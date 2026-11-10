import BackgroundTasks
import CoreLocation
import Flutter
import Foundation
import UIKit
import UserNotifications

/// The iOS counterpart of the Android CollectorService + AndroidCollectorHost
/// (docs/PHASE4_IOS.md §3):
/// - while collection is enabled, a **headless FlutterEngine** runs the shared Dart collector
///   (`collectorMain`), exactly as the Android foreground service does. The UI engine never
///   collects, so foreground, background and relaunched starts all behave the same;
/// - continuous background location keeps the process alive, and significant-change
///   monitoring relaunches it after termination;
/// - uploads run inside the collector engine: hourly from the Dart loop on an unmetered
///   network, and when the `upload` BGProcessingTask fires.
///
/// Everything here runs on the main thread: Pigeon sync handlers, Core Location and
/// notification delegates all call in on it, and async handlers hop to it.
final class IosCollectorHost: NSObject, IosCollectorApi {
  static let shared = IosCollectorHost()

  static let uploadTaskId = "io.github.kouotou.qoesense.upload"
  static let uploadInterval: TimeInterval = 60 * 60

  private let defaults = UserDefaults.standard
  private enum Keys {
    static let enabled = "collector.enabled"
    static let consentMs = "collector.consentMs"
    static let lastUploadMs = "collector.lastUploadMs"
  }

  let location = LocationService()
  lazy var capturer = IosSampleCapturer(location: location)
  let answers = SurveyAnswerStore()
  let openedPrompts = OpenedPromptStore()
  private lazy var notificationDelegate = SurveyNotificationDelegate(
    answers: answers, openedPrompts: openedPrompts)

  private var collectorEngine: FlutterEngine?
  private var collectorEvents: CollectorEvents?
  private var uiEvents: SurveyUiEvents?
  private var pendingUploadTask: BGTask?
  private var lastWakeMs: Int64 = 0
  private var launched = false

  // MARK: Launch

  /// Called from application(_:didFinishLaunchingWithOptions:), for every launch: by the
  /// participant, a significant location change, a BGTask, or a notification action.
  func launch() {
    guard !launched else { return }
    launched = true
    // Must be registered before launch ends, or iOS drops the task. On the main queue, like
    // everything else here (nil would mean a background queue).
    BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.uploadTaskId, using: .main) { [weak self] task in
      self?.handleUploadTask(task)
    }
    SurveyNotifications.registerCategory()
    UNUserNotificationCenter.current().delegate = notificationDelegate
    notificationDelegate.onPromptOpened = { [weak self] in self?.notifyUiPromptOpened() }

    location.onKeepAliveUpdate = { [weak self] in self?.forwardWake() }
    location.onAuthorizationChange = { [weak self] _ in
      guard let self, self.isEnabled else { return }
      self.location.startKeepAlive()  // e.g. Always granted later in Settings
    }
    // Before the first unlock after a reboot, UserDefaults and the database are unreadable.
    // Re-check once protected data becomes available.
    NotificationCenter.default.addObserver(
      forName: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil, queue: .main
    ) { [weak self] _ in self?.startIfEnabled() }
    startIfEnabled()
  }

  /// The UI engine's channel, for the survey sheet event.
  func attachUi(_ events: SurveyUiEvents) {
    uiEvents = events
  }

  private var isEnabled: Bool { defaults.bool(forKey: Keys.enabled) && defaults.object(forKey: Keys.consentMs) != nil }

  private func startIfEnabled() {
    guard isEnabled else { return }
    location.startKeepAlive()
    startCollectorEngine()
    scheduleUploadTask()
  }

  private func stopCollection() {
    location.stopKeepAlive()
    collectorEngine?.destroyContext()
    collectorEngine = nil
    collectorEvents = nil
    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.uploadTaskId)
    finishUploadTask(success: true)
  }

  private func startCollectorEngine() {
    guard collectorEngine == nil else { return }
    let engine = FlutterEngine(name: "qoesense.collector", project: nil, allowHeadlessExecution: true)
    guard engine.run(withEntrypoint: "collectorMain") else {
      NSLog("QoESense: the collector engine did not start")
      return
    }
    GeneratedPluginRegistrant.register(with: engine)
    TelemetryHostApiSetup.setUp(binaryMessenger: engine.binaryMessenger, api: IOSCapabilityReporter())
    IosCollectorApiSetup.setUp(binaryMessenger: engine.binaryMessenger, api: self)
    collectorEvents = CollectorEvents(binaryMessenger: engine.binaryMessenger)
    collectorEngine = engine
  }

  /// Keep-alive location updates double as wake-ups, at most every 30 s. Dart ignores a
  /// wake-up that arrives before the sampling interval is up (Collector.wake).
  private func forwardWake() {
    let now = monotonicMs()
    guard let events = collectorEvents, now - lastWakeMs >= 30_000 else { return }
    lastWakeMs = now
    Task { @MainActor in try? await events.wakeTick() }
  }

  private func notifyUiPromptOpened() {
    guard let events = uiEvents else { return }
    Task { @MainActor in try? await events.surveyPromptOpened() }
  }

  // MARK: Uploads

  private func scheduleUploadTask() {
    let request = BGProcessingTaskRequest(identifier: Self.uploadTaskId)
    request.requiresNetworkConnectivity = true
    request.requiresExternalPower = false
    request.earliestBeginDate = Date(timeIntervalSinceNow: Self.uploadInterval)
    do {
      try BGTaskScheduler.shared.submit(request)  // replaces the pending request
    } catch {
      NSLog("QoESense: could not schedule the upload task: \(error)")
    }
  }

  private func handleUploadTask(_ task: BGTask) {
    scheduleUploadTask()
    guard isEnabled else { return task.setTaskCompleted(success: true) }
    finishUploadTask(success: false)  // a previous one still open
    pendingUploadTask = task
    task.expirationHandler = { [weak self] in
      DispatchQueue.main.async { self?.finishUploadTask(success: false) }
    }
    startIfEnabled()
    guard currentUploadConstraintsMet() else { return finishUploadTask(success: true) }
    askCollectorToUpload()
  }

  /// If the engine was just started, its handler may not be registered yet; the collector
  /// then runs its own hourly check on its first tick and reports back the same way.
  private func askCollectorToUpload() {
    guard let events = collectorEvents else { return }
    Task { @MainActor in try? await events.uploadRequested() }
  }

  private func finishUploadTask(success: Bool) {
    pendingUploadTask?.setTaskCompleted(success: success)
    pendingUploadTask = nil
  }

  private func currentUploadConstraintsMet() -> Bool {
    PathMapping.isUnmetered(capturer.paths.currentPath) && !ProcessInfo.processInfo.isLowPowerModeEnabled
  }

  // MARK: IosCollectorApi

  func captureSample(locationTimeoutMs: Int64, staleAfterMs: Int64) async throws -> CapturedSampleMessage {
    await withCheckedContinuation { continuation in
      DispatchQueue.main.async {
        self.capturer.capture(locationTimeoutMs: locationTimeoutMs, staleAfterMs: staleAfterMs) {
          continuation.resume(returning: $0)
        }
      }
    }
  }

  func setCollectionEnabled(enabled: Bool) throws {
    defaults.set(enabled, forKey: Keys.enabled)
    // Deferred: this call may come from the collector engine itself (no consent), and that
    // engine must not be destroyed while it waits for this reply.
    DispatchQueue.main.async {
      if self.isEnabled { self.startIfEnabled() } else { self.stopCollection() }
    }
  }

  func status() throws -> CollectorStatusMessage {
    CollectorStatusMessage(
      collectionEnabled: defaults.bool(forKey: Keys.enabled),
      serviceRunning: collectorEngine != nil,
      lastUploadMs: (defaults.object(forKey: Keys.lastUploadMs) as? NSNumber)?.int64Value)
  }

  func presentSurvey(triggerType: String) throws {
    SurveyNotifications.present(triggerType: triggerType, promptedAtMs: wallClockMs())
  }

  func pendingSurveyAnswers() throws -> [SurveyAnswerMessage] {
    answers.pending()
  }

  func acknowledgeSurveyAnswers(responseIds: [String]) throws {
    answers.acknowledge(responseIds)
  }

  func submitSurveyAnswer(answer: SurveyAnswerMessage) throws {
    answers.append(answer)
  }

  func takeOpenedSurveyPrompt() throws -> SurveyPromptMessage? {
    openedPrompts.take()
  }

  func uploadConstraintsMet() throws -> Bool {
    currentUploadConstraintsMet()
  }

  func uploadRunFinished(success: Bool, uploadedRows: Int64) throws {
    if success { defaults.set(NSNumber(value: wallClockMs()), forKey: Keys.lastUploadMs) }
    finishUploadTask(success: success)
  }

  func requestUploadNow() throws {
    askCollectorToUpload()
  }

  func openAppSettings() throws {
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
    DispatchQueue.main.async { UIApplication.shared.open(url) }
  }

  func recordConsent(timestampMs: Int64) throws {
    defaults.set(NSNumber(value: timestampMs), forKey: Keys.consentMs)
  }

  func requestLocationWhenInUse() async throws -> LocationAuthorizationMessage {
    await withCheckedContinuation { continuation in
      DispatchQueue.main.async {
        self.location.requestWhenInUse { continuation.resume(returning: Self.message(for: $0)) }
      }
    }
  }

  func requestLocationAlways() async throws -> LocationAuthorizationMessage {
    await withCheckedContinuation { continuation in
      DispatchQueue.main.async {
        self.location.requestAlways { continuation.resume(returning: Self.message(for: $0)) }
      }
    }
  }

  func requestNotifications() async throws -> Bool {
    (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
  }

  static func message(for status: CLAuthorizationStatus) -> LocationAuthorizationMessage {
    switch status {
    case .authorizedAlways: return .always
    case .authorizedWhenInUse: return .whenInUse
    case .restricted: return .restricted
    case .denied: return .denied
    default: return .notDetermined
    }
  }
}

/// Every member is used on the main thread only: Pigeon handlers, delegates and the async
/// methods' continuations all run there (see the type's doc comment). That confinement is what
/// makes it safe to capture in the main-queue closures of the async methods.
extension IosCollectorHost: @unchecked Sendable {}

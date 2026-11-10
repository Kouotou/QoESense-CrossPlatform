import Foundation
import UserNotifications

/// The iOS MOS survey (docs/PHASE4_IOS.md §4). iOS can't draw over other apps, so the prompt
/// is a local notification:
/// - its five action buttons (touch and hold the notification) record the score without
///   opening the app: presentationMode NOTIFICATION_ACTION;
/// - tapping the notification opens the app, which shows the in-app sheet with the score and
///   the "what were you doing?" question (D-6): presentationMode NOTIFICATION.
/// Taps go into a durable native queue; Dart reads it, stores the answers durably, then
/// acknowledges them (the same contract as Android's CollectorPrefs queue).
enum SurveyNotifications {
  static let categoryId = "QOESENSE_MOS"
  static let actionPrefix = "MOS_"
  static let requestId = "qoesense.mos.prompt"
  static let keyTrigger = "triggerType"
  static let keyPromptedAt = "promptedAtMs"

  /// Language-neutral titles: the body explains the scale (as Android's caption does).
  static func registerCategory(center: UNUserNotificationCenter = .current()) {
    let actions = (1...5).map { score in
      UNNotificationAction(
        identifier: "\(actionPrefix)\(score)",
        title: "\(score) " + String(repeating: "★", count: score),
        options: [],  // no .foreground: answered in the background; no .authenticationRequired: works when locked
        icon: UNNotificationActionIcon(systemImageName: "\(score).circle"))
    }
    let category = UNNotificationCategory(
      identifier: categoryId, actions: actions, intentIdentifiers: [], options: [])
    center.setNotificationCategories([category])
  }

  static func present(triggerType: String, promptedAtMs: Int64, center: UNUserNotificationCenter = .current()) {
    let strings = SurveyStrings.current
    let content = UNMutableNotificationContent()
    content.title = strings.title
    content.body = strings.body
    content.sound = .default
    content.categoryIdentifier = categoryId
    content.threadIdentifier = categoryId
    content.userInfo = [keyTrigger: triggerType, keyPromptedAt: NSNumber(value: promptedAtMs)]
    // One prompt at a time: a new one replaces an unanswered older one (same identifier).
    let request = UNNotificationRequest(identifier: requestId, content: content, trigger: nil)
    center.add(request) { error in
      if let error { NSLog("QoESense: survey notification failed: \(error)") }
    }
  }

  /// The score of a rating action, or nil for any other action.
  static func score(forAction identifier: String) -> Int64? {
    guard identifier.hasPrefix(actionPrefix), let n = Int64(identifier.dropFirst(actionPrefix.count)),
      (1...5).contains(n)
    else { return nil }
    return n
  }

  static func prompt(from userInfo: [AnyHashable: Any]) -> SurveyPromptMessage? {
    guard let trigger = userInfo[keyTrigger] as? String else { return nil }
    let prompted = (userInfo[keyPromptedAt] as? NSNumber)?.int64Value ?? 0
    return SurveyPromptMessage(triggerType: trigger, promptedAtMs: prompted)
  }
}

/// Notification texts, copied from the Android res/values(-fr)/strings.xml survey strings and
/// adapted for the iOS gestures.
struct SurveyStrings {
  let title: String
  let body: String

  static var current: SurveyStrings {
    let french = Locale.preferredLanguages.first?.lowercased().hasPrefix("fr") ?? false
    return french
      ? SurveyStrings(
        title: "Question rapide",
        body:
          "Comment était votre expérience réseau à l'instant ? Appuyez longuement pour évaluer de 1 à 5 (1 = très mauvaise, 5 = excellente), ou touchez pour ouvrir."
      )
      : SurveyStrings(
        title: "Quick question",
        body:
          "How was your network experience just now? Touch and hold to rate 1-5 (1 = very poor, 5 = excellent), or tap to open."
      )
  }
}

/// Receives notification taps, also when iOS launches the app in the background for them.
final class SurveyNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
  let answers: SurveyAnswerStore
  let openedPrompts: OpenedPromptStore
  /// Called (main queue) when the participant opened a prompt by tapping it.
  var onPromptOpened: (() -> Void)?
  var clock: () -> Int64 = { wallClockMs() }

  init(answers: SurveyAnswerStore, openedPrompts: OpenedPromptStore) {
    self.answers = answers
    self.openedPrompts = openedPrompts
  }

  /// In the foreground the prompt is still shown as a banner.
  func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .list, .sound])
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    handle(
      actionIdentifier: response.actionIdentifier,
      userInfo: response.notification.request.content.userInfo)
    completionHandler()
  }

  /// Separated from the delegate callback so RunnerTests can drive it.
  func handle(actionIdentifier: String, userInfo: [AnyHashable: Any]) {
    guard let prompt = SurveyNotifications.prompt(from: userInfo) else { return }
    if let score = SurveyNotifications.score(forAction: actionIdentifier) {
      let tapMs = clock()
      answers.append(
        SurveyAnswerMessage(
          responseId: UUID().uuidString.lowercased(),  // tap-time UUID, reused on every retry
          score: score,
          triggerType: prompt.triggerType,
          tapMs: tapMs,
          promptedAtMs: prompt.promptedAtMs > 0 ? min(prompt.promptedAtMs, tapMs) : nil,
          presentationMode: "NOTIFICATION_ACTION"))
    } else if actionIdentifier == UNNotificationDefaultActionIdentifier {
      openedPrompts.set(prompt)
      DispatchQueue.main.async { self.onPromptOpened?() }
    }
  }
}

/// Durable queue of taps, one JSON file in Application Support. Written atomically, with
/// "complete until first user authentication" protection, so a tap on the lock screen (which
/// launches the app in the background) can still be stored.
final class SurveyAnswerStore {
  private let url: URL
  private let lock = NSLock()

  init(directory: URL? = nil) {
    let dir =
      directory
      ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("qoesense", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    url = dir.appendingPathComponent("survey_answers.json")
  }

  func append(_ answer: SurveyAnswerMessage) {
    lock.lock()
    defer { lock.unlock() }
    var all = load()
    guard !all.contains(where: { $0.responseId == answer.responseId }) else { return }
    all.append(answer)
    save(all)
  }

  func pending() -> [SurveyAnswerMessage] {
    lock.lock()
    defer { lock.unlock() }
    return load()
  }

  func acknowledge(_ responseIds: [String]) {
    lock.lock()
    defer { lock.unlock() }
    let ids = Set(responseIds)
    save(load().filter { !ids.contains($0.responseId) })
  }

  private func load() -> [SurveyAnswerMessage] {
    guard let data = try? Data(contentsOf: url),
      let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    else { return [] }
    return rows.compactMap(Self.decode)
  }

  private func save(_ answers: [SurveyAnswerMessage]) {
    do {
      let data = try JSONSerialization.data(withJSONObject: answers.map(Self.encode))
      try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    } catch {
      NSLog("QoESense: could not store survey answers: \(error)")
    }
  }

  static func encode(_ a: SurveyAnswerMessage) -> [String: Any] {
    var row: [String: Any] = [
      "responseId": a.responseId, "score": a.score, "triggerType": a.triggerType, "tapMs": a.tapMs,
      "presentationMode": a.presentationMode,
    ]
    if let p = a.promptedAtMs { row["promptedAtMs"] = p }
    if let p = a.contextAppPackage { row["contextAppPackage"] = p }
    if let s = a.contextSessionType { row["contextSessionType"] = s }
    return row
  }

  static func decode(_ row: [String: Any]) -> SurveyAnswerMessage? {
    guard let id = row["responseId"] as? String,
      let score = (row["score"] as? NSNumber)?.int64Value,
      let trigger = row["triggerType"] as? String,
      let tap = (row["tapMs"] as? NSNumber)?.int64Value,
      let mode = row["presentationMode"] as? String
    else { return nil }
    return SurveyAnswerMessage(
      responseId: id, score: score, triggerType: trigger, tapMs: tap,
      promptedAtMs: (row["promptedAtMs"] as? NSNumber)?.int64Value,
      presentationMode: mode,
      contextAppPackage: row["contextAppPackage"] as? String,
      contextSessionType: row["contextSessionType"] as? String)
  }
}

/// The prompt the participant opened by tapping its notification, until the UI takes it.
final class OpenedPromptStore {
  private let defaults: UserDefaults
  private let key = "survey.openedPrompt"

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  func set(_ prompt: SurveyPromptMessage) {
    defaults.set([SurveyNotifications.keyTrigger: prompt.triggerType, SurveyNotifications.keyPromptedAt: prompt.promptedAtMs], forKey: key)
  }

  func take() -> SurveyPromptMessage? {
    guard let row = defaults.dictionary(forKey: key) else { return nil }
    defaults.removeObject(forKey: key)
    return SurveyNotifications.prompt(from: row)
  }
}

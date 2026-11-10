import CoreLocation
import Foundation
import UIKit

/// One tick's location, with the contract status (DATA_CONTRACT §5).
struct LocationReading: Equatable {
  var latitude: Double?
  var longitude: Double?
  var accuracyMeters: Double?
  var ageMs: Int64?
  var status: MeasurementStatus

  static func empty(_ status: MeasurementStatus) -> LocationReading {
    LocationReading(latitude: nil, longitude: nil, accuracyMeters: nil, ageMs: nil, status: status)
  }
}

/// Pure rules, unit-tested in RunnerTests.
enum LocationRules {
  /// No reading at all when the app isn't allowed to use location.
  static func statusWithoutPermission(_ status: CLAuthorizationStatus) -> MeasurementStatus? {
    switch status {
    case .authorizedAlways, .authorizedWhenInUse: return nil
    case .restricted: return .restricted  // MDM or parental controls
    default: return .permissionDenied  // not determined, denied, or Location Services off
    }
  }

  /// A fix becomes a reading. Its age comes from CLLocation.timestamp (iOS gives no monotonic
  /// timestamp), so it is wall-clock based. Older than the sampling interval = STALE.
  static func reading(
    latitude: Double, longitude: Double, horizontalAccuracy: Double, ageMs: Int64, staleAfterMs: Int64
  ) -> LocationReading {
    // A negative horizontalAccuracy means the coordinate is invalid.
    guard horizontalAccuracy >= 0, latitude.isFinite, longitude.isFinite else { return .empty(.unavailable) }
    let age = max(0, ageMs)
    return LocationReading(
      latitude: latitude, longitude: longitude, accuracyMeters: horizontalAccuracy, ageMs: age,
      status: age > staleAfterMs ? .stale : .ok)
  }

  /// Why a one-shot request produced no fix.
  static func status(forError error: Error?) -> MeasurementStatus {
    guard let error = error as? CLError else { return error == nil ? .timeout : .failed }
    switch error.code {
    case .denied: return .permissionDenied
    case .locationUnknown: return .unavailable
    default: return .failed
    }
  }
}

/// Core Location for the collector:
/// - `keepAlive`: continuous coarse updates with background updates allowed and automatic
///   pausing off. While it runs, iOS keeps the process alive in the background, so the Dart
///   timer keeps firing (docs/ARCHITECTURE.md §5). It costs little at 3 km accuracy.
/// - `relaunch`: significant-location-change monitoring (needs Always). iOS relaunches the
///   app after a ~500 m move once it was terminated; per the requestAlwaysAuthorization header,
///   even after the participant force-quit it (to confirm on device, docs/PHASE4_IOS.md §7).
/// - `oneShot`: one `requestLocation()` per tick at 100 m, like Android's balanced-power
///   getCurrentLocation, bounded by the SamplingPolicy timeout.
final class LocationService: NSObject, CLLocationManagerDelegate {
  private let keepAlive = CLLocationManager()
  private let relaunch = CLLocationManager()
  private let oneShot = CLLocationManager()

  private var fixWaiters: [UUID: (CLLocation?, Error?) -> Void] = [:]
  private var oneShotInFlight = false
  private var authWaiters: [(CLAuthorizationStatus) -> Void] = []
  private var keepAliveRunning = false

  /// Every keep-alive update (main queue). The host forwards it to Dart as a wake-up.
  var onKeepAliveUpdate: (() -> Void)?
  /// Authorization changes (main queue), e.g. granted later in Settings.
  var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?

  override init() {
    super.init()
    for manager in [keepAlive, relaunch, oneShot] { manager.delegate = self }
    oneShot.desiredAccuracy = kCLLocationAccuracyHundredMeters
  }

  var authorization: CLAuthorizationStatus { keepAlive.authorizationStatus }

  var isAuthorized: Bool { LocationRules.statusWithoutPermission(authorization) == nil }

  /// Reduced ("approximate") accuracy chosen by the participant (iOS 14+).
  var isApproximate: Bool { keepAlive.accuracyAuthorization == .reducedAccuracy }

  // MARK: Keep-alive

  func startKeepAlive() {
    guard isAuthorized else { return }
    if !keepAliveRunning {
      keepAlive.desiredAccuracy = kCLLocationAccuracyThreeKilometers
      keepAlive.distanceFilter = kCLDistanceFilterNone
      keepAlive.activityType = .other
      keepAlive.pausesLocationUpdatesAutomatically = false
      keepAlive.allowsBackgroundLocationUpdates = true  // needs UIBackgroundModes "location"
      // The blue status-bar indicator while collecting in the background: the counterpart of
      // the Android "collection active" notification, so collection is never invisible.
      keepAlive.showsBackgroundLocationIndicator = true
      keepAlive.startUpdatingLocation()
      keepAliveRunning = true
    }
    if authorization == .authorizedAlways {
      relaunch.startMonitoringSignificantLocationChanges()
    }
  }

  func stopKeepAlive() {
    keepAlive.stopUpdatingLocation()
    relaunch.stopMonitoringSignificantLocationChanges()
    keepAliveRunning = false
  }

  // MARK: One fix per tick

  /// The freshest fix within [timeoutMs]. If the one-shot request fails or times out, a
  /// keep-alive fix that is still within the sampling interval is used instead (with its own,
  /// usually coarse, accuracy). Otherwise the status says why there's no value.
  func fix(timeoutMs: Int64, staleAfterMs: Int64, completion: @escaping (LocationReading) -> Void) {
    if let denied = LocationRules.statusWithoutPermission(authorization) {
      completion(.empty(denied))
      return
    }
    let id = UUID()
    var done = false
    let finish: (CLLocation?, Error?) -> Void = { [weak self] location, error in
      guard let self, !done else { return }
      done = true
      self.fixWaiters[id] = nil
      completion(self.reading(location: location, error: error, staleAfterMs: staleAfterMs))
    }
    fixWaiters[id] = finish
    if !oneShotInFlight {
      oneShotInFlight = true
      oneShot.requestLocation()
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Int(timeoutMs))) { [weak self] in
      finish(nil, nil)  // nil error = our own timeout
      // requestLocation() may never call back (Apple: it "does nothing" while location
      // services already run). Don't let one lost request block every later tick.
      if let self, self.fixWaiters.isEmpty { self.oneShotInFlight = false }
    }
  }

  private func reading(location: CLLocation?, error: Error?, staleAfterMs: Int64) -> LocationReading {
    if let location { return reading(of: location, staleAfterMs: staleAfterMs) }
    if let fallback = keepAlive.location {
      let r = reading(of: fallback, staleAfterMs: staleAfterMs)
      if r.status == .ok { return r }
    }
    return .empty(LocationRules.status(forError: error))
  }

  private func reading(of location: CLLocation, staleAfterMs: Int64) -> LocationReading {
    LocationRules.reading(
      latitude: location.coordinate.latitude,
      longitude: location.coordinate.longitude,
      horizontalAccuracy: location.horizontalAccuracy,
      ageMs: Int64(Date().timeIntervalSince(location.timestamp) * 1000),
      staleAfterMs: staleAfterMs)
  }

  private func deliverOneShot(_ location: CLLocation?, _ error: Error?) {
    oneShotInFlight = false
    let waiters = fixWaiters.values
    for w in waiters { w(location, error) }
  }

  // MARK: Authorization

  /// Asks for When-In-Use (the first iOS prompt). Completes when the participant answers, or
  /// at once if they already did.
  func requestWhenInUse(_ completion: @escaping (CLAuthorizationStatus) -> Void) {
    guard authorization == .notDetermined else { return completion(authorization) }
    awaitPrompt(completion) { self.keepAlive.requestWhenInUseAuthorization() }
  }

  /// Asks to upgrade to Always. iOS shows that prompt at most once; if it doesn't appear,
  /// this completes with the current status, and the UI offers the Settings app instead.
  func requestAlways(_ completion: @escaping (CLAuthorizationStatus) -> Void) {
    guard authorization != .authorizedAlways else { return completion(authorization) }
    awaitPrompt(completion) { self.keepAlive.requestAlwaysAuthorization() }
  }

  /// The delegate only fires when the status *changes*, and "Keep Only While Using" changes
  /// nothing. So the prompt is also considered answered when the app becomes active again
  /// after the system alert, or after a short grace period if no alert appeared at all.
  private func awaitPrompt(_ completion: @escaping (CLAuthorizationStatus) -> Void, request: () -> Void) {
    var finished = false
    var observers: [NSObjectProtocol] = []
    var alertShown = false
    let finish: () -> Void = { [weak self] in
      guard let self, !finished else { return }
      finished = true
      observers.forEach(NotificationCenter.default.removeObserver)
      completion(self.authorization)
    }
    authWaiters.append { _ in finish() }
    let center = NotificationCenter.default
    observers.append(
      center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { _ in
        alertShown = true
      })
    observers.append(
      center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
        if alertShown { finish() }
      })
    request()
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { if !alertShown { finish() } }
    DispatchQueue.main.asyncAfter(deadline: .now() + 120) { finish() }
  }

  // MARK: CLLocationManagerDelegate

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    if manager === oneShot {
      deliverOneShot(locations.last, nil)
    } else if manager === keepAlive {
      onKeepAliveUpdate?()
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    if manager === oneShot { deliverOneShot(nil, error) }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    guard manager === keepAlive else { return }
    let status = manager.authorizationStatus
    if status != .notDetermined {
      let waiters = authWaiters
      authWaiters.removeAll()
      waiters.forEach { $0(status) }
    }
    onAuthorizationChange?(status)
  }
}

import CoreLocation
import CoreTelephony
import Foundation
import UserNotifications

/// Explicit, honest capability report for this iPhone. Field groups that iOS has no public
/// API for (RSRP/RSRQ/SINR/TA/cell ID, CQI, physical channel, foreground app, drawing over
/// other apps) report `.unsupportedOnPlatform` unconditionally - they are always null on the
/// wire, never estimated. See docs/MIGRATION_MATRIX.md.
///
/// Phase 1 only reports; it requests no permissions and captures nothing.
final class IOSCapabilityReporter: TelemetryHostApi {

  func getCapabilityReport() async throws -> CapabilityReportMessage {
    let os = ProcessInfo.processInfo.operatingSystemVersion
    let locationStatus = CLLocationManager().authorizationStatus
    let notificationStatus = await UNUserNotificationCenter.current()
      .notificationSettings().authorizationStatus

    return CapabilityReportMessage(
      platform: "IOS",
      osMajorVersion: Int64(os.majorVersion),
      deviceModel: Self.hardwareIdentifier(),
      radioSignal: .unsupportedOnPlatform,
      cqi: .unsupportedOnPlatform,
      physicalChannel: .unsupportedOnPlatform,
      radioAccessTechnology: Self.hasCellularService() ? .available : .unsupportedOnPlatform,
      connectivity: .available,  // NWPathMonitor needs no permission
      throughput: .available,  // getifaddrs byte counters need no permission
      foregroundApp: .unsupportedOnPlatform,
      callDetection: .available,  // CXCallObserver needs no permission
      location: Self.foregroundLocation(locationStatus),
      backgroundLocation: Self.backgroundLocation(locationStatus),
      notifications: Self.notifications(notificationStatus),
      surveyOverlay: .unsupportedOnPlatform
    )
  }

  /// e.g. "iPhone14,5" - the stable hardware identifier, not the marketing name.
  static func hardwareIdentifier() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)
    let identifier = withUnsafeBytes(of: &systemInfo.machine) { buffer in
      String(decoding: buffer.prefix(while: { $0 != 0 }), as: UTF8.self)
    }
    return identifier.isEmpty ? "unknown" : identifier
  }

  /// A device with no cellular modem (Wi-Fi iPad, simulator) has neither service subscribers
  /// nor a current RAT. CTCarrier is deprecated since iOS 16 and returns placeholder values,
  /// but the subscriber dictionary still exists on a cellular device, so either signal counts.
  static func hasCellularService() -> Bool {
    let info = CTTelephonyNetworkInfo()
    let rat = info.serviceCurrentRadioAccessTechnology ?? [:]
    let subscribers = info.serviceSubscriberCellularProviders ?? [:]
    return !rat.isEmpty || !subscribers.isEmpty
  }

  static func foregroundLocation(_ status: CLAuthorizationStatus) -> Availability {
    switch status {
    case .authorizedAlways, .authorizedWhenInUse: return .available
    case .restricted: return .restricted
    default: return .permissionMissing
    }
  }

  static func backgroundLocation(_ status: CLAuthorizationStatus) -> Availability {
    switch status {
    case .authorizedAlways: return .available
    case .restricted: return .restricted
    default: return .permissionMissing
    }
  }

  static func notifications(_ status: UNAuthorizationStatus) -> Availability {
    switch status {
    case .authorized, .provisional, .ephemeral: return .available
    default: return .permissionMissing
    }
  }
}

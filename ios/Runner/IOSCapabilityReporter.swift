import CoreLocation
import CoreTelephony
import Foundation
import UserNotifications

/// Explicit, honest capability report for this iPhone. Field groups that iOS has no public
/// API for (RSRP/RSRQ/SINR/TA/cell ID, CQI, physical channel, foreground app, drawing over
/// other apps) report `.unsupportedOnPlatform` unconditionally - they are always null on the
/// wire, never estimated. See docs/PHASE4_IOS.md §1 and docs/MIGRATION_MATRIX.md.
final class IOSCapabilityReporter: TelemetryHostApi {

  func getCapabilityReport() async throws -> CapabilityReportMessage {
    let notificationStatus = await UNUserNotificationCenter.current()
      .notificationSettings().authorizationStatus
    // Core Location objects belong on the main thread.
    let (locationStatus, hasCellular) = await withCheckedContinuation { continuation in
      DispatchQueue.main.async {
        let host = IosCollectorHost.shared
        continuation.resume(returning: (host.location.authorization, host.capturer.hasCellular))
      }
    }
    return Self.report(
      locationStatus: locationStatus, notificationStatus: notificationStatus, hasCellular: hasCellular)
  }

  static func report(
    locationStatus: CLAuthorizationStatus, notificationStatus: UNAuthorizationStatus, hasCellular: Bool
  ) -> CapabilityReportMessage {
    CapabilityReportMessage(
      platform: "IOS",
      osMajorVersion: DeviceInfo.osMajorVersion,
      deviceModel: DeviceInfo.hardwareIdentifier(),
      radioSignal: .unsupportedOnPlatform,
      cqi: .unsupportedOnPlatform,
      physicalChannel: .unsupportedOnPlatform,
      radioAccessTechnology: hasCellular ? .available : .unsupportedOnPlatform,
      connectivity: .available,  // NWPathMonitor needs no permission
      throughput: .available,  // getifaddrs byte counters need no permission
      foregroundApp: .unsupportedOnPlatform,
      callDetection: .available,  // CXCallObserver needs no permission
      location: foregroundLocation(locationStatus),
      backgroundLocation: backgroundLocation(locationStatus),
      notifications: notifications(notificationStatus),
      surveyOverlay: .unsupportedOnPlatform
    )
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

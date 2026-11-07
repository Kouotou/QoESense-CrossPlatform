// Single source of truth for the Dart <-> Kotlin/Swift channel. Regenerate with:
//   dart run pigeon --input pigeons/telemetry_api.dart
// CI fails if the checked-in generated files differ from a fresh generation.
//
// Phase 1 exposes only the capability report. Capture calls (radio, location, throughput,
// session) and the native -> Dart collector callbacks arrive in Phase 3 - see
// docs/ARCHITECTURE.md section 3.
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/platform/telemetry_api.g.dart',
    dartPackageName: 'qoesense',
    kotlinOut: 'android/app/src/main/kotlin/org/qoesense/xplat/qoesense/TelemetryApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'org.qoesense.xplat.qoesense'),
    swiftOut: 'ios/Runner/TelemetryApi.g.swift',
  ),
)
/// Whether a telemetry field group can actually be measured right now. Never faked: a group
/// that is not [available] is written as null on the wire.
enum Availability {
  /// The OS and hardware provide it and any needed permission is granted.
  available,

  /// The platform supports it but the participant hasn't granted the permission (yet).
  permissionMissing,

  /// No API exists on this platform at all (e.g. RSRP on iOS).
  unsupportedOnPlatform,

  /// An API exists but this app can't use it (e.g. carrier-privileged PhysicalChannelConfig,
  /// or an MDM/parental restriction on location).
  restricted,
}

class CapabilityReportMessage {
  CapabilityReportMessage({
    required this.platform,
    required this.osMajorVersion,
    required this.deviceModel,
    required this.radioSignal,
    required this.cqi,
    required this.physicalChannel,
    required this.radioAccessTechnology,
    required this.connectivity,
    required this.throughput,
    required this.foregroundApp,
    required this.callDetection,
    required this.location,
    required this.backgroundLocation,
    required this.notifications,
    required this.surveyOverlay,
  });

  /// "ANDROID" or "IOS" - same values as the BigQuery `platform` column.
  final String platform;

  /// Android SDK_INT, or the iOS major version (see DATA_CONTRACT D-5).
  final int osMajorVersion;

  /// Build.MODEL on Android, hardware identifier (e.g. "iPhone14,5") on iOS.
  final String deviceModel;

  /// RSRP, RSRQ, RSSNR, timing advance, cell identity, TAC, signal bars.
  final Availability radioSignal;
  final Availability cqi;
  final Availability physicalChannel;
  final Availability radioAccessTechnology;
  final Availability connectivity;
  final Availability throughput;
  final Availability foregroundApp;
  final Availability callDetection;
  final Availability location;
  final Availability backgroundLocation;
  final Availability notifications;
  final Availability surveyOverlay;
}

@HostApi()
abstract class TelemetryHostApi {
  @async
  CapabilityReportMessage getCapabilityReport();
}

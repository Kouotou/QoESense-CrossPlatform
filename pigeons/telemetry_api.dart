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
    kotlinOut: 'android/app/src/main/kotlin/io/github/kouotou/qoesense/TelemetryApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'io.github.kouotou.qoesense'),
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

// ---------------------------------------------------------------------------------------
// Android collector (Phase 3). Android-only: iOS gets its own API in the Mac phase. The
// generated Swift protocol for this API is never implemented on iOS, which is fine.
// ---------------------------------------------------------------------------------------

/// Mirrors the Dart FieldStatus / DATA_CONTRACT §5.
enum MeasurementStatus {
  ok,
  stale,
  notSupported,
  permissionDenied,
  restricted,
  notAttempted,
  unavailable,
  timeout,
  failed,
}

enum SessionTypeMessage { none, socialMedia, videoConferencing }

/// One whole capture, everything except RTT, from a single native call per tick.
/// Field semantics are the reference app's (DATA_CONTRACT §3).
class CapturedSampleMessage {
  CapturedSampleMessage({
    required this.radioStatus,
    required this.cqiStatus,
    required this.physicalChannelStatus,
    required this.networkTypeStatus,
    required this.connectivityStatus,
    required this.throughputStatus,
    required this.appSessionType,
    required this.foregroundAppStatus,
    required this.locationStatus,
    required this.capabilitySet,
    required this.deviceModel,
    required this.osSdkInt,
    required this.osVersion,
    required this.appId,
    required this.appVersion,
    required this.appBuild,
  });

  int? rsrp;
  int? rsrq;
  int? rssnr;
  int? timingAdvance;
  String? cellIdentityHash;
  int? trackingAreaCode;
  int? signalStrengthLevel;
  MeasurementStatus radioStatus;
  int? cellInfoAgeMs;

  int? cqi;
  MeasurementStatus cqiStatus;

  int? cellBandwidthKhz;
  int? downlinkChannelNumber;
  int? uplinkChannelNumber;
  MeasurementStatus physicalChannelStatus;

  String? networkType;
  MeasurementStatus networkTypeStatus;

  String? connectionType;
  bool? isRoaming;
  MeasurementStatus connectivityStatus;

  int? throughputBytesPerSecond;
  int? throughputWindowMs;
  MeasurementStatus throughputStatus;

  String? foregroundAppPackage;
  SessionTypeMessage appSessionType;
  MeasurementStatus foregroundAppStatus;

  double? latitude;
  double? longitude;
  double? locationAccuracyMeters;
  int? locationAgeMs;
  MeasurementStatus locationStatus;

  /// SampleFieldGroup wire names (RADIO, CQI, …) this device could provide right now.
  List<String> capabilitySet;

  String deviceModel;
  int osSdkInt;
  String osVersion;
  String appId;
  String appVersion;
  int appBuild;
}

/// A rating tapped in the native overlay or notification, queued natively until Dart has
/// stored it durably and acknowledged it.
class SurveyAnswerMessage {
  SurveyAnswerMessage({
    required this.responseId,
    required this.score,
    required this.triggerType,
    required this.tapMs,
    required this.presentationMode,
  });
  String responseId;
  int score;

  /// PERIODIC, POST_SESSION or ANOMALY.
  String triggerType;
  int tapMs;
  int? promptedAtMs;

  /// OVERLAY, NOTIFICATION or IN_APP.
  String presentationMode;
}

class CollectorStatusMessage {
  CollectorStatusMessage({required this.collectionEnabled, required this.serviceRunning});
  bool collectionEnabled;
  bool serviceRunning;
  int? lastUploadMs;
}

@HostApi()
abstract class AndroidCollectorApi {
  /// One full capture. Location waits at most [locationTimeoutMs] (SamplingPolicy). A radio
  /// or location reading older than [staleAfterMs] (the current sampling interval) is
  /// reported STALE, with its value kept.
  @async
  CapturedSampleMessage captureSample(int locationTimeoutMs, int staleAfterMs);

  /// Persists the flag (read by BootReceiver), starts/stops the foreground service and
  /// schedules/cancels the hourly upload work.
  void setCollectionEnabled(bool enabled);

  CollectorStatusMessage status();

  /// Shows the overlay survey, or the notification fallback without overlay permission.
  void presentSurvey(String triggerType);

  List<SurveyAnswerMessage> pendingSurveyAnswers();

  void acknowledgeSurveyAnswers(List<String> responseIds);

  /// Called by the headless upload entrypoint when its run ends.
  void uploadRunFinished(bool success, int uploadedRows);

  /// Opens a system settings screen: usageAccess, overlay, batteryOptimization or appDetails.
  void openSystemSettings(String target);

  /// One-off upload now (same constraints as the hourly job).
  void requestUploadNow();

  void recordConsent(int timestampMs);
}

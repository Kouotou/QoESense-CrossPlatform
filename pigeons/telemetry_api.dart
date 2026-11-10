// Single source of truth for the Dart <-> Kotlin/Swift channel. Regenerate with:
//   dart run pigeon --input pigeons/telemetry_api.dart
// CI fails if the checked-in generated files differ from a fresh generation.
//
// TelemetryHostApi (both platforms), AndroidCollectorApi (Phase 3, Kotlin) and
// IosCollectorApi (Phase 4, Swift) - see docs/ARCHITECTURE.md section 3 and
// docs/PHASE4_IOS.md. Each platform implements only its own collector API.
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
// Android collector (Phase 3). Android-only: the generated Swift protocol for this API is
// never implemented on iOS, which is fine. The message classes are shared with iOS.
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

  /// OVERLAY, NOTIFICATION, NOTIFICATION_ACTION or IN_APP.
  String presentationMode;

  /// iOS self-report (D-6): the Android package name of the app the participant chose, or
  /// null for "something else". Always null on Android, where the context is observed.
  String? contextAppPackage;

  /// iOS self-report: NONE, SOCIAL_MEDIA or VIDEO_CONFERENCING. Null when the question
  /// wasn't asked or was skipped (contextSource UNKNOWN).
  String? contextSessionType;
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

/// Native -> Dart events for the collector engine.
@FlutterApi()
abstract class CollectorEvents {
  /// A Doze-tolerant wake-up (AlarmManager.setAndAllowWhileIdle, ~10 min, decision C).
  /// While the CPU sleeps, Dart timers don't advance. This lets the collector take an
  /// overdue sample while the native wake lock is held. iOS sends it on keep-alive location
  /// updates, at most every 30 s.
  void wakeTick();

  /// iOS only: a BGProcessingTask or the "Upload now" button asks the collector engine to
  /// drain the buffer now (if the upload constraints are met). It reports back through
  /// IosCollectorApi.uploadRunFinished.
  void uploadRequested();
}

// ---------------------------------------------------------------------------------------
// iOS collector (Phase 4). iOS-only: the generated Kotlin interface is never implemented on
// Android. Captures reuse CapturedSampleMessage, with the iOS rules of DATA_CONTRACT §3/§5.
// ---------------------------------------------------------------------------------------

/// A survey prompt the participant opened by tapping its notification.
class SurveyPromptMessage {
  SurveyPromptMessage({required this.triggerType, required this.promptedAtMs});

  /// PERIODIC, POST_SESSION or ANOMALY.
  String triggerType;
  int promptedAtMs;
}

/// CLAuthorizationStatus, as the onboarding needs it.
enum LocationAuthorizationMessage { notDetermined, denied, restricted, whenInUse, always }

@HostApi()
abstract class IosCollectorApi {
  /// One full capture, as AndroidCollectorApi.captureSample. Location waits at most
  /// [locationTimeoutMs]; a fix older than [staleAfterMs] is reported STALE.
  @async
  CapturedSampleMessage captureSample(int locationTimeoutMs, int staleAfterMs);

  /// Persists the flag, starts/stops background location and the headless collector engine,
  /// and schedules/cancels the upload BGProcessingTask.
  void setCollectionEnabled(bool enabled);

  /// serviceRunning = the headless collector engine is alive.
  CollectorStatusMessage status();

  /// Posts the actionable survey notification.
  void presentSurvey(String triggerType);

  List<SurveyAnswerMessage> pendingSurveyAnswers();

  void acknowledgeSurveyAnswers(List<String> responseIds);

  /// An answer from the in-app sheet, added to the same durable native queue.
  void submitSurveyAnswer(SurveyAnswerMessage answer);

  /// The prompt opened from a notification tap, if any. Reading it clears it.
  SurveyPromptMessage? takeOpenedSurveyPrompt();

  /// Unmetered usable network (not cellular, not a hotspot, not Low Data Mode) and Low Power
  /// Mode off: the iOS counterpart of WorkManager's unmetered + battery-not-low constraints.
  bool uploadConstraintsMet();

  /// Called by the collector engine when an upload run ends.
  void uploadRunFinished(bool success, int uploadedRows);

  /// Asks the collector engine to upload now (same constraints).
  void requestUploadNow();

  /// Opens this app's page in the Settings app.
  void openAppSettings();

  void recordConsent(int timestampMs);

  /// The When-In-Use prompt. Completes with the resulting status.
  @async
  LocationAuthorizationMessage requestLocationWhenInUse();

  /// The Always upgrade prompt (shown by iOS at most once). Completes with the resulting status.
  @async
  LocationAuthorizationMessage requestLocationAlways();

  /// The notification permission prompt. Completes with whether alerts are allowed.
  @async
  bool requestNotifications();
}

/// Native -> Dart events for the UI engine (iOS).
@FlutterApi()
abstract class SurveyUiEvents {
  /// The participant tapped a survey notification: show the in-app sheet
  /// (IosCollectorApi.takeOpenedSurveyPrompt has the prompt).
  void surveyPromptOpened();
}

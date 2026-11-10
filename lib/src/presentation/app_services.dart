import '../application/mos_pipeline.dart';
import '../application/stores.dart';
import '../data/backend/backend_ports.dart';
import '../data/local/telemetry_buffer.dart';
import '../domain/enums.dart';
import '../domain/telemetry_sample.dart';
import '../platform/capability_source.dart';

enum SettingsTarget { usageAccess, overlay, batteryOptimization, appDetails }

class CollectorStatus {
  const CollectorStatus({required this.enabled, required this.running, this.lastUploadMs});
  final bool enabled;
  final bool running;
  final int? lastUploadMs;
}

/// What the UI may ask the native collector to do.
abstract interface class CollectorControl {
  Future<void> setCollectionEnabled(bool enabled);
  Future<CollectorStatus> status();
  Future<void> presentTestSurvey();

  /// The reference "Run telemetry test": one full capture, recorded into the buffer.
  Future<TelemetrySample> runTestCapture();
  Future<void> openSettings(SettingsTarget target);
  Future<void> uploadNow();
  Future<void> recordConsent(int timestampMs);
}

/// Runtime-permission prompts (permission_handler on device, a fake in widget tests).
abstract interface class PermissionGateway {
  /// The reference location screen: fine + coarse location and phone state.
  Future<void> requestForeground();

  /// The reference background screen: "allow all the time" location and notifications.
  Future<void> requestBackground();
  Future<bool> isBatteryOptimizationIgnored();
}

/// A survey prompt the participant opened from its notification (iOS).
class SurveyPrompt {
  const SurveyPrompt({required this.triggerType, required this.promptedAtMs});
  final MosTriggerType triggerType;
  final int promptedAtMs;
}

/// The in-app survey sheet's link to the native survey queue. iOS only: Android draws its
/// survey natively over other apps.
abstract interface class SurveyInbox {
  /// Fires when a survey notification was tapped while the UI runs.
  Stream<void> get opened;

  /// The tapped prompt waiting for the sheet, if any. Reading it clears it.
  Future<SurveyPrompt?> takeOpened();

  /// Queues the sheet's answer natively, the same way a notification-action tap is queued.
  Future<void> submit(SurveyAnswer answer);
}

/// Everything the UI depends on, injected so screens are testable without a device.
class AppServices {
  const AppServices({
    required this.capabilities,
    required this.control,
    required this.permissions,
    required this.buffer,
    required this.settings,
    required this.backend,
    this.platform = ClientPlatform.android,
    this.surveyInbox,
  });

  final CapabilitySource capabilities;
  final CollectorControl control;
  final PermissionGateway permissions;
  final TelemetryBuffer buffer;
  final KeyValueStore settings;
  final Backend backend;

  /// Selects the platform's onboarding steps and texts.
  final ClientPlatform platform;

  /// iOS only (null on Android).
  final SurveyInbox? surveyInbox;
}

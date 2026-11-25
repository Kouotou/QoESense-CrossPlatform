import '../application/mos_pipeline.dart';
import '../application/stores.dart';
import '../data/backend/backend_ports.dart';
import '../data/local/telemetry_buffer.dart';
import '../domain/enums.dart';
import '../domain/telemetry_sample.dart';
import '../platform/capability_source.dart';

enum SettingsTarget { usageAccess, overlay, batteryOptimization, autoStart, backgroundPopup, appDetails }

/// Manufacturer families whose system stops apps from restarting on their own, each with
/// its own auto-start screen and instructions (report alignment, 2026-11-14). Android only.
enum AutoStartBrand {
  transsion,
  xiaomi,
  oppo,
  vivo,
  huawei,
  samsung,
  other;

  static AutoStartBrand fromWire(String name) =>
      AutoStartBrand.values.firstWhere((b) => b.name == name, orElse: () => AutoStartBrand.other);
}

class CollectorStatus {
  const CollectorStatus({required this.enabled, required this.running, this.lastUploadMs, this.mobileDataUploads});
  final bool enabled;
  final bool running;
  final int? lastUploadMs;

  /// Android: "upload on mobile data when there's no Wi-Fi". Null on iOS (Wi-Fi only), where
  /// the switch isn't shown.
  final bool? mobileDataUploads;
}

/// What the UI may ask the native collector to do.
abstract interface class CollectorControl {
  Future<void> setCollectionEnabled(bool enabled);
  Future<CollectorStatus> status();
  Future<void> presentTestSurvey();

  /// The reference "Run telemetry test": one full capture, recorded into the buffer.
  Future<TelemetrySample> runTestCapture();
  Future<void> openSettings(SettingsTarget target);

  /// The phone's auto-start family on Android; null on iOS, which has no such setting.
  Future<AutoStartBrand?> autoStartBrand();
  Future<void> uploadNow();
  Future<void> recordConsent(int timestampMs);
  Future<void> setMobileDataUploads(bool allowed);
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
    this.backgroundPopupStatus,
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

  /// Android: Xiaomi's background pop-up permission (allowed, denied, notApplicable or
  /// unknown). Null on iOS.
  final Future<String> Function()? backgroundPopupStatus;
}

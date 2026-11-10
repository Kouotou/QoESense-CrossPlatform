import 'dart:async';

import '../application/captured_sample.dart';
import '../application/collector.dart';
import '../application/mos_pipeline.dart';
import '../application/sampling_policy.dart';
import '../application/survey_scheduler.dart';
import '../data/local/telemetry_buffer.dart';
import '../data/network/http_rtt_probe.dart';
import '../domain/enums.dart';
import '../domain/telemetry_sample.dart';
import '../presentation/app_services.dart';
import 'android_collector.dart' show mapCapturedSample, mapSurveyAnswer, surveyAnswerMessage;
import 'telemetry_api.g.dart';

/// Dart adapters over the Pigeon-generated [IosCollectorApi] (docs/PHASE4_IOS.md §3). The
/// capture uses the same message and mapping as Android; only the platform differs.
class IosSampleSource implements SampleSource {
  IosSampleSource(this._api);
  final IosCollectorApi _api;

  @override
  Future<CapturedSample> capture({required int locationTimeoutMs, required int staleAfterMs}) async =>
      mapCapturedSample(await _api.captureSample(locationTimeoutMs, staleAfterMs), platform: ClientPlatform.ios);
}

class IosSurveyPresenter implements SurveyPresenter {
  IosSurveyPresenter(this._api);
  final IosCollectorApi _api;

  @override
  Future<void> present(MosTriggerType trigger) => _api.presentSurvey(trigger.wireName);
}

class IosSurveyAnswerQueue implements SurveyAnswerQueue {
  IosSurveyAnswerQueue(this._api);
  final IosCollectorApi _api;

  @override
  Future<List<SurveyAnswer>> pending() async => [for (final m in await _api.pendingSurveyAnswers()) mapSurveyAnswer(m)];

  @override
  Future<void> acknowledge(List<String> responseIds) => _api.acknowledgeSurveyAnswers(responseIds);
}

class IosCollectorControl implements CollectorControl {
  IosCollectorControl(this._api, this._buffer);
  final IosCollectorApi _api;
  final TelemetryBuffer _buffer;

  @override
  Future<void> setCollectionEnabled(bool enabled) => _api.setCollectionEnabled(enabled);

  @override
  Future<CollectorStatus> status() async {
    final s = await _api.status();
    return CollectorStatus(enabled: s.collectionEnabled, running: s.serviceRunning, lastUploadMs: s.lastUploadMs);
  }

  @override
  Future<void> presentTestSurvey() => _api.presentSurvey(MosTriggerType.periodic.wireName);

  @override
  Future<TelemetrySample> runTestCapture() async {
    final rtt = HttpRttProbe();
    final watch = Stopwatch()..start();
    final results = await Future.wait<Object>([
      IosSampleSource(_api).capture(
        locationTimeoutMs: SamplingPolicy.standardLocationTimeoutMs,
        staleAfterMs: SamplingPolicy.standardIntervalMs,
      ),
      rtt.measure(),
    ]);
    final now = DateTime.now();
    final sample = assembleSample(
      c: results[0] as CapturedSample,
      rtt: results[1] as RttResult,
      rttMethod: rtt.method,
      timestampMs: now.millisecondsSinceEpoch,
      captureDurationMs: watch.elapsedMilliseconds,
      utcOffsetMinutes: now.timeZoneOffset.inMinutes,
    );
    await _buffer.append(sample);
    return sample;
  }

  /// iOS has a single settings page per app; every target opens it.
  @override
  Future<void> openSettings(SettingsTarget target) => _api.openAppSettings();

  @override
  Future<void> uploadNow() => _api.requestUploadNow();

  @override
  Future<void> recordConsent(int timestampMs) => _api.recordConsent(timestampMs);
}

/// iOS permissions, asked natively (Core Location / UserNotifications) so the Always upgrade
/// prompt, which iOS shows at most once, is handled reliably.
class IosPermissionGateway implements PermissionGateway {
  IosPermissionGateway(this._api);
  final IosCollectorApi _api;

  /// When-In-Use location. iOS has no phone-state permission.
  @override
  Future<void> requestForeground() async {
    await _api.requestLocationWhenInUse();
  }

  /// Always location (only after When-In-Use is held), then notifications.
  @override
  Future<void> requestBackground() async {
    final status = await _api.requestLocationWhenInUse();
    if (status == LocationAuthorizationMessage.whenInUse) await _api.requestLocationAlways();
    await _api.requestNotifications();
  }

  /// iOS has no battery-optimization exemption to ask for.
  @override
  Future<bool> isBatteryOptimizationIgnored() async => true;
}

/// The in-app sheet's side of the iOS survey: native pings via [SurveyUiEvents].
class IosSurveyInbox implements SurveyInbox, SurveyUiEvents {
  IosSurveyInbox(this._api) {
    SurveyUiEvents.setUp(this);
  }

  final IosCollectorApi _api;
  final _opened = StreamController<void>.broadcast();

  @override
  Stream<void> get opened => _opened.stream;

  @override
  void surveyPromptOpened() => _opened.add(null);

  @override
  Future<SurveyPrompt?> takeOpened() async {
    final m = await _api.takeOpenedSurveyPrompt();
    if (m == null) return null;
    final trigger = MosTriggerType.values.where((t) => t.wireName == m.triggerType).firstOrNull;
    if (trigger == null) return null;
    return SurveyPrompt(triggerType: trigger, promptedAtMs: m.promptedAtMs);
  }

  @override
  Future<void> submit(SurveyAnswer answer) => _api.submitSurveyAnswer(surveyAnswerMessage(answer));
}

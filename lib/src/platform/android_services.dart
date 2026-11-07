import 'package:permission_handler/permission_handler.dart';

import '../application/captured_sample.dart';
import '../application/sampling_policy.dart';
import '../data/local/telemetry_buffer.dart';
import '../data/network/http_rtt_probe.dart';
import '../domain/enums.dart';
import '../domain/telemetry_sample.dart';
import '../presentation/app_services.dart';
import 'android_collector.dart';
import 'telemetry_api.g.dart';

class AndroidCollectorControl implements CollectorControl {
  AndroidCollectorControl(this._api, this._buffer);
  final AndroidCollectorApi _api;
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
      AndroidSampleSource(_api).capture(
        locationTimeoutMs: SamplingPolicy.standardLocationTimeoutMs,
        staleAfterMs: SamplingPolicy.standardIntervalMs,
      ),
      rtt.measure(), // the reference test button always measures RTT
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

  @override
  Future<void> openSettings(SettingsTarget target) => _api.openSystemSettings(target.name);

  @override
  Future<void> uploadNow() => _api.requestUploadNow();

  @override
  Future<void> recordConsent(int timestampMs) => _api.recordConsent(timestampMs);
}

class PermissionHandlerGateway implements PermissionGateway {
  @override
  Future<void> requestForeground() async {
    await [Permission.location, Permission.phone].request();
  }

  @override
  Future<void> requestBackground() async {
    // Android only offers "Allow all the time" once foreground location is held.
    if (await Permission.location.isGranted) await Permission.locationAlways.request();
    await Permission.notification.request();
  }

  @override
  Future<bool> isBatteryOptimizationIgnored() => Permission.ignoreBatteryOptimizations.isGranted;
}

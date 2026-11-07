import 'dart:async';

import '../data/local/telemetry_buffer.dart';
import '../domain/enums.dart';
import '../domain/telemetry_sample.dart';
import 'captured_sample.dart';
import 'rsrp_anomaly_detector.dart';
import 'sampling_policy.dart';
import 'survey_scheduler.dart';

/// One native capture per tick (everything except RTT).
abstract interface class SampleSource {
  /// [staleAfterMs] is the current sampling interval: an older radio/location reading can't
  /// be from this tick, so it is reported STALE (with its value kept).
  Future<CapturedSample> capture({required int locationTimeoutMs, required int staleAfterMs});
}

/// Shared RTT probe (see HttpRttProbe).
abstract interface class RttProbe {
  String get method;
  Future<RttResult> measure();
}

/// Port of the reference TelemetryForegroundService loop body (../QoESense
/// service/TelemetryForegroundService.kt), step for step:
/// capture → buffer → periodic check → session-end check → RSRP window → anomaly check;
/// a failed tick is logged and the loop continues; fixed-rate delay from the tick start.
/// It runs in the headless Flutter engine that the native foreground service starts.
class Collector {
  Collector({
    required this.source,
    required this.rtt,
    required this.buffer,
    required this.surveys,
    this.clock = DateTime.now,
    Stopwatch Function()? stopwatch,
    this.onError,
    this.onSample,
  }) : _stopwatch = stopwatch ?? (() => Stopwatch()..start());

  final SampleSource source;
  final RttProbe rtt;
  final TelemetryBuffer buffer;
  final SurveyScheduler surveys;
  final DateTime Function() clock;
  final Stopwatch Function() _stopwatch;
  final void Function(Object error, StackTrace stack)? onError;
  final void Function(TelemetrySample sample)? onSample;

  int sampleCount = 0;
  AppSessionType lastSessionType = AppSessionType.none;
  final List<int> recentRsrp = [];
  bool _running = false;

  /// One iteration. Returns the delay until the next tick (fixed-rate).
  Future<int> tick() async {
    final tickWatch = _stopwatch();
    sampleCount++;
    try {
      final measureRtt = SamplingPolicy.shouldMeasureRtt(lastSessionType, sampleCount);
      final results = await Future.wait<Object>([
        source.capture(
          locationTimeoutMs: SamplingPolicy.locationTimeoutFor(lastSessionType),
          staleAfterMs: SamplingPolicy.intervalFor(lastSessionType),
        ),
        if (measureRtt) rtt.measure() else Future.value(const RttResult.notAttempted()),
      ]);
      final now = clock();
      final sample = assembleSample(
        c: results[0] as CapturedSample,
        rtt: results[1] as RttResult,
        rttMethod: rtt.method,
        timestampMs: now.millisecondsSinceEpoch,
        captureDurationMs: tickWatch.elapsedMilliseconds,
        utcOffsetMinutes: now.timeZoneOffset.inMinutes,
      );
      await buffer.append(sample);
      onSample?.call(sample);
      await surveys.maybeTriggerPeriodic();

      final previous = lastSessionType;
      lastSessionType = sample.appSessionType;
      // Reference semantics: any change away from a non-NONE session counts as "ended",
      // including SOCIAL_MEDIA -> VIDEO_CONFERENCING.
      if (previous != AppSessionType.none && previous != lastSessionType) {
        await surveys.maybeTriggerPostSession();
      }

      final rsrp = sample.rsrp;
      if (rsrp != null) {
        recentRsrp.add(rsrp);
        while (recentRsrp.length > RsrpAnomalyDetector.stabilityWindowSize) {
          recentRsrp.removeAt(0);
        }
      }
      final reason = RsrpAnomalyDetector.detect(recentRsrp);
      if (reason != null) await surveys.maybeTriggerAnomaly(reason);
    } catch (e, st) {
      // One bad sample must not take down weeks of collection.
      onError?.call(e, st);
    }
    return SamplingPolicy.delayUntilNextTick(
      tickStartMs: 0,
      nowMs: tickWatch.elapsedMilliseconds,
      intervalMs: SamplingPolicy.intervalFor(lastSessionType),
    );
  }

  /// Runs ticks until [stop]. [afterTick] lets the entrypoint piggyback light work (the MOS
  /// pipeline) without delaying the cadence.
  Future<void> run({void Function()? afterTick}) async {
    if (_running) return;
    _running = true;
    await surveys.ensureBaseline();
    while (_running) {
      final delayMs = await tick();
      afterTick?.call();
      if (!_running) break;
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }
  }

  void stop() => _running = false;
}

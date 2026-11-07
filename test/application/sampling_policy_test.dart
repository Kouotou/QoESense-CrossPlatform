import 'package:flutter_test/flutter_test.dart';
import 'package:qoesense/src/application/sampling_policy.dart';
import 'package:qoesense/src/domain/enums.dart';

/// Mirrors ../QoESense app/src/test/.../SamplingSchedulerTest.kt case for case.
void main() {
  test('standard interval at rest', () {
    expect(SamplingPolicy.intervalFor(AppSessionType.none), SamplingPolicy.standardIntervalMs);
    expect(SamplingPolicy.intervalFor(AppSessionType.socialMedia), SamplingPolicy.standardIntervalMs);
  });

  test('elevated interval only during video conferencing', () {
    expect(SamplingPolicy.intervalFor(AppSessionType.videoConferencing), SamplingPolicy.elevatedIntervalMs);
  });

  test('agreed intervals - 60s at rest, 15s during a video call (not the handbook 20s/5s)', () {
    expect(SamplingPolicy.standardIntervalMs, 60000);
    expect(SamplingPolicy.elevatedIntervalMs, 15000);
  });

  test('location wait fits inside the elevated interval', () {
    expect(SamplingPolicy.elevatedLocationTimeoutMs, lessThan(SamplingPolicy.elevatedIntervalMs));
    expect(SamplingPolicy.locationTimeoutFor(AppSessionType.videoConferencing), 8000);
    expect(SamplingPolicy.locationTimeoutFor(AppSessionType.none), 15000);
  });

  test('fixed-rate - capture time is subtracted from the wait', () {
    expect(SamplingPolicy.delayUntilNextTick(tickStartMs: 1000, nowMs: 10000, intervalMs: 15000), 6000);
  });

  test('fixed-rate - overrun starts the next tick immediately, never negative', () {
    expect(SamplingPolicy.delayUntilNextTick(tickStartMs: 0, nowMs: 20000, intervalMs: 15000), 0);
  });

  test('fixed-rate - a clock oddity never waits longer than one interval', () {
    expect(SamplingPolicy.delayUntilNextTick(tickStartMs: 10000, nowMs: 5000, intervalMs: 15000), 15000);
  });

  test('RTT at rest about every 5 minutes, every tick during a call', () {
    final atRest = [for (var i = 1; i <= 10; i++) i]
        .where((i) => SamplingPolicy.shouldMeasureRtt(AppSessionType.none, i));
    expect(atRest, hasLength(2)); // 10 ticks x 60 s = 10 min -> 2 probes
    expect(
      [for (var i = 1; i <= 10; i++) i]
          .every((i) => SamplingPolicy.shouldMeasureRtt(AppSessionType.videoConferencing, i)),
      isTrue,
    );
  });

  test('RTT only forced every tick during video conferencing', () {
    expect(SamplingPolicy.shouldAlwaysMeasureRtt(AppSessionType.videoConferencing), isTrue);
    expect(SamplingPolicy.shouldAlwaysMeasureRtt(AppSessionType.socialMedia), isFalse);
    expect(SamplingPolicy.shouldAlwaysMeasureRtt(AppSessionType.none), isFalse);
  });
}

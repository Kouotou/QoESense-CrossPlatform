import 'package:flutter_test/flutter_test.dart';
import 'package:qoesense/src/application/captured_sample.dart';
import 'package:qoesense/src/application/path_anomaly_detector.dart';
import 'package:qoesense/src/application/rsrp_anomaly_detector.dart';
import 'package:qoesense/src/domain/enums.dart';
import 'package:qoesense/src/domain/telemetry_sample.dart';

import '../support/fakes.dart';

/// The proposed iOS anomaly rules (docs/PHASE4_IOS.md §6).
void main() {
  TelemetrySample sample({
    String? connection = 'CELLULAR',
    FieldStatus connectivity = FieldStatus.ok,
    String? rat = 'LTE',
    RttResult rtt = const RttResult.notAttempted(),
    bool inCall = false,
    int atMs = 1,
  }) => assembleSample(
    c: iosCaptured(
      connectionType: connection,
      connectivityStatus: connectivity,
      networkType: rat,
      session: inCall ? AppSessionType.videoConferencing : AppSessionType.none,
    ),
    rtt: rtt,
    rttMethod: 'TEST',
    timestampMs: atMs,
    captureDurationMs: 1,
    utcOffsetMinutes: 60,
  );

  List<AnomalyReason?> feed(PathAnomalyDetector d, List<TelemetrySample> samples) => [
    for (final s in samples) d.observe(s),
  ];

  test('a call falling back from LTE to 3G (CSFB) is not a RAT downgrade, nor is the climb back', () {
    final d = PathAnomalyDetector();
    const s = 1000;
    expect(
      feed(d, [
        sample(atMs: 0),
        sample(rat: 'OTHER', inCall: true, atMs: 15 * s), // CSFB during the call
        sample(rat: 'OTHER', inCall: true, atMs: 30 * s),
        sample(rat: 'OTHER', atMs: 45 * s), // call ended, still on 3G for a moment
        sample(atMs: 105 * s), // back on LTE
        sample(atMs: 165 * s),
      ]),
      everyElement(isNull),
    );
  });

  test('a real downgrade after the post-call grace period is still flagged', () {
    final d = PathAnomalyDetector();
    const s = 1000;
    expect(
      feed(d, [
        sample(atMs: 0),
        sample(rat: 'OTHER', inCall: true, atMs: 15 * s),
        sample(atMs: 30 * s), // call ended
        sample(atMs: 120 * s), // grace over: LTE remembered again
        sample(rat: 'OTHER', atMs: 180 * s),
      ]),
      [null, null, null, null, AnomalyReason.ratDowngrade],
    );
  });

  test('a steady path flags nothing', () {
    final d = PathAnomalyDetector();
    expect(feed(d, List.generate(20, (_) => sample())), everyElement(isNull));
  });

  test('losing the network, and switching Wi-Fi <-> cellular, are flagged once each', () {
    final d = PathAnomalyDetector();
    expect(
      feed(d, [
        sample(connection: 'WIFI'),
        sample(connection: 'CELLULAR'),
        sample(connection: 'CELLULAR'),
        sample(connection: null, connectivity: FieldStatus.unavailable),
        sample(connection: null, connectivity: FieldStatus.unavailable),
        sample(connection: 'WIFI'), // back after a loss: not a second anomaly
      ]),
      [null, AnomalyReason.pathChange, null, AnomalyReason.connectivityLoss, null, null],
    );
  });

  test('the first sample has no baseline, so nothing is flagged', () {
    expect(PathAnomalyDetector().observe(sample(connection: 'WIFI')), isNull);
  });

  test('a RAT downgrade on cellular is flagged; NR <-> LTE flips are not', () {
    final d = PathAnomalyDetector();
    expect(
      feed(d, [
        sample(rat: 'NR'),
        sample(rat: 'LTE'),
        sample(rat: 'NR'),
        sample(rat: 'OTHER'),
        sample(rat: 'OTHER'),
        sample(rat: 'LTE'),
        sample(rat: 'UNKNOWN'),
      ]),
      [null, null, null, AnomalyReason.ratDowngrade, null, null, AnomalyReason.ratDowngrade],
    );
  });

  test('on Wi-Fi the cellular RAT is not a trigger', () {
    final d = PathAnomalyDetector();
    expect(feed(d, [sample(connection: 'WIFI', rat: 'LTE'), sample(connection: 'WIFI', rat: 'OTHER')]), [null, null]);
  });

  test('an RTT spike needs a baseline, twice the median and +200 ms', () {
    final d = PathAnomalyDetector();
    RttResult ms(int v) => RttResult(FieldStatus.ok, v);
    final baseline = feed(d, [
      for (final v in [100, 110, 90, 105, 95]) sample(rtt: ms(v)),
    ]);
    expect(baseline, everyElement(isNull));
    expect(d.observe(sample(rtt: ms(250))), isNull, reason: 'over 2x but only +150 ms');
    expect(d.observe(sample(rtt: ms(320))), AnomalyReason.latencySpike);
  });

  test('no RTT spike before the baseline exists', () {
    final d = PathAnomalyDetector();
    expect(
      feed(d, [sample(rtt: const RttResult(FieldStatus.ok, 80)), sample(rtt: const RttResult(FieldStatus.ok, 900))]),
      [null, null],
    );
  });

  test('two failed probes in a row on a usable path are flagged; a success resets the count', () {
    final d = PathAnomalyDetector();
    const timeout = RttResult(FieldStatus.timeout);
    const failed = RttResult(FieldStatus.failed);
    const ok = RttResult(FieldStatus.ok, 90);
    expect(feed(d, [sample(rtt: timeout), sample(rtt: ok), sample(rtt: failed), sample(rtt: timeout)]), [
      null,
      null,
      null,
      AnomalyReason.probeFailures,
    ]);
  });

  test('probe failures while offline are part of the loss, not a second trigger', () {
    final d = PathAnomalyDetector();
    const timeout = RttResult(FieldStatus.timeout);
    expect(
      feed(d, [
        sample(),
        sample(connection: null, connectivity: FieldStatus.unavailable, rtt: timeout),
        sample(connection: null, connectivity: FieldStatus.unavailable, rtt: timeout),
      ]),
      [null, AnomalyReason.connectivityLoss, null],
    );
  });
}

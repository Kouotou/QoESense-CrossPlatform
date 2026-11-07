import 'package:flutter_test/flutter_test.dart';
import 'package:qoesense/src/application/collector.dart';
import 'package:qoesense/src/application/rsrp_anomaly_detector.dart';
import 'package:qoesense/src/application/sampling_policy.dart';
import 'package:qoesense/src/application/stores.dart';
import 'package:qoesense/src/application/survey_scheduler.dart';
import 'package:qoesense/src/data/local/telemetry_buffer.dart';
import 'package:qoesense/src/domain/contract_rules.dart';
import 'package:qoesense/src/domain/enums.dart';

import '../support/fakes.dart';

/// Regression tests mirroring the reference TelemetryForegroundService loop.
void main() {
  late InMemoryTelemetryBuffer buffer;
  late InMemoryKeyValueStore kv;
  late RecordingPresenter presenter;
  late CountingRtt rtt;
  var now = DateTime.utc(2026, 11, 7, 10);

  Collector collector(ScriptedSource source) => Collector(
    source: source,
    rtt: rtt,
    buffer: buffer,
    surveys: SurveyScheduler(store: kv, presenter: presenter, clock: () => now),
    clock: () => now,
  );

  setUp(() {
    buffer = InMemoryTelemetryBuffer();
    kv = InMemoryKeyValueStore();
    presenter = RecordingPresenter();
    rtt = CountingRtt();
    now = DateTime.utc(2026, 11, 7, 10);
  });

  test('every tick buffers one contract-valid sample before anything else', () async {
    final c = collector(ScriptedSource([captured]));
    await c.tick();
    final rows = await buffer.oldest(10);
    expect(rows, hasLength(1));
    expect(contractViolations(rows.single.sample), isEmpty);
  });

  test('cadence: 60 s at rest, 15 s once a video call is seen', () async {
    final source = ScriptedSource([
      captured,
      () => captured(session: AppSessionType.videoConferencing, foregroundAppPackage: 'us.zoom.videomeetings'),
    ]);
    final c = collector(source);
    final atRest = await c.tick();
    final inCall = await c.tick();
    expect(atRest, inInclusiveRange(SamplingPolicy.standardIntervalMs - 1000, SamplingPolicy.standardIntervalMs));
    expect(inCall, inInclusiveRange(SamplingPolicy.elevatedIntervalMs - 1000, SamplingPolicy.elevatedIntervalMs));
    // The location budget and the stale limit follow the session seen on the previous tick.
    await c.tick();
    expect(source.timeouts, [15000, 15000, 8000]);
    expect(source.staleLimits, [60000, 60000, 15000]);
  });

  test('RTT: every 5th tick at rest (not attempted otherwise), every tick in a call', () async {
    final c = collector(ScriptedSource([captured]));
    for (var i = 0; i < 10; i++) {
      await c.tick();
    }
    expect(rtt.calls, 2);
    final statuses = [for (final r in await buffer.oldest(10)) r.sample.provenance.statusOf(SampleFieldGroup.rtt)];
    expect(statuses.where((s) => s == FieldStatus.notAttempted), hasLength(8));

    final call = collector(
      ScriptedSource([
        () => captured(session: AppSessionType.videoConferencing, foregroundAppPackage: 'us.zoom.videomeetings'),
      ]),
    );
    rtt.calls = 0;
    await call.tick(); // first tick: lastSession is still NONE -> tick 1 is not an RTT tick
    for (var i = 0; i < 5; i++) {
      await call.tick();
    }
    expect(rtt.calls, 5);
  });

  test('a session ending fires the post-session check (reference: any change away from non-NONE)', () async {
    await kv.write('survey.lastPromptMs', '${now.millisecondsSinceEpoch - 16 * 60 * 1000}');
    final c = collector(
      ScriptedSource([
        captured, // SOCIAL_MEDIA
        () => captured(session: AppSessionType.none, foregroundAppPackage: 'com.android.launcher'),
      ]),
    );
    await c.tick();
    expect(presenter.shown, isEmpty);
    await c.tick();
    expect(presenter.shown, [MosTriggerType.postSession]);
  });

  test('an RSRP drop of >= 10 dB triggers an ANOMALY prompt once its cooldown allows', () async {
    await kv.write('survey.lastPromptMs', '${now.millisecondsSinceEpoch - 11 * 60 * 1000}');
    final script = [
      for (var i = 0; i < 10; i++) () => captured(rsrp: -85),
      for (var i = 0; i < 3; i++) () => captured(rsrp: -100),
    ];
    final c = collector(ScriptedSource(script));
    for (var i = 0; i < 13; i++) {
      await c.tick();
    }
    expect(presenter.shown, [MosTriggerType.anomaly]);
    expect(RsrpAnomalyDetector.detect(c.recentRsrp), AnomalyReason.signalDrop);
  });

  test('the RSRP window holds at most 15 readings; samples without RSRP are not added', () async {
    final c = collector(
      ScriptedSource([
        for (var i = 0; i < 20; i++) () => captured(rsrp: -90 - i),
        () => captured(radioStatus: FieldStatus.permissionDenied),
      ]),
    );
    for (var i = 0; i < 21; i++) {
      await c.tick();
    }
    expect(c.recentRsrp, hasLength(15));
    expect(c.recentRsrp.last, -109);
  });

  test('STALE (cached) RSRP readings never enter the anomaly window', () async {
    final c = collector(
      ScriptedSource([
        () => captured(rsrp: -90),
        () => captured(rsrp: -90, radioStatus: FieldStatus.stale),
        () => captured(rsrp: -91),
      ]),
    );
    for (var i = 0; i < 3; i++) {
      await c.tick();
    }
    expect(c.recentRsrp, [-90, -91]);
  });

  test('a failed capture is logged and the loop keeps going (one bad tick never stops collection)', () async {
    final errors = <Object>[];
    final source = ScriptedSource([captured])..throwOnNext = StateError('modem busy');
    final c = Collector(
      source: source,
      rtt: rtt,
      buffer: buffer,
      surveys: SurveyScheduler(store: kv, presenter: presenter, clock: () => now),
      clock: () => now,
      onError: (e, _) => errors.add(e),
    );
    final delay = await c.tick();
    expect(errors, hasLength(1));
    expect(delay, greaterThan(0));
    await c.tick();
    expect(await buffer.count(), 1);
  });

  test('no prompt fires right after install: the first run writes the baseline', () async {
    final c = collector(ScriptedSource([captured]));
    final surveys = SurveyScheduler(store: kv, presenter: presenter, clock: () => now);
    await surveys.ensureBaseline();
    now = now.add(const Duration(hours: 1, minutes: 59));
    await c.tick();
    expect(presenter.shown, isEmpty);
    now = now.add(const Duration(minutes: 1));
    await c.tick();
    expect(presenter.shown, [MosTriggerType.periodic]);
  });

  test('the daily cap of 6 holds across trigger types and resets at local midnight', () async {
    final surveys = SurveyScheduler(store: kv, presenter: presenter, clock: () => now);
    await surveys.ensureBaseline();
    for (var i = 0; i < 8; i++) {
      now = now.add(const Duration(minutes: 11));
      await surveys.maybeTriggerAnomaly(AnomalyReason.signalDrop);
    }
    expect(presenter.shown, hasLength(6));
    now = now.add(const Duration(days: 1));
    expect(await surveys.maybeTriggerAnomaly(AnomalyReason.signalDrop), isTrue);
  });
}

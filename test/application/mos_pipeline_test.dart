import 'package:flutter_test/flutter_test.dart';
import 'package:qoesense/src/application/captured_sample.dart';
import 'package:qoesense/src/application/mos_pipeline.dart';
import 'package:qoesense/src/application/stores.dart';
import 'package:qoesense/src/data/local/telemetry_buffer.dart';
import 'package:qoesense/src/domain/enums.dart';

import '../support/fakes.dart';

void main() {
  const tap = 1762500600000;
  late FakeAnswerQueue answers;
  late InMemoryTelemetryBuffer buffer;
  late InMemoryPendingMosStore pending;
  late FakeMosSink sink;
  late FakeIdentity identity;
  var now = DateTime.fromMillisecondsSinceEpoch(tap);

  MosPipeline pipeline() => MosPipeline(
    answers: answers,
    buffer: buffer,
    pending: pending,
    identity: identity,
    sink: sink,
    app: testApp,
    platform: ClientPlatform.android,
    clock: () => now,
  );

  SurveyAnswer answer(String id, {int score = 3}) => SurveyAnswer(
    responseId: id,
    score: score,
    triggerType: MosTriggerType.anomaly,
    tapMs: tap,
    promptedAtMs: tap - 4000,
    presentationMode: PresentationMode.overlay,
  );

  Future<void> bufferAt(int ts, {String pkg = 'com.whatsapp', AppSessionType s = AppSessionType.socialMedia}) =>
      buffer.append(
        assembleSample(
          c: captured(foregroundAppPackage: pkg, session: s),
          rtt: const RttResult.notAttempted(),
          rttMethod: null,
          timestampMs: ts,
          captureDurationMs: 100,
          utcOffsetMinutes: 60,
        ),
      );

  setUp(() {
    answers = FakeAnswerQueue();
    buffer = InMemoryTelemetryBuffer();
    pending = InMemoryPendingMosStore();
    sink = FakeMosSink();
    identity = FakeIdentity();
    now = DateTime.fromMillisecondsSinceEpoch(tap);
  });

  test('context comes from the latest buffered sample inside the 10-minute window', () async {
    await bufferAt(tap - 11 * 60 * 1000, pkg: 'us.zoom.videomeetings', s: AppSessionType.videoConferencing); // outside
    await bufferAt(tap - 5 * 60 * 1000);
    await bufferAt(tap + 1000, pkg: 'com.instagram.android'); // after the tap: excluded
    answers.queue.add(answer('r1'));
    await pipeline().run();
    final body = sink.written['r1']!;
    expect(body['contextAppPackage'], 'com.whatsapp');
    expect(body['contextSessionType'], 'SOCIAL_MEDIA');
    expect(body['contextSource'], 'OBSERVED');
    expect(body['windowStartMs'], tap - 10 * 60 * 1000);
    expect(body['presentationMode'], 'OVERLAY');
    expect(body['promptedAtMs'], tap - 4000);
  });

  test('no sample in the window: context is UNKNOWN, never guessed', () async {
    answers.queue.add(answer('r1'));
    await pipeline().run();
    expect(sink.written['r1']!['contextSource'], 'UNKNOWN');
    expect(sink.written['r1']!['contextAppPackage'], isNull);
    expect(sink.written['r1']!['contextSessionType'], 'NONE');
  });

  test('a tap is acknowledged to native only after it is durably queued', () async {
    sink.succeed = false;
    answers.queue.add(answer('r1'));
    await pipeline().run();
    expect(answers.acknowledged, ['r1']);
    expect((await pending.all()).map((p) => p.responseId), ['r1']);
  });

  test('offline: the rating stays queued and is retried later - never dropped', () async {
    sink.succeed = false;
    answers.queue.add(answer('r1'));
    final p = pipeline();
    await p.run();
    // Many failed attempts later (the reference gave up after 10), it's still there.
    for (var i = 0; i < 15; i++) {
      now = now.add(const Duration(hours: 2));
      await p.run();
    }
    expect((await pending.all()).single.attempts, greaterThanOrEqualTo(15));
    sink.succeed = true;
    now = now.add(const Duration(hours: 2));
    await p.run();
    expect(await pending.all(), isEmpty);
    expect(sink.written.keys, ['r1']);
  });

  test('backoff: a failed rating is not retried on every 15 s tick', () async {
    sink.succeed = false;
    answers.queue.add(answer('r1'));
    final p = pipeline();
    await p.run();
    final calls = sink.calls;
    now = now.add(const Duration(seconds: 15));
    await p.run();
    expect(sink.calls, calls);
  });

  test('no identity yet: nothing is sent, nothing is lost', () async {
    identity.id = null;
    answers.queue.add(answer('r1'));
    await pipeline().run();
    expect(sink.calls, 0);
    expect(await pending.all(), hasLength(1));
  });

  test('the same tap delivered twice produces one rating (idempotent on responseId)', () async {
    answers.queue.add(answer('r1'));
    final p = pipeline();
    await p.intake();
    answers.queue.add(answer('r1'));
    await p.intake();
    expect(await pending.all(), hasLength(1));
  });

  test('backoff grows exponentially and is capped at 1 h', () {
    expect(MosPipeline.backoffMs(1), 60000);
    expect(MosPipeline.backoffMs(2), 120000);
    expect(MosPipeline.backoffMs(20), MosPipeline.maxBackoffMs);
  });
}

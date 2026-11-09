import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qoesense/src/application/collector.dart';
import 'package:qoesense/src/application/stores.dart';
import 'package:qoesense/src/application/survey_scheduler.dart';
import 'package:qoesense/src/data/local/telemetry_buffer.dart';

import '../support/fakes.dart';

/// Decision C: in Doze the CPU is suspended, so monotonic timers stand still while the wall
/// clock moves on. Simulated here by advancing the wall clock WITHOUT elapsing fake time.
void main() {
  late DateTime wall;
  late InMemoryTelemetryBuffer buffer;

  Collector build() => Collector(
    source: ScriptedSource([captured]),
    rtt: CountingRtt(),
    buffer: buffer,
    surveys: SurveyScheduler(store: InMemoryKeyValueStore(), presenter: RecordingPresenter(), clock: () => wall),
    clock: () => wall,
  );

  setUp(() {
    wall = DateTime.utc(2026, 11, 9, 2);
    buffer = InMemoryTelemetryBuffer();
  });

  test('awake: one sample per 60 s; wake-ups inside the interval add nothing', () {
    fakeAsync((async) {
      final c = build();
      c.run();
      async.flushMicrotasks();
      expect(buffer.oldest(100).then((r) => r.length), completion(1));
      wall = wall.add(const Duration(seconds: 30));
      async.elapse(const Duration(seconds: 30));
      c.wake(); // e.g. an alarm while the screen is on
      async.flushMicrotasks();
      expect(buffer.count(), completion(1));
      wall = wall.add(const Duration(seconds: 30));
      async.elapse(const Duration(seconds: 30));
      async.flushMicrotasks();
      expect(buffer.count(), completion(2));
      c.stop();
      async.flushMicrotasks();
    });
  });

  test('asleep: no timer fires, but a wake-up after 10 wall-clock minutes takes the overdue sample', () {
    fakeAsync((async) {
      final c = build();
      c.run();
      async.flushMicrotasks();
      expect(buffer.count(), completion(1));
      // Doze: 10 minutes pass on the wall clock, monotonic time doesn't move.
      wall = wall.add(const Duration(minutes: 10));
      async.flushMicrotasks();
      expect(buffer.count(), completion(1), reason: 'timers are frozen while the CPU sleeps');
      c.wake();
      async.flushMicrotasks();
      expect(buffer.count(), completion(2));
      c.stop();
      async.flushMicrotasks();
    });
  });
}

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:qoesense/src/application/stores.dart';
import 'package:qoesense/src/application/upload_gate.dart';

/// The iOS in-loop upload schedule (docs/PHASE4_IOS.md §3).
void main() {
  late InMemoryKeyValueStore kv;
  var now = DateTime.utc(2026, 11, 9, 12);
  var runs = 0;
  var allowed = true;

  UploadGate gate() => UploadGate(store: kv, clock: () => now);
  Future<bool> attempt(UploadGate g, {bool force = false}) =>
      g.maybeRun(force: force, allowed: () async => allowed, body: () async => runs++);

  setUp(() {
    kv = InMemoryKeyValueStore();
    now = DateTime.utc(2026, 11, 9, 12);
    runs = 0;
    allowed = true;
  });

  test('runs at most once an hour', () async {
    final g = gate();
    expect(await attempt(g), isTrue);
    now = now.add(const Duration(minutes: 59));
    expect(await attempt(g), isFalse);
    now = now.add(const Duration(minutes: 1));
    expect(await attempt(g), isTrue);
    expect(runs, 2);
  });

  test('waits for the constraints without spending the hour', () async {
    final g = gate();
    allowed = false; // on cellular
    expect(await attempt(g), isFalse);
    now = now.add(const Duration(minutes: 5));
    allowed = true; // Wi-Fi again
    expect(await attempt(g), isTrue);
  });

  test('a forced run (BGTask, Upload now) skips the hour but not the constraints', () async {
    final g = gate();
    await attempt(g);
    expect(await attempt(g, force: true), isTrue);
    allowed = false;
    expect(await attempt(g, force: true), isFalse);
    expect(runs, 2);
  });

  test('never two runs at once', () async {
    final g = gate();
    final release = Completer<void>();
    final first = g.maybeRun(allowed: () async => true, body: () => release.future);
    await Future<void>.delayed(Duration.zero);
    expect(g.isRunning, isTrue);
    expect(await attempt(g, force: true), isFalse);
    release.complete();
    expect(await first, isTrue);
    expect(g.isRunning, isFalse);
  });

  test('the attempt is recorded before the run, and survives a restart', () async {
    await gate()
        .maybeRun(allowed: () async => true, body: () async => throw StateError('crash'))
        .catchError((_) => false);
    expect(await kv.read(UploadGate.lastAttemptKey), '${now.millisecondsSinceEpoch}');
    expect(await attempt(gate()), isFalse, reason: 'a fresh gate (new engine) still waits the hour');
  });

  test('a clock set backwards never blocks uploads', () async {
    await attempt(gate());
    now = now.subtract(const Duration(days: 1));
    expect(await attempt(gate()), isTrue);
  });
}

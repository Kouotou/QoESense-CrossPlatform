import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qoesense/src/application/upload_drain.dart';
import 'package:qoesense/src/data/backend/backend_ports.dart';
import 'package:qoesense/src/data/local/database.dart';
import 'package:qoesense/src/data/local/drift_stores.dart';
import 'package:qoesense/src/data/local/sample_codec.dart';
import 'package:qoesense/src/data/upload/batch_serializer.dart';
import 'package:qoesense/src/domain/enums.dart';

import '../support/fakes.dart';
import '../support/fixtures.dart';

/// Persistence regression tests against a real SQLite engine (in memory), the same code
/// that runs on the device.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late QoESenseDatabase db;
  late DriftTelemetryBuffer buffer;

  setUp(() {
    db = QoESenseDatabase(NativeDatabase.memory());
    buffer = DriftTelemetryBuffer(db);
  });
  tearDown(() => db.close());

  test('the storage codec round-trips every representative record exactly', () {
    const v2 = BatchSerializer(version: ContractVersion.v2);
    for (final s in allSamples) {
      final back = SampleCodec.decode(SampleCodec.encode(s));
      expect(v2.lineFields(back, 'u'), v2.lineFields(s, 'u'));
    }
  });

  test('corrupt storage is an error, never silently skipped', () {
    expect(() => SampleCodec.decode('{"timestampMs":"x"}'), throwsFormatException);
  });

  test('append -> oldest -> delete by id; count and watchCount follow', () async {
    for (final s in allSamples) {
      await buffer.append(s);
    }
    expect(await buffer.count(), 4);
    final rows = await buffer.oldest(10);
    expect(rows.map((r) => r.sample.timestampMs), [1762500000000, 1762500060000, 1762500060000, 1762500075000]);
    await buffer.deleteByIds([rows.first.id]);
    expect(await buffer.count(), 3);
    expect(await buffer.watchCount().first, 3);
  });

  test('retention deletes only rows older than the cutoff', () async {
    await buffer.append(sampleAt(1000));
    await buffer.append(sampleAt(5000));
    expect(await buffer.deleteOlderThan(2000), 1);
    expect((await buffer.oldest(10)).single.sample.timestampMs, 5000);
  });

  test('latestInWindow picks the newest sample inside [start, end]', () async {
    await buffer.append(sampleAt(100));
    await buffer.append(sampleAt(200));
    await buffer.append(sampleAt(300));
    expect((await buffer.latestInWindow(100, 250))!.timestampMs, 200);
    expect(await buffer.latestInWindow(400, 500), isNull);
  });

  test('the upload drain works against SQLite: 2 x 2000 + rest, deletes only what uploaded', () async {
    for (var i = 0; i < 4100; i++) {
      await buffer.append(sampleAt(DateTime(2026, 11, 7).millisecondsSinceEpoch + i));
    }
    final dest = FakeBatchDestination();
    final result = await UploadDrain(
      buffer: buffer,
      identity: FakeIdentity(),
      destination: dest,
      clock: () => DateTime(2026, 11, 7, 12),
      newBatchId: () => 'b',
    ).run();
    expect(result.uploadedRows, 4100);
    expect(dest.paths, hasLength(3));
    expect(await buffer.count(), 0);
  });

  test('an unconfigured backend never deletes buffered data', () async {
    await buffer.append(sampleAt(DateTime(2026, 11, 7).millisecondsSinceEpoch));
    await UploadDrain(
      buffer: buffer,
      identity: const UnconfiguredDeviceIdentity(),
      destination: const UnconfiguredBatchDestination(),
      clock: () => DateTime(2026, 11, 7, 12),
      newBatchId: () => 'b',
    ).run();
    expect(await buffer.count(), 1);
  });

  test('pending MOS queue: enqueue is idempotent, attempts count, remove on success', () async {
    final store = DriftPendingMosStore(db);
    await store.enqueue(mosAndroidOverlay, 1);
    await store.enqueue(mosAndroidOverlay, 2);
    expect(await store.all(), hasLength(1));
    await store.markAttempt(mosAndroidOverlay.responseId);
    expect((await store.all()).single.attempts, 1);
    expect((await store.all()).single.firestoreBody, mosAndroidOverlay.toFirestore());
    await store.remove(mosAndroidOverlay.responseId);
    expect(await store.all(), isEmpty);
  });

  test('key-value store: write, overwrite, writeAll', () async {
    final kv = DriftKeyValueStore(db);
    await kv.write('a', '1');
    await kv.write('a', '2');
    await kv.writeAll({'b': '3', 'c': '4'});
    expect([await kv.read('a'), await kv.read('b'), await kv.read('c'), await kv.read('z')], ['2', '3', '4', null]);
  });
}

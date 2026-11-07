import 'dart:convert';

import 'package:drift/drift.dart';

import '../../application/stores.dart';
import '../../domain/mos_response.dart';
import '../../domain/telemetry_sample.dart';
import 'database.dart';
import 'sample_codec.dart';
import 'telemetry_buffer.dart';

/// Durable [TelemetryBuffer] on SQLite. Same guarantees as the reference Room table: append
/// before anything else, oldest-first reads, deletion only by id (after a confirmed upload)
/// or by retention.
class DriftTelemetryBuffer implements TelemetryBuffer {
  DriftTelemetryBuffer(this._db);
  final QoESenseDatabase _db;

  @override
  Future<int> append(TelemetrySample sample) => _db
      .into(_db.bufferedSamples)
      .insert(BufferedSamplesCompanion.insert(timestampMs: sample.timestampMs, payload: SampleCodec.encode(sample)));

  @override
  Future<List<BufferedSample>> oldest(int limit) async {
    final rows =
        await (_db.select(_db.bufferedSamples)
              ..orderBy([(t) => OrderingTerm.asc(t.timestampMs), (t) => OrderingTerm.asc(t.id)])
              ..limit(limit))
            .get();
    return [for (final r in rows) BufferedSample(r.id, SampleCodec.decode(r.payload))];
  }

  @override
  Future<void> deleteByIds(Iterable<int> ids) async {
    final list = ids.toList();
    // SQLite's bound-parameter limit is 32766; a batch is at most 2000 ids, so chunk generously.
    for (var i = 0; i < list.length; i += 900) {
      final chunk = list.sublist(i, i + 900 > list.length ? list.length : i + 900);
      await (_db.delete(_db.bufferedSamples)..where((t) => t.id.isIn(chunk))).go();
    }
  }

  @override
  Future<int> deleteOlderThan(int cutoffMs) =>
      (_db.delete(_db.bufferedSamples)..where((t) => t.timestampMs.isSmallerThanValue(cutoffMs))).go();

  @override
  Future<int> count() => _countQuery().getSingle();

  @override
  Stream<int> watchCount() => _countQuery().watchSingle();

  Selectable<int> _countQuery() {
    final c = _db.bufferedSamples.id.count();
    return (_db.selectOnly(_db.bufferedSamples)..addColumns([c])).map((r) => r.read(c)!);
  }

  @override
  Future<TelemetrySample?> latestInWindow(int startMs, int endMs) async {
    final row =
        await (_db.select(_db.bufferedSamples)
              ..where((t) => t.timestampMs.isBetweenValues(startMs, endMs))
              ..orderBy([(t) => OrderingTerm.desc(t.timestampMs), (t) => OrderingTerm.desc(t.id)])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : SampleCodec.decode(row.payload);
  }
}

class DriftKeyValueStore implements KeyValueStore {
  DriftKeyValueStore(this._db);
  final QoESenseDatabase _db;

  @override
  Future<String?> read(String key) async =>
      (await (_db.select(_db.keyValues)..where((t) => t.key.equals(key))).getSingleOrNull())?.value;

  @override
  Future<void> write(String key, String value) =>
      _db.into(_db.keyValues).insertOnConflictUpdate(KeyValuesCompanion.insert(key: key, value: value));

  @override
  Future<void> writeAll(Map<String, String> values) => _db.transaction(() async {
    for (final e in values.entries) {
      await write(e.key, e.value);
    }
  });
}

class DriftPendingMosStore implements PendingMosStore {
  DriftPendingMosStore(this._db);
  final QoESenseDatabase _db;

  @override
  Future<void> enqueue(MosResponse r, int nowMs) => _db
      .into(_db.pendingMosResponses)
      // Ignore on conflict: the same tap (same responseId) is never queued twice.
      .insert(
        PendingMosResponsesCompanion.insert(
          responseId: r.responseId,
          payload: jsonEncode(r.toFirestore()),
          createdAtMs: nowMs,
        ),
        mode: InsertMode.insertOrIgnore,
      );

  @override
  Future<List<PendingMos>> all() async {
    final rows = await (_db.select(_db.pendingMosResponses)..orderBy([(t) => OrderingTerm.asc(t.createdAtMs)])).get();
    return [
      for (final r in rows)
        PendingMos(
          responseId: r.responseId,
          firestoreBody: (jsonDecode(r.payload) as Map<String, Object?>),
          attempts: r.attempts,
        ),
    ];
  }

  @override
  Future<void> markAttempt(String responseId) => _db.customUpdate(
    'UPDATE pending_mos_responses SET attempts = attempts + 1 WHERE response_id = ?',
    variables: [Variable.withString(responseId)],
    updates: {_db.pendingMosResponses},
  );

  @override
  Future<void> remove(String responseId) =>
      (_db.delete(_db.pendingMosResponses)..where((t) => t.responseId.equals(responseId))).go();
}

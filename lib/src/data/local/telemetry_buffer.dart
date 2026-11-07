import 'dart:async';

import '../../domain/telemetry_sample.dart';

/// A buffered sample. A row's presence means "pending upload" (same semantics as the
/// reference app's Room table): it is deleted only after a confirmed upload, or by retention.
class BufferedSample {
  const BufferedSample(this.id, this.sample);
  final int id;
  final TelemetrySample sample;
}

/// Offline buffer port. Phase 2 adds the SQLite (drift) implementation; everything above
/// this interface - the upload drain, status counts - is already written and tested against
/// [InMemoryTelemetryBuffer].
abstract interface class TelemetryBuffer {
  /// Persists [sample] durably before anything else is done with it. Returns its row id.
  Future<int> append(TelemetrySample sample);

  /// Oldest-first by timestamp, then by id.
  Future<List<BufferedSample>> oldest(int limit);

  Future<void> deleteByIds(Iterable<int> ids);

  /// Removes rows with timestampMs < [cutoffMs]; returns how many.
  Future<int> deleteOlderThan(int cutoffMs);

  Future<int> count();

  Stream<int> watchCount();
}

/// Test/dev implementation. Not durable - never use it for real collection.
class InMemoryTelemetryBuffer implements TelemetryBuffer {
  final _rows = <int, TelemetrySample>{};
  final _counts = StreamController<int>.broadcast();
  int _nextId = 1;

  @override
  Future<int> append(TelemetrySample sample) async {
    final id = _nextId++;
    _rows[id] = sample;
    _emit();
    return id;
  }

  @override
  Future<List<BufferedSample>> oldest(int limit) async {
    final entries = _rows.entries.toList()
      ..sort((a, b) {
        final byTime = a.value.timestampMs.compareTo(b.value.timestampMs);
        return byTime != 0 ? byTime : a.key.compareTo(b.key);
      });
    return entries.take(limit).map((e) => BufferedSample(e.key, e.value)).toList();
  }

  @override
  Future<void> deleteByIds(Iterable<int> ids) async {
    ids.forEach(_rows.remove);
    _emit();
  }

  @override
  Future<int> deleteOlderThan(int cutoffMs) async {
    final stale = _rows.entries.where((e) => e.value.timestampMs < cutoffMs).map((e) => e.key).toList();
    stale.forEach(_rows.remove);
    if (stale.isNotEmpty) _emit();
    return stale.length;
  }

  @override
  Future<int> count() async => _rows.length;

  @override
  Stream<int> watchCount() async* {
    yield _rows.length;
    yield* _counts.stream;
  }

  void _emit() => _counts.add(_rows.length);
}

import '../domain/mos_response.dart';

/// Small durable settings (drift `key_values` on device, a map in tests).
abstract interface class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);

  /// Writes all [values] atomically.
  Future<void> writeAll(Map<String, String> values);
}

/// A MOS rating waiting for a confirmed backend write.
class PendingMos {
  const PendingMos({required this.responseId, required this.firestoreBody, required this.attempts});
  final String responseId;
  final Map<String, Object?> firestoreBody;
  final int attempts;
}

/// Durable queue of ratings. Enqueue is idempotent on responseId.
abstract interface class PendingMosStore {
  Future<void> enqueue(MosResponse response, int nowMs);
  Future<List<PendingMos>> all();
  Future<void> markAttempt(String responseId);
  Future<void> remove(String responseId);
}

class InMemoryKeyValueStore implements KeyValueStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> writeAll(Map<String, String> v) async => values.addAll(v);
}

class InMemoryPendingMosStore implements PendingMosStore {
  final _rows = <String, PendingMos>{};
  @override
  Future<void> enqueue(MosResponse r, int nowMs) async => _rows.putIfAbsent(
    r.responseId,
    () => PendingMos(responseId: r.responseId, firestoreBody: r.toFirestore(), attempts: 0),
  );
  @override
  Future<List<PendingMos>> all() async => _rows.values.toList();
  @override
  Future<void> markAttempt(String id) async {
    final p = _rows[id];
    if (p != null) _rows[id] = PendingMos(responseId: id, firestoreBody: p.firestoreBody, attempts: p.attempts + 1);
  }

  @override
  Future<void> remove(String id) async => _rows.remove(id);
}

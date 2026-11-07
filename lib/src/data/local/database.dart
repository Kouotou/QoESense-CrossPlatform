import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Buffered telemetry. A row's presence means "pending upload", as in the reference app's
/// `telemetry_samples` table. [payload] is the sample's contract-v2 JSON (see SampleCodec).
@DataClassName('BufferedSampleRow')
@TableIndex(name: 'buffered_samples_ts', columns: {#timestampMs})
class BufferedSamples extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get timestampMs => integer()();
  TextColumn get payload => text()();
}

/// MOS ratings waiting for a confirmed Firestore write. The key is the tap-time responseId,
/// so a retry can never duplicate a rating.
class PendingMosResponses extends Table {
  TextColumn get responseId => text()();
  TextColumn get payload => text()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  IntColumn get createdAtMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {responseId};
}

/// Small durable settings: survey bookkeeping, consent time, last upload time.
class KeyValues extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(tables: [BufferedSamples, PendingMosResponses, KeyValues])
class QoESenseDatabase extends _$QoESenseDatabase {
  QoESenseDatabase(super.executor);

  /// The on-device database. Shared across isolates and Flutter engines in one process:
  /// the UI engine and the headless collector/upload engines all open the same file.
  factory QoESenseDatabase.open() =>
      QoESenseDatabase(driftDatabase(name: 'qoesense', native: const DriftNativeOptions(shareAcrossIsolates: true)));

  /// Bump only together with a tested migration step: tables must never be recreated
  /// over buffered data.
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    beforeOpen: (details) async {
      await customStatement('PRAGMA journal_mode = WAL');
      await customStatement('PRAGMA busy_timeout = 5000');
    },
  );
}

import 'dart:typed_data';

import '../../domain/enums.dart';

/// Where telemetry batches go (docs/FREE_TIER_MIGRATION.md).
enum UploadTarget {
  /// Cloud Storage `telemetry/{uid}/{day}/{batchId}.json.gz` → loadTelemetryBatch → BigQuery.
  /// Needs a Firebase project with billing enabled (Blaze).
  cloudStorage,

  /// Firestore `devices/{uid}/telemetryBatches/{batchId}`, holding the same gzipped NDJSON
  /// bytes. Free (Spark): no billing and no card needed. Exported to analysis files by
  /// QoESense/functions/tools/export_firestore.js.
  firestore,
}

/// **The active upload target.** It's firestore while the project's billing is disabled
/// (owner decision, 2026-11-14). Switching back to cloudStorage, once billing works, is this
/// one line plus a rebuild. The batch bytes are identical either way.
const UploadTarget activeUploadTarget = UploadTarget.firestore;

/// The contract version of uploaded batches (report alignment, 2026-11-14).
///
/// - firestore: **v2**. The PC exporter reads v2, so the stale/timeout statuses, platform,
///   capabilitySet, provenance and timing fields reach the analysis files.
/// - cloudStorage: **v1**, because the deployed loadTelemetryBatch loads with
///   ignoreUnknownValues=false: a v2 field would fail the whole batch until the v2 BigQuery
///   schema and functions are deployed (docs/PHASE5_BACKEND.md).
ContractVersion get uploadContractVersion => switch (activeUploadTarget) {
  UploadTarget.firestore => ContractVersion.v2,
  UploadTarget.cloudStorage => ContractVersion.v1,
};

/// Firestore's hard document limit is 1 MiB. A 2,000-row batch measured ~60 KB on a real
/// phone, so this leaves more than 10× headroom, and the rules enforce the same bound.
const int maxBatchDocumentBytes = 900 * 1024;

/// One telemetry batch as a Firestore document. Pure, so it's unit-tested without Firebase.
class BatchDocument {
  const BatchDocument({required this.path, required this.fields});

  /// `devices/{uid}/telemetryBatches/{batchId}`.
  final String path;

  /// batchId, day, objectPath, sizeBytes, createdAtMs, ndjsonGz (the raw bytes; the Firebase
  /// adapter wraps them in a Firestore Blob).
  final Map<String, Object> fields;

  static final _objectPath = RegExp(r'^telemetry/([^/]+)/(\d{4}-\d{2}-\d{2})/([A-Za-z0-9-]+)\.json\.gz$');

  /// Maps the Storage object path the upload drain already builds (unchanged since the
  /// reference app) onto the Firestore document. Throws [ArgumentError] on any other shape.
  factory BatchDocument.fromObjectPath({
    required String objectPath,
    required Uint8List gzippedNdjson,
    required int nowMs,
  }) {
    final m = _objectPath.firstMatch(objectPath);
    if (m == null) throw ArgumentError.value(objectPath, 'objectPath', 'not a telemetry batch path');
    final uid = m.group(1)!, day = m.group(2)!, batchId = m.group(3)!;
    return BatchDocument(
      path: 'devices/$uid/telemetryBatches/$batchId',
      fields: {
        'batchId': batchId,
        'day': day,
        'objectPath': objectPath,
        'sizeBytes': gzippedNdjson.length,
        'createdAtMs': nowMs,
        'ndjsonGz': gzippedNdjson,
      },
    );
  }
}

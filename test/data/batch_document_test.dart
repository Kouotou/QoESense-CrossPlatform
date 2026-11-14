import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:qoesense/src/data/backend/batch_document.dart';
import 'package:qoesense/src/data/upload/batch_serializer.dart';

import '../support/fixtures.dart';

void main() {
  test('the free-tier target is active while billing is disabled', () {
    expect(activeUploadTarget, UploadTarget.firestore);
  });

  test('a drain object path maps onto devices/{uid}/telemetryBatches/{batchId} with the same bytes', () {
    final bytes = const BatchSerializer().toGzippedNdjson(allSamples, 'uid-1');
    final path = telemetryObjectPath(deviceId: 'uid-1', localNow: DateTime(2026, 11, 14), batchId: 'b-123');
    final doc = BatchDocument.fromObjectPath(objectPath: path, gzippedNdjson: bytes, nowMs: 42);
    expect(doc.path, 'devices/uid-1/telemetryBatches/b-123');
    expect(doc.fields.keys, ['batchId', 'day', 'objectPath', 'sizeBytes', 'createdAtMs', 'ndjsonGz']);
    expect(doc.fields['day'], '2026-11-14');
    expect(doc.fields['ndjsonGz'], same(bytes), reason: 'byte-identical to the Cloud Storage path');
    expect(doc.fields['sizeBytes'], bytes.length);
  });

  test('anything that is not a telemetry batch path is refused', () {
    for (final bad in ['uploads/x.png', 'telemetry/uid/latest/b.json.gz', 'telemetry/uid/2026-11-14/b.txt']) {
      expect(
        () => BatchDocument.fromObjectPath(objectPath: bad, gzippedNdjson: Uint8List(1), nowMs: 1),
        throwsArgumentError,
      );
    }
  });

  test('a full 2,000-row batch stays far below the Firestore document limit', () {
    final rows = [for (var i = 0; i < 2000; i++) sampleAt(1762500000000 + i * 60000)];
    final bytes = const BatchSerializer().toGzippedNdjson(rows, 'UD1DfRM9K9Wow7GaL8BrGfbSFiG2');
    expect(bytes.length, lessThan(maxBatchDocumentBytes ~/ 10));
  });
}

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:qoesense/src/application/upload_drain.dart';
import 'package:qoesense/src/data/backend/backend_ports.dart';
import 'package:qoesense/src/data/local/telemetry_buffer.dart';

import '../support/fixtures.dart';

class _Identity implements DeviceIdentity {
  _Identity(this.id);
  final String? id;
  @override
  Future<String?> deviceId() async => id;
}

class _Destination implements BatchDestination {
  _Destination({this.failOnCall});
  final int? failOnCall;
  final paths = <String>[];
  int calls = 0;

  @override
  Future<bool> upload({required String objectPath, required Uint8List gzippedNdjson}) async {
    calls++;
    if (calls == failOnCall) return false;
    paths.add(objectPath);
    return true;
  }
}

void main() {
  final now = DateTime(2026, 11, 7, 12);
  final nowMs = now.millisecondsSinceEpoch;
  var batchCounter = 0;

  UploadDrain drain(TelemetryBuffer buffer, {String? id = 'uid', BatchDestination? dest}) => UploadDrain(
    buffer: buffer,
    identity: _Identity(id),
    destination: dest ?? _Destination(),
    clock: () => now,
    newBatchId: () => 'b${batchCounter++}',
  );

  Future<InMemoryTelemetryBuffer> bufferWith(int n, {int startMs = 0}) async {
    final b = InMemoryTelemetryBuffer();
    for (var i = 0; i < n; i++) {
      await b.append(sampleAt((startMs == 0 ? nowMs : startMs) + i));
    }
    return b;
  }

  test('drains a backlog across several batches and deletes only what was uploaded', () async {
    final buffer = await bufferWith(4500);
    final dest = _Destination();
    final result = await drain(buffer, dest: dest).run();
    expect(result.outcome, DrainOutcome.success);
    expect(result.uploadedRows, 4500);
    expect(dest.paths, hasLength(3)); // 2000 + 2000 + 500
    expect(dest.paths.first, startsWith('telemetry/uid/2026-11-07/'));
    expect(await buffer.count(), 0);
  });

  test('a failed upload keeps that batch and asks for a retry', () async {
    final buffer = await bufferWith(4500);
    final result = await drain(buffer, dest: _Destination(failOnCall: 2)).run();
    expect(result.outcome, DrainOutcome.retry);
    expect(result.uploadedRows, 2000);
    expect(await buffer.count(), 2500);
  });

  test('no identity yet -> retry, nothing deleted', () async {
    final buffer = await bufferWith(10);
    final result = await drain(buffer, id: null).run();
    expect(result.outcome, DrainOutcome.retry);
    expect(await buffer.count(), 10);
  });

  test('unconfigured backend fails closed - nothing is ever deleted', () async {
    final buffer = await bufferWith(10);
    final result = await UploadDrain(
      buffer: buffer,
      identity: const UnconfiguredDeviceIdentity(),
      destination: const UnconfiguredBatchDestination(),
      newBatchId: () => 'x',
    ).run();
    expect(result.outcome, DrainOutcome.retry);
    expect(await buffer.count(), 10);
  });

  test('per-run cap: at most 20 x 2000 rows, the rest waits for the next run', () async {
    final buffer = await bufferWith(UploadDrain.batchLimit * UploadDrain.maxBatchesPerRun + 1);
    final result = await drain(buffer).run();
    expect(result.outcome, DrainOutcome.success);
    expect(await buffer.count(), 1);
  });

  test('drain-then-retain: an old backlog that is now uploadable is uploaded, not purged', () async {
    final old = now.subtract(const Duration(days: 50)).millisecondsSinceEpoch;
    final buffer = await bufferWith(100, startMs: old);
    final result = await drain(buffer).run();
    expect(result.uploadedRows, 100);
    expect(result.purgedRows, 0);
  });

  test('retention purges rows older than 45 days only when they could not be uploaded', () async {
    final buffer = InMemoryTelemetryBuffer();
    await buffer.append(sampleAt(now.subtract(const Duration(days: 46)).millisecondsSinceEpoch));
    await buffer.append(sampleAt(now.subtract(const Duration(days: 44)).millisecondsSinceEpoch));
    final result = await drain(buffer, id: null).run();
    expect(result.purgedRows, 1);
    expect(await buffer.count(), 1);
  });
}

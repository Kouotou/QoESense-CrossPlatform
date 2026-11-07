import 'dart:convert';
import 'dart:io' show gzip;

import 'package:flutter_test/flutter_test.dart';
import 'package:qoesense/src/data/upload/batch_serializer.dart';

import '../support/fixtures.dart';

/// Pins the telemetry wire format to (a) the golden NDJSON and (b) the BigQuery schema the
/// deployed loadTelemetryBatch enforces with ignoreUnknownValues:false.
void main() {
  final schema = loadSchema('contracts/bigquery_samples_schema.json');
  const serializer = BatchSerializer();

  test('matches the golden NDJSON byte for byte (reference Kotlin line format)', () {
    expect(
      serializer.toNdjson([androidSample, iosSample], 'uid-123'),
      readRepoFile('contracts/fixtures/batch_v1.ndjson').trimRight(),
    );
  });

  test('platform is NOT emitted by default - the column is not deployed yet', () {
    expect(BatchSerializer.defaultEmitPlatformField, isFalse);
    expect(serializer.lineFields(androidSample, 'uid'), isNot(contains('platform')));
  });

  test('when enabled, platform is appended last with the wire value', () {
    final fields = const BatchSerializer(emitPlatformField: true).lineFields(iosSample, 'uid');
    expect(fields.keys.last, 'platform');
    expect(fields['platform'], 'IOS');
  });

  for (final emitPlatform in [false, true]) {
    group('emitPlatformField=$emitPlatform', () {
      final s = BatchSerializer(emitPlatformField: emitPlatform);

      test('every emitted key exists in the BigQuery schema (no unknown values)', () {
        final known = schema.map((f) => f.name).toSet();
        for (final sample in [androidSample, iosSample]) {
          expect(known, containsAll(s.lineFields(sample, 'uid').keys));
        }
      });

      test('every REQUIRED schema field is present and non-null', () {
        for (final sample in [androidSample, iosSample]) {
          final fields = s.lineFields(sample, 'uid');
          for (final f in schema.where((f) => f.required)) {
            expect(fields[f.name], isNotNull, reason: '${f.name} is REQUIRED');
          }
        }
      });
    });
  }

  test('emitted JSON types match the BigQuery column types', () {
    final fields = const BatchSerializer(emitPlatformField: true).lineFields(androidSample, 'uid');
    for (final f in schema) {
      final value = fields[f.name];
      if (value == null) continue;
      final ok = switch (f.type) {
        'INTEGER' => value is int,
        'FLOAT' => value is num,
        'BOOLEAN' => value is bool,
        'STRING' => value is String,
        _ => false,
      };
      expect(ok, isTrue, reason: '${f.name}: ${value.runtimeType} vs ${f.type}');
    }
  });

  test('NDJSON has no trailing newline and gzip round-trips', () {
    final bytes = serializer.toGzippedNdjson([androidSample, iosSample], 'uid-123');
    final text = utf8.decode(gzip.decode(bytes));
    expect(text.endsWith('\n'), isFalse);
    expect(text.split('\n'), hasLength(2));
    expect(text, serializer.toNdjson([androidSample, iosSample], 'uid-123'));
  });

  test('storage path is telemetry/{uid}/{local yyyy-MM-dd}/{batchId}.json.gz', () {
    expect(
      telemetryObjectPath(deviceId: 'uid', localNow: DateTime(2026, 3, 7, 23, 59), batchId: 'b1'),
      'telemetry/uid/2026-03-07/b1.json.gz',
    );
  });
}

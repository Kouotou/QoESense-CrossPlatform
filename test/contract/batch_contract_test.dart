import 'dart:convert';
import 'dart:io' show gzip;

import 'package:flutter_test/flutter_test.dart';
import 'package:qoesense/src/data/upload/batch_serializer.dart';
import 'package:qoesense/src/domain/enums.dart';

import '../support/fixtures.dart';

/// Pins the telemetry wire format:
/// - v1 to the reference app's exact line format and the current BigQuery schema;
/// - v2 to the golden records and the PROPOSED v2 schema (contracts/proposed/).
void main() {
  final v1Schema = loadSchema('contracts/bigquery_samples_schema.json');
  final v2Schema = loadSchema('contracts/proposed/bigquery_samples_schema_v2.json');
  const v1 = BatchSerializer(version: ContractVersion.v1);
  const v2 = BatchSerializer(version: ContractVersion.v2);

  group('v1 (deployed format)', () {
    test('matches the golden NDJSON byte for byte (reference Kotlin line format)', () {
      expect(
        v1.toNdjson([androidSample, iosSample], 'uid-123'),
        readRepoFile('contracts/fixtures/batch_v1.ndjson').trimRight(),
      );
    });

    test('is the default, and stays the default until the v2 functions are deployed', () {
      expect(BatchSerializer.defaultVersion, ContractVersion.v1);
      expect(const BatchSerializer().version, ContractVersion.v1);
    });

    test('emits exactly the 27 reference fields + deviceId - nothing the deployed loader rejects', () {
      for (final s in allSamples) {
        final keys = v1.lineFields(s, 'uid').keys.toList();
        expect(keys, hasLength(28));
        expect(keys.last, 'deviceId');
        expect(keys, isNot(contains('platform')));
        expect(keys, isNot(contains('schemaVersion')));
      }
    });

    test('every v1 line fits the v1 schema (keys known, REQUIRED non-null, types match)', () {
      _expectFits(v1Schema, [for (final s in allSamples) v1.lineFields(s, 'uid')]);
    });
  });

  group('v2 (proposed)', () {
    test('matches the golden v2 records', () {
      expect(v2.toNdjson(allSamples, 'uid-123'), readRepoFile('contracts/fixtures/samples_v2.ndjson').trimRight());
    });

    test('a v2 line is the v1 line plus an appended v2 block - v1 keys keep their order', () {
      for (final s in allSamples) {
        final v1Keys = v1.lineFields(s, 'uid').keys.toList();
        final v2Keys = v2.lineFields(s, 'uid').keys.toList();
        expect(v2Keys.sublist(0, v1Keys.length), v1Keys);
        expect(v2.lineFields(s, 'uid')['schemaVersion'], 2);
      }
    });

    test('every v2 line fits the proposed v2 schema (keys known, REQUIRED non-null, types match)', () {
      _expectFits(v2Schema, [for (final s in allSamples) v2.lineFields(s, 'uid')]);
    });

    test('every v2 schema column is written by v2 lines (no orphan columns)', () {
      final written = v2.lineFields(androidFull, 'uid').keys.toSet();
      expect(written, containsAll(v2Schema.map((f) => f.name)));
    });

    test('iOS records carry no radio values - null with NOT_SUPPORTED, never estimated', () {
      for (final s in [iosInCall, iosOnWifi]) {
        final line = v2.lineFields(s, 'uid');
        for (final k in [
          'rsrp',
          'rsrq',
          'rssnr',
          'timingAdvance',
          'cellIdentityHash',
          'trackingAreaCode',
          'signalStrengthLevel',
          'cqi',
          'cellBandwidthKhz',
          'downlinkChannelNumber',
          'uplinkChannelNumber',
          'foregroundAppPackage',
          'isRoaming',
        ]) {
          expect(line[k], isNull, reason: k);
        }
        expect(line['cqiSupported'], isFalse);
        expect(line['radioStatus'], 'NOT_SUPPORTED');
        expect(line['telemetryCapabilityTier'], 'IOS_RAT');
        expect(line['platform'], 'IOS');
        expect(line['capabilitySet'], isNot(contains('RADIO')));
      }
    });

    test('v1 nulls that meant different things are distinguishable in v2', () {
      // Both rows have rttMs = null in v1. v2 says why.
      expect(v2.lineFields(androidDegraded, 'u')['rttStatus'], 'NOT_ATTEMPTED');
      expect(v2.lineFields(iosOnWifi, 'u')['rttStatus'], 'FAILED');
      // Both have location = null in v1: permission denied, not a failed fix.
      expect(v2.lineFields(androidDegraded, 'u')['locationStatus'], 'PERMISSION_DENIED');
      // Unsupported on the platform vs. not granted on this device.
      expect(v2.lineFields(iosOnWifi, 'u')['foregroundAppStatus'], 'NOT_SUPPORTED');
      expect(v2.lineFields(androidDegraded, 'u')['foregroundAppStatus'], 'PERMISSION_DENIED');
      // A stale reading keeps its value and says how old it is.
      final stale = v2.lineFields(androidDegraded, 'u');
      expect(stale['radioStatus'], 'STALE');
      expect(stale['rsrp'], -112);
      expect(stale['cellInfoAgeMs'], 95000);
    });
  });

  group('schema evolution (DATA_CONTRACT §7)', () {
    test('v2 keeps every v1 column unchanged', () {
      final v2ByName = {for (final f in v2Schema) f.name: f};
      for (final f in v1Schema) {
        expect(v2ByName[f.name], isNotNull, reason: '${f.name} removed');
        expect(v2ByName[f.name]!.type, f.type, reason: '${f.name} retyped');
        expect(v2ByName[f.name]!.mode, f.mode, reason: '${f.name} mode changed');
      }
    });

    test('every column added in v2 is NULLABLE or REPEATED (old rows stay valid)', () {
      final v1Names = v1Schema.map((f) => f.name).toSet();
      for (final f in v2Schema.where((f) => !v1Names.contains(f.name))) {
        expect(f.required, isFalse, reason: '${f.name} must not be REQUIRED');
      }
    });

    test('a v1 line still loads under the v2 schema (old clients keep working after the deploy)', () {
      _expectFits(v2Schema, [for (final s in allSamples) v1.lineFields(s, 'uid')]);
    });
  });

  test('NDJSON has no trailing newline and gzip round-trips', () {
    final bytes = v2.toGzippedNdjson(allSamples, 'uid-123');
    final text = utf8.decode(gzip.decode(bytes));
    expect(text.endsWith('\n'), isFalse);
    expect(text.split('\n'), hasLength(allSamples.length));
    expect(text, v2.toNdjson(allSamples, 'uid-123'));
  });

  test('storage path is telemetry/{uid}/{local yyyy-MM-dd}/{batchId}.json.gz for every version', () {
    expect(
      telemetryObjectPath(deviceId: 'uid', localNow: DateTime(2026, 3, 7, 23, 59), batchId: 'b1'),
      'telemetry/uid/2026-03-07/b1.json.gz',
    );
  });
}

void _expectFits(List<SchemaField> schema, List<Map<String, Object?>> lines) {
  final byName = {for (final f in schema) f.name: f};
  for (final raw in lines) {
    // Round-trip through JSON so the check sees exactly what BigQuery parses.
    final line = jsonDecode(jsonEncode(raw)) as Map<String, Object?>;
    for (final key in line.keys) {
      expect(byName, contains(key), reason: 'unknown key "$key" would fail the whole load job');
    }
    for (final f in schema) {
      expect(fitsColumn(f, line[f.name]), isTrue, reason: '${f.name}=${line[f.name]} vs ${f.type} ${f.mode}');
    }
  }
}

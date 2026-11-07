// Regenerates the v2 golden files from the fixtures. Golden files are the contract: after
// regenerating, REVIEW THE DIFF LINE BY LINE before committing.
//   C:\Users\Ahmad\flutter\bin\flutter test test/support/print_goldens.dart --dart-define=WRITE_GOLDENS=true
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qoesense/src/data/upload/batch_serializer.dart';
import 'package:qoesense/src/domain/enums.dart';

import 'fixtures.dart';

void main() {
  test('write golden files', () {
    const write = bool.fromEnvironment('WRITE_GOLDENS');
    if (!write) return; // no-op in normal test runs
    File('contracts/fixtures/samples_v2.ndjson')
        .writeAsStringSync('${const BatchSerializer(version: ContractVersion.v2).toNdjson(allSamples, 'uid-123')}\n');
    File('contracts/fixtures/mos_v2.ndjson').writeAsStringSync(
      '${[
        for (final m in allMos) jsonEncode({'responseId': m.responseId, ...m.toFirestore()}),
      ].join('\n')}\n',
    );
  });
}

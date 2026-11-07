import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Enforces docs/ARCHITECTURE.md section 2: domain/ is pure Dart; domain/ and application/
/// never import Flutter, plugins, generated channel code or presentation.
void main() {
  final importPattern = RegExp(r'''^import\s+['"]([^'"]+)['"]''', multiLine: true);

  Map<String, List<String>> importsUnder(String dir) => {
    for (final f in Directory(dir).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')))
      f.path: importPattern.allMatches(f.readAsStringSync()).map((m) => m.group(1)!).toList(),
  };

  test('domain/ imports only dart: libraries and other domain files', () {
    importsUnder('lib/src/domain').forEach((file, imports) {
      for (final i in imports) {
        expect(i.startsWith('dart:') || !i.contains(':') && !i.contains('..'), isTrue, reason: '$file imports $i');
      }
    });
  });

  test('application/ never imports Flutter, packages, platform or presentation', () {
    importsUnder('lib/src/application').forEach((file, imports) {
      for (final i in imports) {
        expect(i.startsWith('package:'), isFalse, reason: '$file imports $i');
        expect(i.contains('platform/') || i.contains('presentation/'), isFalse, reason: '$file imports $i');
      }
    });
  });

  test('no secrets or reference-app credentials in the workspace', () {
    for (final forbidden in ['keystore.properties', 'google-services.json', 'GoogleService-Info.plist']) {
      final hits = Directory('.')
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((f) => !f.path.contains('${Platform.pathSeparator}build${Platform.pathSeparator}'))
          .where((f) => !f.path.contains('.dart_tool'))
          .where((f) => f.uri.pathSegments.last == forbidden);
      expect(hits, isEmpty, reason: '$forbidden must not be in this workspace yet (see docs/ARCHITECTURE.md §7)');
    }
    final keystores = Directory('.')
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where((f) => f.path.endsWith('.jks') || f.path.endsWith('.keystore'));
    expect(keystores, isEmpty);
  });
}

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
    // Walk only source folders: build outputs and tool caches are regenerated, never
    // committed, and contain paths longer than Windows' 260-character limit.
    const skip = {'build', '.dart_tool', '.gradle', '.git', '.idea', 'Pods', '.symlinks'};
    Iterable<File> sourceFiles(Directory dir) sync* {
      for (final e in dir.listSync(followLinks: false)) {
        final name = e.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
        if (e is Directory) {
          if (!skip.contains(name)) yield* sourceFiles(e);
        } else if (e is File) {
          yield e;
        }
      }
    }

    final files = sourceFiles(Directory('.')).toList();
    final names = files.map((f) => f.uri.pathSegments.last).toList();
    for (final forbidden in ['keystore.properties', 'google-services.json', 'GoogleService-Info.plist']) {
      expect(names, isNot(contains(forbidden)), reason: '$forbidden must not be in this workspace (ARCHITECTURE §7)');
    }
    expect(names.where((n) => n.endsWith('.jks') || n.endsWith('.keystore')), isEmpty);
  });
}

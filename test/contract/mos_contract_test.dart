import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:qoesense/src/domain/enums.dart';
import 'package:qoesense/src/domain/ids.dart';
import 'package:qoesense/src/domain/mos_response.dart';

import '../support/fixtures.dart';

void main() {
  final v1Schema = loadSchema('contracts/bigquery_mos_responses_schema.json');
  final v2Schema = loadSchema('contracts/proposed/bigquery_mos_responses_schema_v2.json');
  const fromPath = {'deviceId', 'responseId'};

  MosResponse rating({
    int score = 4,
    ContextSource source = ContextSource.observed,
    String? app = 'com.whatsapp',
    AppSessionType session = AppSessionType.socialMedia,
    int? promptedAtMs,
  }) => MosResponse.forTap(
    responseId: 'r-1',
    score: score,
    tapMs: 1762500000000,
    triggerType: MosTriggerType.anomaly,
    contextAppPackage: app,
    contextSessionType: session,
    platform: ClientPlatform.ios,
    contextSource: source,
    presentationMode: PresentationMode.notificationAction,
    appId: 'io.github.kouotou.qoesense',
    appVersion: '2.0.0',
    appBuild: 1,
    utcOffsetMinutes: 60,
    promptedAtMs: promptedAtMs,
  );

  test('MOS scale is exactly 1-5 (unchanged)', () {
    expect(() => rating(score: 0), throwsArgumentError);
    expect(() => rating(score: 6), throwsArgumentError);
    for (var s = 1; s <= 5; s++) {
      expect(rating(score: s).score, s);
    }
  });

  test('context window is the 10 minutes before the tap (unchanged)', () {
    final r = rating();
    expect(r.windowEndMs, r.submittedAtMs);
    expect(r.windowEndMs - r.windowStartMs, 10 * 60 * 1000);
  });

  test('the 7 reference fields keep their names and order', () {
    expect(mosAndroidOverlay.toV1Fields().keys, [
      'score',
      'submittedAtMs',
      'triggerType',
      'contextAppPackage',
      'contextSessionType',
      'windowStartMs',
      'windowEndMs',
    ]);
  });

  test('Firestore body matches the golden records', () {
    final lines = [
      for (final m in allMos) jsonEncode({'responseId': m.responseId, ...m.toFirestore()}),
    ];
    expect(lines.join('\n'), readRepoFile('contracts/fixtures/mos_v2.ndjson').trimRight());
  });

  test('the deployed exporter can read every body: v1 REQUIRED fields present, extras ignored', () {
    for (final m in allMos) {
      final body = m.toFirestore();
      for (final f in v1Schema.where((f) => f.required && !fromPath.contains(f.name))) {
        expect(body[f.name], isNotNull, reason: '${f.name} is REQUIRED');
      }
    }
  });

  test('every body field maps onto the proposed v2 table with the right type', () {
    final byName = {for (final f in v2Schema) f.name: f};
    for (final m in allMos) {
      final body = jsonDecode(jsonEncode(m.toFirestore())) as Map<String, Object?>;
      for (final e in body.entries) {
        expect(byName, contains(e.key), reason: e.key);
        expect(fitsColumn(byName[e.key]!, e.value), isTrue, reason: '${e.key}=${e.value}');
      }
      expect(body, isNot(contains('responseId')), reason: 'responseId is the document id');
    }
  });

  test('v2 MOS columns are additive: v1 columns unchanged, new ones nullable', () {
    final v2ByName = {for (final f in v2Schema) f.name: f};
    final v1Names = v1Schema.map((f) => f.name).toSet();
    for (final f in v1Schema) {
      expect((v2ByName[f.name]!.type, v2ByName[f.name]!.mode), (f.type, f.mode));
    }
    expect(v2Schema.where((f) => !v1Names.contains(f.name)).any((f) => f.required), isFalse);
  });

  test('UNKNOWN context cannot carry an app or a session type', () {
    expect(() => rating(source: ContextSource.unknown), throwsArgumentError);
    expect(rating(source: ContextSource.unknown, app: null, session: AppSessionType.none).contextAppPackage, isNull);
  });

  test('self-reported context uses Android package names (D-6)', () {
    expect(mosIosSelfReported.contextSource, ContextSource.selfReported);
    expect(mosIosSelfReported.contextAppPackage, 'com.whatsapp');
  });

  test('promptedAtMs cannot be after the tap', () {
    expect(() => rating(promptedAtMs: 1762500000001), throwsArgumentError);
  });

  test('trigger and session wire values match the reference app', () {
    expect(MosTriggerType.values.map((t) => t.wireName), ['PERIODIC', 'POST_SESSION', 'ANOMALY']);
    expect(AppSessionType.values.map((t) => t.wireName), ['NONE', 'SOCIAL_MEDIA', 'VIDEO_CONFERENCING']);
  });

  test('responseId is a v4 UUID, unique per tap', () {
    final pattern = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
    final ids = List.generate(1000, (_) => newUuidV4());
    expect(ids.every(pattern.hasMatch), isTrue);
    expect(ids.toSet(), hasLength(1000));
  });
}

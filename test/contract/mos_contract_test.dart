import 'package:flutter_test/flutter_test.dart';
import 'package:qoesense/src/domain/enums.dart';
import 'package:qoesense/src/domain/ids.dart';
import 'package:qoesense/src/domain/mos_response.dart';

import '../support/fixtures.dart';

void main() {
  final schema = loadSchema('contracts/bigquery_mos_responses_schema.json');

  MosResponse rating({int score = 4}) => MosResponse.forTap(
    responseId: 'r-1',
    score: score,
    tapMs: 1762500000000,
    triggerType: MosTriggerType.anomaly,
    contextAppPackage: null,
    contextSessionType: AppSessionType.none,
    platform: ClientPlatform.ios,
  );

  test('MOS scale is exactly 1-5', () {
    expect(() => rating(score: 0), throwsArgumentError);
    expect(() => rating(score: 6), throwsArgumentError);
    for (var s = 1; s <= 5; s++) {
      expect(rating(score: s).score, s);
    }
  });

  test('context window is the 10 minutes before the tap', () {
    final r = rating();
    expect(r.windowEndMs, r.submittedAtMs);
    expect(r.windowEndMs - r.windowStartMs, 10 * 60 * 1000);
  });

  test('Firestore body covers every schema field except the path-derived ids', () {
    final body = rating().toFirestore();
    final fromPath = {'deviceId', 'responseId'};
    final known = schema.map((f) => f.name).toSet();
    expect(known, containsAll(body.keys));
    for (final f in schema.where((f) => f.required && !fromPath.contains(f.name))) {
      expect(body[f.name], isNotNull, reason: '${f.name} is REQUIRED');
    }
    expect(body, isNot(contains('responseId')), reason: 'responseId is the document id');
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

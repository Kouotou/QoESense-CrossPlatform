import 'package:flutter_test/flutter_test.dart';
import 'package:qoesense/src/application/survey_trigger_policy.dart';

/// Mirrors the reference SurveyTriggerPolicyTest semantics.
void main() {
  const hour = 60 * 60 * 1000;
  const minute = 60 * 1000;
  const today = 20000;

  SurveyState state({int? last = 0, int shown = 0, int day = today, int current = today}) =>
      SurveyState(lastPromptMs: last, promptsShownToday: shown, promptsDayEpoch: day, currentDayEpoch: current);

  group('no baseline yet -> nothing fires', () {
    test('all triggers', () {
      final s = state(last: null);
      expect(SurveyTriggerPolicy.shouldTriggerPeriodic(s, 100 * hour), isFalse);
      expect(SurveyTriggerPolicy.shouldTriggerPostSession(s, 100 * hour), isFalse);
      expect(SurveyTriggerPolicy.shouldTriggerAnomaly(s, 100 * hour), isFalse);
    });
  });

  test('periodic fires at exactly 2 h, not before', () {
    expect(SurveyTriggerPolicy.shouldTriggerPeriodic(state(), 2 * hour - 1), isFalse);
    expect(SurveyTriggerPolicy.shouldTriggerPeriodic(state(), 2 * hour), isTrue);
  });

  test('post-session cooldown is 15 min', () {
    expect(SurveyTriggerPolicy.shouldTriggerPostSession(state(), 15 * minute - 1), isFalse);
    expect(SurveyTriggerPolicy.shouldTriggerPostSession(state(), 15 * minute), isTrue);
  });

  test('anomaly cooldown is 10 min - the shortest', () {
    expect(SurveyTriggerPolicy.shouldTriggerAnomaly(state(), 10 * minute - 1), isFalse);
    expect(SurveyTriggerPolicy.shouldTriggerAnomaly(state(), 10 * minute), isTrue);
    expect(SurveyTriggerPolicy.anomalyCooldownMs, lessThan(SurveyTriggerPolicy.postSessionCooldownMs));
  });

  test('daily cap of 6 blocks every trigger type', () {
    final capped = state(shown: 6);
    expect(SurveyTriggerPolicy.shouldTriggerPeriodic(capped, 10 * hour), isFalse);
    expect(SurveyTriggerPolicy.shouldTriggerPostSession(capped, 10 * hour), isFalse);
    expect(SurveyTriggerPolicy.shouldTriggerAnomaly(capped, 10 * hour), isFalse);
    expect(SurveyTriggerPolicy.shouldTriggerAnomaly(state(shown: 5), 10 * hour), isTrue);
  });

  test('the cap resets on a new day', () {
    expect(SurveyTriggerPolicy.shouldTriggerAnomaly(state(shown: 6, day: today - 1), 10 * hour), isTrue);
  });

  group('local day', () {
    // 2026-11-06T23:30:00Z
    final ms = DateTime.utc(2026, 11, 6, 23, 30).millisecondsSinceEpoch;
    final utcDay = DateTime.utc(2026, 11, 6).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

    test('Cameroon (UTC+1) is already on the next local day', () {
      expect(SurveyTriggerPolicy.localDayEpoch(ms, utcOffset: const Duration(hours: 1)), utcDay + 1);
    });

    test('New York (UTC-5) is still on the same day', () {
      expect(SurveyTriggerPolicy.localDayEpoch(ms, utcOffset: const Duration(hours: -5)), utcDay);
    });

    test('UTC offset zero equals the epoch day', () {
      expect(SurveyTriggerPolicy.localDayEpoch(ms, utcOffset: Duration.zero), utcDay);
    });
  });
}

/// When a MOS prompt may fire - a port of the reference app's `SurveyTriggerPolicy`
/// (../QoESense service/survey/SurveyTriggerPolicy.kt).
///
/// All trigger types share one lastPromptMs / daily-cap state, so periodic, post-session and
/// anomaly prompts can't stack: whichever fires first resets the cooldown for all of them.
/// `lastPromptMs == null` means the first-run baseline hasn't been written yet - nothing fires
/// until it is (the baseline is "now" at first run, so no prompt right after install).
abstract final class SurveyTriggerPolicy {
  static const int periodicIntervalMs = 2 * 60 * 60 * 1000;
  static const int postSessionCooldownMs = 15 * 60 * 1000;
  static const int anomalyCooldownMs = 10 * 60 * 1000;
  static const int maxPromptsPerDay = 6;

  static bool shouldTriggerPeriodic(SurveyState state, int nowMs) => _allowed(state, nowMs, periodicIntervalMs);

  static bool shouldTriggerPostSession(SurveyState state, int nowMs) => _allowed(state, nowMs, postSessionCooldownMs);

  static bool shouldTriggerAnomaly(SurveyState state, int nowMs) => _allowed(state, nowMs, anomalyCooldownMs);

  /// The participant's *local* calendar day as an epoch-day number, so the daily cap resets
  /// at local midnight. Same number space as the reference (days since 1970-01-01), so the
  /// value is comparable across platforms.
  ///
  /// [utcOffset] overrides the device's current offset - for tests, since Dart has no
  /// built-in time-zone database.
  static int localDayEpoch(int nowMs, {Duration? utcOffset}) {
    final DateTime local;
    if (utcOffset == null) {
      local = DateTime.fromMillisecondsSinceEpoch(nowMs);
    } else {
      local = DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true).add(utcOffset);
    }
    return DateTime.utc(local.year, local.month, local.day).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  }

  static bool _allowed(SurveyState state, int nowMs, int cooldownMs) {
    final last = state.lastPromptMs;
    if (last == null) return false;
    if (_isOverDailyCap(state)) return false;
    return nowMs - last >= cooldownMs;
  }

  static bool _isOverDailyCap(SurveyState state) {
    final effective = state.promptsDayEpoch == state.currentDayEpoch ? state.promptsShownToday : 0;
    return effective >= maxPromptsPerDay;
  }
}

/// The persisted survey bookkeeping plus "today", bundled for the policy.
class SurveyState {
  const SurveyState({
    required this.lastPromptMs,
    required this.promptsShownToday,
    required this.promptsDayEpoch,
    required this.currentDayEpoch,
  });

  final int? lastPromptMs;
  final int promptsShownToday;
  final int promptsDayEpoch;
  final int currentDayEpoch;
}

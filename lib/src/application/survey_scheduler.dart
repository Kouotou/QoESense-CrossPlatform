import '../domain/enums.dart';
import 'rsrp_anomaly_detector.dart';
import 'stores.dart';
import 'survey_trigger_policy.dart';

/// Shows a survey prompt: the Android overlay activity or notification fallback; on iOS,
/// the actionable notification.
abstract interface class SurveyPresenter {
  Future<void> present(MosTriggerType trigger);
}

/// Whether someone is using the phone right now (Android: screen on and unlocked).
abstract interface class UserActivity {
  Future<bool> isUserActive();
}

/// iOS: prompts are notifications that wait in the notification centre, so no gate is needed.
class AlwaysActive implements UserActivity {
  const AlwaysActive();
  @override
  Future<bool> isUserActive() async => true;
}

/// Port of the reference MosSurveyScheduler + MosSurveyPreferences: one shared
/// lastPrompt/daily-cap state for all trigger types, persisted durably.
///
/// **Only asks while the phone is in use** (owner decision, 2026-11-21). The reference asked at
/// whatever tick a trigger fell due, mostly with the screen off, where the 8 s pop-up vanished
/// unseen yet still used up the cooldown and the 6-a-day cap: the test phone got 7 ratings in
/// two weeks. Now a prompt is shown only after the screen has been on and unlocked for
/// [minActiveMs] (the question is about "the last few minutes", which the person must have
/// been using the phone for). A prompt that can't be shown is not counted:
/// - PERIODIC simply stays due until the next moment of use;
/// - POST_SESSION and ANOMALY are events: they stay due for [eventValidMs], the 10-minute
///   window the rating covers, so the rated window still contains the event.
class SurveyScheduler {
  SurveyScheduler({
    required this.store,
    required this.presenter,
    this.activity = const AlwaysActive(),
    this.clock = DateTime.now,
  });

  final KeyValueStore store;
  final SurveyPresenter presenter;
  final UserActivity activity;
  final DateTime Function() clock;

  static const int minActiveMs = 2 * 60 * 1000;
  static const int eventValidMs = 10 * 60 * 1000;

  /// When the current stretch of use began; null while the phone isn't in use.
  int? _activeSinceMs;

  /// An event trigger that fell due while the phone wasn't in use.
  ({MosTriggerType trigger, int atMs})? _pendingEvent;

  ({MosTriggerType trigger, int atMs})? get pendingEvent => _pendingEvent;

  /// Called once per tick, before the triggers: tracks how long the phone has been in use.
  Future<void> observeUserActivity() async {
    final now = clock().millisecondsSinceEpoch;
    final active = await activity.isUserActive();
    _activeSinceMs = active ? (_activeSinceMs ?? now) : null;
  }

  bool _userReady(int nowMs) {
    if (activity is AlwaysActive) return true;
    final since = _activeSinceMs;
    return since != null && nowMs - since >= minActiveMs;
  }

  /// Fires a POST_SESSION or ANOMALY prompt that couldn't be shown earlier, if still valid.
  Future<bool> maybeTriggerPending() async {
    final p = _pendingEvent;
    if (p == null) return false;
    if (clock().millisecondsSinceEpoch - p.atMs > eventValidMs) {
      _pendingEvent = null;
      return false;
    }
    final fired = await _maybe(p.trigger, _policyFor(p.trigger), event: false);
    if (fired) _pendingEvent = null;
    return fired;
  }

  static bool Function(SurveyState, int) _policyFor(MosTriggerType t) => switch (t) {
    MosTriggerType.anomaly => SurveyTriggerPolicy.shouldTriggerAnomaly,
    MosTriggerType.postSession => SurveyTriggerPolicy.shouldTriggerPostSession,
    _ => SurveyTriggerPolicy.shouldTriggerPeriodic,
  };

  static const _kLastPrompt = 'survey.lastPromptMs';
  static const _kShownToday = 'survey.promptsShownToday';
  static const _kDayEpoch = 'survey.promptsDayEpoch';

  /// First run: the baseline is "now", so no prompt fires right after install (as in the reference).
  Future<void> ensureBaseline() async {
    if (await store.read(_kLastPrompt) == null) {
      await store.write(_kLastPrompt, '${clock().millisecondsSinceEpoch}');
    }
  }

  Future<SurveyState> state() async {
    final now = clock().millisecondsSinceEpoch;
    return SurveyState(
      lastPromptMs: int.tryParse(await store.read(_kLastPrompt) ?? ''),
      promptsShownToday: int.tryParse(await store.read(_kShownToday) ?? '') ?? 0,
      promptsDayEpoch: int.tryParse(await store.read(_kDayEpoch) ?? '') ?? 0,
      currentDayEpoch: SurveyTriggerPolicy.localDayEpoch(now),
    );
  }

  Future<bool> maybeTriggerPeriodic() => _maybe(MosTriggerType.periodic, SurveyTriggerPolicy.shouldTriggerPeriodic);

  Future<bool> maybeTriggerPostSession() =>
      _maybe(MosTriggerType.postSession, SurveyTriggerPolicy.shouldTriggerPostSession, event: true);

  /// [reason] is not stored or uploaded (DATA_CONTRACT §6); only triggerType ANOMALY is.
  Future<bool> maybeTriggerAnomaly(AnomalyReason reason) =>
      _maybe(MosTriggerType.anomaly, SurveyTriggerPolicy.shouldTriggerAnomaly, event: true);

  /// [event]: a POST_SESSION/ANOMALY occurrence, kept as pending if the phone isn't in use.
  Future<bool> _maybe(MosTriggerType trigger, bool Function(SurveyState, int) policy, {bool event = false}) async {
    final s = await state();
    final now = clock().millisecondsSinceEpoch;
    if (!policy(s, now)) return false;
    if (!_userReady(now)) {
      // Not counted. An ANOMALY outranks a POST_SESSION waiting at the same time.
      final p = _pendingEvent;
      if (event && (p == null || trigger == MosTriggerType.anomaly || p.trigger != MosTriggerType.anomaly)) {
        _pendingEvent = (trigger: trigger, atMs: now);
      }
      return false;
    }
    final previous = s.promptsDayEpoch == s.currentDayEpoch ? s.promptsShownToday : 0;
    // Recorded before presenting, as in the reference: a failed presentation still counts,
    // so a broken presenter can't cause a prompt storm.
    await store.writeAll({_kLastPrompt: '$now', _kShownToday: '${previous + 1}', _kDayEpoch: '${s.currentDayEpoch}'});
    await presenter.present(trigger);
    return true;
  }
}

import '../domain/enums.dart';
import 'rsrp_anomaly_detector.dart';
import 'stores.dart';
import 'survey_trigger_policy.dart';

/// Shows a survey prompt: the Android overlay activity or notification fallback; on iOS,
/// the actionable notification.
abstract interface class SurveyPresenter {
  Future<void> present(MosTriggerType trigger);
}

/// Port of the reference MosSurveyScheduler + MosSurveyPreferences: one shared
/// lastPrompt/daily-cap state for all trigger types, persisted durably.
class SurveyScheduler {
  SurveyScheduler({required this.store, required this.presenter, this.clock = DateTime.now});

  final KeyValueStore store;
  final SurveyPresenter presenter;
  final DateTime Function() clock;

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
      _maybe(MosTriggerType.postSession, SurveyTriggerPolicy.shouldTriggerPostSession);

  /// [reason] is not stored or uploaded (DATA_CONTRACT §6); only triggerType ANOMALY is.
  Future<bool> maybeTriggerAnomaly(AnomalyReason reason) =>
      _maybe(MosTriggerType.anomaly, SurveyTriggerPolicy.shouldTriggerAnomaly);

  Future<bool> _maybe(MosTriggerType trigger, bool Function(SurveyState, int) policy) async {
    final s = await state();
    final now = clock().millisecondsSinceEpoch;
    if (!policy(s, now)) return false;
    final previous = s.promptsDayEpoch == s.currentDayEpoch ? s.promptsShownToday : 0;
    // Recorded before presenting, as in the reference: a failed presentation still counts,
    // so a broken presenter can't cause a prompt storm.
    await store.writeAll({_kLastPrompt: '$now', _kShownToday: '${previous + 1}', _kDayEpoch: '${s.currentDayEpoch}'});
    await presenter.present(trigger);
    return true;
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:qoesense/src/application/rsrp_anomaly_detector.dart';
import 'package:qoesense/src/application/stores.dart';
import 'package:qoesense/src/application/survey_scheduler.dart';
import 'package:qoesense/src/domain/enums.dart';

import '../support/fakes.dart';

class _Activity implements UserActivity {
  bool active = false;
  @override
  Future<bool> isUserActive() async => active;
}

/// Owner decision 2026-11-21: ask only while the phone has been in use for 2 minutes; a prompt
/// that can't be shown is not counted (test phone: 7 ratings in 2 weeks before this).
void main() {
  late InMemoryKeyValueStore kv;
  late RecordingPresenter presenter;
  late _Activity activity;
  late SurveyScheduler surveys;
  var now = DateTime.utc(2026, 11, 21, 8);

  Future<void> tickAt(Duration after) async {
    now = now.add(after);
    await surveys.observeUserActivity();
  }

  setUp(() async {
    kv = InMemoryKeyValueStore();
    presenter = RecordingPresenter();
    activity = _Activity();
    now = DateTime.utc(2026, 11, 21, 8);
    surveys = SurveyScheduler(store: kv, presenter: presenter, activity: activity, clock: () => now);
    await surveys.ensureBaseline();
  });

  test('a due periodic prompt waits while the screen is off and is not counted', () async {
    await tickAt(const Duration(hours: 3));
    expect(await surveys.maybeTriggerPeriodic(), isFalse);
    expect(presenter.shown, isEmpty);
    expect(kv.values['survey.promptsShownToday'], isNull, reason: 'nothing counted toward the cap');
  });

  test('it fires only after 2 minutes of use, not at the moment of unlocking', () async {
    await tickAt(const Duration(hours: 3));
    activity.active = true;
    await tickAt(Duration.zero);
    expect(await surveys.maybeTriggerPeriodic(), isFalse);
    await tickAt(const Duration(minutes: 1));
    expect(await surveys.maybeTriggerPeriodic(), isFalse);
    await tickAt(const Duration(minutes: 1));
    expect(await surveys.maybeTriggerPeriodic(), isTrue);
    expect(presenter.shown, [MosTriggerType.periodic]);
  });

  test('locking the phone restarts the 2-minute count', () async {
    await tickAt(const Duration(hours: 3));
    activity.active = true;
    await tickAt(Duration.zero);
    await tickAt(const Duration(minutes: 1, seconds: 30));
    activity.active = false;
    await tickAt(const Duration(seconds: 10));
    activity.active = true;
    await tickAt(const Duration(seconds: 10));
    expect(await surveys.maybeTriggerPeriodic(), isFalse);
    await tickAt(const Duration(minutes: 2));
    expect(await surveys.maybeTriggerPeriodic(), isTrue);
  });

  test('an anomaly seen with the screen off is asked about once the phone is in use, within 10 minutes', () async {
    await tickAt(const Duration(minutes: 30));
    expect(await surveys.maybeTriggerAnomaly(AnomalyReason.signalDrop), isFalse);
    expect(surveys.pendingEvent?.trigger, MosTriggerType.anomaly);
    activity.active = true;
    await tickAt(const Duration(minutes: 1));
    expect(await surveys.maybeTriggerPending(), isFalse, reason: 'not 2 minutes of use yet');
    await tickAt(const Duration(minutes: 2));
    expect(await surveys.maybeTriggerPending(), isTrue);
    expect(presenter.shown, [MosTriggerType.anomaly]);
    expect(surveys.pendingEvent, isNull);
  });

  test('a missed event expires after the 10-minute rating window', () async {
    await tickAt(const Duration(minutes: 30));
    await surveys.maybeTriggerPostSession();
    expect(surveys.pendingEvent?.trigger, MosTriggerType.postSession);
    activity.active = true;
    await tickAt(const Duration(minutes: 9));
    await tickAt(const Duration(minutes: 2)); // in use for 2 min, but the event is 11 min old
    expect(await surveys.maybeTriggerPending(), isFalse);
    expect(surveys.pendingEvent, isNull);
    expect(presenter.shown, isEmpty);
  });

  test('a waiting anomaly is not replaced by a later session end', () async {
    await tickAt(const Duration(minutes: 30));
    await surveys.maybeTriggerAnomaly(AnomalyReason.signalSpike);
    await tickAt(const Duration(minutes: 1));
    await surveys.maybeTriggerPostSession();
    expect(surveys.pendingEvent?.trigger, MosTriggerType.anomaly);
  });

  test('the daily cap of 6 counts only prompts actually shown', () async {
    activity.active = true;
    await tickAt(Duration.zero);
    for (var i = 0; i < 8; i++) {
      await tickAt(const Duration(minutes: 11));
      await surveys.maybeTriggerAnomaly(AnomalyReason.signalDrop);
    }
    expect(presenter.shown, hasLength(6));
  });

  test('iOS keeps the old behaviour: no activity gate', () async {
    final ios = SurveyScheduler(store: InMemoryKeyValueStore(), presenter: presenter, clock: () => now);
    await ios.ensureBaseline();
    now = now.add(const Duration(hours: 2));
    expect(await ios.maybeTriggerPeriodic(), isTrue);
  });
}

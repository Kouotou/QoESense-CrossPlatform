import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qoesense/src/application/mos_pipeline.dart';
import 'package:qoesense/src/application/self_report.dart';
import 'package:qoesense/src/application/settings_keys.dart';
import 'package:qoesense/src/application/stores.dart';
import 'package:qoesense/src/data/backend/backend_ports.dart';
import 'package:qoesense/src/data/local/telemetry_buffer.dart';
import 'package:qoesense/src/domain/capabilities.dart';
import 'package:qoesense/src/domain/enums.dart';
import 'package:qoesense/src/domain/telemetry_sample.dart';
import 'package:qoesense/src/platform/capability_source.dart';
import 'package:qoesense/src/presentation/app_services.dart';
import 'package:qoesense/src/presentation/qoesense_app.dart';

import '../support/fixtures.dart';

/// The iOS onboarding variant and the in-app survey sheet (docs/PHASE4_IOS.md §4-5).
class _IosCaps implements CapabilitySource {
  bool always = false;
  @override
  Future<PlatformCapabilities> load() async => PlatformCapabilities(
    platform: ClientPlatform.ios,
    osMajorVersion: 26,
    deviceModel: 'iPhone15,3',
    groups: {
      for (final g in FieldGroup.values) g: FieldAvailability.unsupportedOnPlatform,
      FieldGroup.location: FieldAvailability.available,
      FieldGroup.backgroundLocation: always ? FieldAvailability.available : FieldAvailability.permissionMissing,
      FieldGroup.notifications: FieldAvailability.available,
    },
  );
}

class _Control implements CollectorControl {
  _Control(this.log);
  final List<String> log;
  bool enabled = false;
  @override
  Future<void> setCollectionEnabled(bool e) async {
    log.add('collection:$e');
    enabled = e;
  }

  @override
  Future<CollectorStatus> status() async => CollectorStatus(enabled: enabled, running: enabled);
  @override
  Future<void> presentTestSurvey() async => log.add('testSurvey');
  @override
  Future<TelemetrySample> runTestCapture() async => iosInCall;
  @override
  Future<void> openSettings(SettingsTarget t) async => log.add('settings:${t.name}');
  @override
  Future<void> uploadNow() async => log.add('uploadNow');
  @override
  Future<void> recordConsent(int ms) async => log.add('consent');
}

class _Perms implements PermissionGateway {
  _Perms(this.log);
  final List<String> log;
  @override
  Future<void> requestForeground() async => log.add('perm:whenInUse');
  @override
  Future<void> requestBackground() async => log.add('perm:always+notifications');
  @override
  Future<bool> isBatteryOptimizationIgnored() async => true;
}

class _Inbox implements SurveyInbox {
  SurveyPrompt? waiting;
  final submitted = <SurveyAnswer>[];
  final _opened = StreamController<void>.broadcast();

  void tap(SurveyPrompt p) {
    waiting = p;
    _opened.add(null);
  }

  @override
  Stream<void> get opened => _opened.stream;

  @override
  Future<SurveyPrompt?> takeOpened() async {
    final p = waiting;
    waiting = null;
    return p;
  }

  @override
  Future<void> submit(SurveyAnswer answer) async => submitted.add(answer);
}

void main() {
  late List<String> log;
  late InMemoryKeyValueStore kv;
  late _Inbox inbox;
  late _IosCaps caps;

  AppServices services() => AppServices(
    capabilities: caps,
    control: _Control(log),
    permissions: _Perms(log),
    buffer: InMemoryTelemetryBuffer(),
    settings: kv,
    backend: const Backend.unconfigured(),
    platform: ClientPlatform.ios,
    surveyInbox: inbox,
  );

  setUp(() {
    log = [];
    kv = InMemoryKeyValueStore();
    inbox = _Inbox();
    caps = _IosCaps();
  });

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(find.text(text), 200);
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets('iOS onboarding: iOS texts, no Android-only steps, consent before anything', (tester) async {
    await tester.pumpWidget(QoESenseApp(services: services()));
    await tester.pumpAndSettle();
    expect(find.textContaining('the network type and connection quality that iOS makes available'), findsOneWidget);
    await tapText(tester, 'Get started');
    expect(find.textContaining('WHAT WE COLLECT ON AN IPHONE'), findsOneWidget);
    expect(find.textContaining('Usage Access'), findsNothing);
    expect(log, isEmpty, reason: 'nothing may run before consent');
    await tapText(tester, 'I agree, continue');
    expect(kv.values[SettingsKeys.consentGivenAtMs], isNotNull);
    expect(find.textContaining('"While Using the App"'), findsOneWidget);
    await tapText(tester, 'Grant permissions');
    expect(find.textContaining('"Always Allow"'), findsOneWidget);
    await tapText(tester, 'Grant access');

    // The last step replaces usage access / battery / overlay.
    expect(find.text('Keeping collection running'), findsOneWidget);
    expect(find.textContaining('Battery optimization'), findsNothing);
    expect(find.textContaining('Display over other apps'), findsNothing);
    expect(find.text('Location "Always": not granted'), findsOneWidget);
    expect(find.text('Notifications: allowed'), findsOneWidget);
    await tapText(tester, 'Open Settings');
    expect(log.last, 'settings:appDetails');

    await tester.scrollUntilVisible(find.byKey(const ValueKey('finish')), 200);
    await tester.tap(find.byKey(const ValueKey('finish')));
    await tester.pumpAndSettle();
    expect(log, ['consent', 'perm:whenInUse', 'perm:always+notifications', 'settings:appDetails', 'collection:true']);
    expect(find.text('Collection'), findsOneWidget);
  });

  testWidgets('a notification tapped before launch opens the sheet; the answer is self-reported', (tester) async {
    kv.values[SettingsKeys.onboardingComplete] = 'true';
    inbox.waiting = const SurveyPrompt(triggerType: MosTriggerType.anomaly, promptedAtMs: 1000);
    await tester.pumpWidget(QoESenseApp(services: services()));
    await tester.pumpAndSettle();
    expect(find.text('How was your network experience just now?'), findsOneWidget);

    final submit = find.byKey(const ValueKey('submitSurvey'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull, reason: 'a score is required');
    await tester.tap(find.text('4'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey(SelfReportOption.whatsappCall)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('How was your network experience just now?'), findsNothing);
    final a = inbox.submitted.single;
    expect(a.score, 4);
    expect(a.triggerType, MosTriggerType.anomaly);
    expect(a.presentationMode, PresentationMode.notification);
    expect(a.promptedAtMs, 1000);
    expect(a.selfReport?.appPackage, 'com.whatsapp');
    expect(a.selfReport?.sessionType, AppSessionType.videoConferencing);
    expect(a.responseId, hasLength(36));
  });

  testWidgets('a tap while the app runs opens the sheet; skipping the question leaves the context unknown', (
    tester,
  ) async {
    kv.values[SettingsKeys.onboardingComplete] = 'true';
    await tester.pumpWidget(QoESenseApp(services: services()));
    await tester.pumpAndSettle();
    expect(find.text('How was your network experience just now?'), findsNothing);

    inbox.tap(const SurveyPrompt(triggerType: MosTriggerType.periodic, promptedAtMs: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('submitSurvey')));
    await tester.tap(find.byKey(const ValueKey('submitSurvey')));
    await tester.pumpAndSettle();
    expect(inbox.submitted.single.selfReport, isNull);
    expect(inbox.submitted.single.score, 2);
  });

  testWidgets('"Not now" closes the sheet without a rating', (tester) async {
    kv.values[SettingsKeys.onboardingComplete] = 'true';
    inbox.waiting = const SurveyPrompt(triggerType: MosTriggerType.periodic, promptedAtMs: 5);
    await tester.pumpWidget(QoESenseApp(services: services()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Not now'));
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(inbox.submitted, isEmpty);
    expect(find.text('How was your network experience just now?'), findsNothing);
  });

  testWidgets('no survey sheet during onboarding', (tester) async {
    inbox.waiting = const SurveyPrompt(triggerType: MosTriggerType.periodic, promptedAtMs: 5);
    await tester.pumpWidget(QoESenseApp(services: services()));
    await tester.pumpAndSettle();
    expect(find.text('How was your network experience just now?'), findsNothing);
    expect(inbox.waiting, isNotNull, reason: 'the prompt waits until onboarding is done');
  });
}

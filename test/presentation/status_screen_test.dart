import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qoesense/src/application/settings_keys.dart';
import 'package:qoesense/src/application/stores.dart';
import 'package:qoesense/src/data/backend/backend_ports.dart';
import 'package:qoesense/src/data/local/telemetry_buffer.dart';
import 'package:qoesense/src/domain/capabilities.dart';
import 'package:qoesense/src/domain/enums.dart';
import 'package:qoesense/src/domain/telemetry_sample.dart';
import 'package:qoesense/src/platform/capability_source.dart';
import 'package:qoesense/src/platform/telemetry_api.g.dart';
import 'package:qoesense/src/presentation/app_services.dart';
import 'package:qoesense/src/presentation/qoesense_app.dart';

import '../support/fixtures.dart';

class _Caps implements CapabilitySource {
  _Caps([this.state = FieldAvailability.permissionMissing]) : missing = const {};
  _Caps.withMissing(this.state, this.missing);
  final FieldAvailability state;
  final Set<FieldGroup> missing;
  @override
  Future<PlatformCapabilities> load() async => PlatformCapabilities(
    platform: ClientPlatform.android,
    osMajorVersion: 34,
    deviceModel: 'SM-A155F',
    groups: {for (final g in FieldGroup.values) g: missing.contains(g) ? FieldAvailability.permissionMissing : state},
  );
}

class _Control implements CollectorControl {
  _Control(this.log, this.buffer);
  final List<String> log;
  final TelemetryBuffer buffer;
  bool enabled = false;
  @override
  Future<void> setCollectionEnabled(bool e) async {
    log.add('collection:$e');
    enabled = e;
  }

  bool? runningOverride;
  bool? mobileData;
  @override
  Future<CollectorStatus> status() async =>
      CollectorStatus(enabled: enabled, running: runningOverride ?? enabled, mobileDataUploads: mobileData);
  @override
  Future<void> presentTestSurvey() async => log.add('testSurvey');
  @override
  Future<TelemetrySample> runTestCapture() async {
    await buffer.append(androidFull);
    return androidFull;
  }

  @override
  Future<void> openSettings(SettingsTarget t) async => log.add('settings:${t.name}');
  AutoStartBrand? brand = AutoStartBrand.transsion;
  @override
  Future<AutoStartBrand?> autoStartBrand() async => brand;
  @override
  Future<void> uploadNow() async => log.add('uploadNow');
  @override
  Future<void> recordConsent(int ms) async => log.add('consent');
  @override
  Future<void> setMobileDataUploads(bool allowed) async => log.add('mobileData:$allowed');
}

class _Perms implements PermissionGateway {
  _Perms(this.log, {this.battery = false});
  final List<String> log;
  final bool battery;
  @override
  Future<void> requestForeground() async => log.add('perm:foreground');
  @override
  Future<void> requestBackground() async => log.add('perm:background');
  @override
  Future<bool> isBatteryOptimizationIgnored() async => battery;
}

void main() {
  late List<String> log;
  late InMemoryKeyValueStore kv;
  late InMemoryTelemetryBuffer buffer;

  AppServices services() => AppServices(
    capabilities: _Caps(),
    control: _Control(log, buffer),
    permissions: _Perms(log),
    buffer: buffer,
    settings: kv,
    backend: const Backend.unconfigured(),
  );

  setUp(() {
    log = [];
    kv = InMemoryKeyValueStore();
    buffer = InMemoryTelemetryBuffer();
  });

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(find.text(text), 200);
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets('onboarding follows the reference order; consent is stored before collection starts', (tester) async {
    await tester.pumpWidget(QoESenseApp(services: services()));
    await tester.pumpAndSettle();
    expect(find.text('QoESense research study'), findsOneWidget);
    await tapText(tester, 'Get started');
    expect(find.text('Research consent & privacy'), findsOneWidget);
    expect(log, isEmpty, reason: 'nothing may run before consent');
    await tapText(tester, 'I agree, continue');
    expect(kv.values[SettingsKeys.consentGivenAtMs], isNotNull);
    await tapText(tester, 'Grant permissions');
    await tapText(tester, 'Grant access');
    await tester.scrollUntilVisible(find.byKey(const ValueKey('finish')), 200);
    await tester.tap(find.byKey(const ValueKey('finish')));
    await tester.pumpAndSettle();
    expect(log, ['consent', 'perm:foreground', 'perm:background', 'collection:true']);
    expect(kv.values[SettingsKeys.onboardingComplete], 'true');
    // The welcome check comes next; nothing is granted in this fake, so it lists what's missing.
    expect(find.text('Welcome to QoESense'), findsOneWidget);
    expect(find.byKey(const ValueKey('missing:overlay')), findsOneWidget);
    expect(find.byKey(const ValueKey('missing:battery')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('welcomeSkip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('welcomeSkip')));
    await tester.pumpAndSettle();
    expect(kv.values[SettingsKeys.welcomeCheckSeen], 'true');
    expect(find.text('Collection'), findsOneWidget); // status screen
  });

  testWidgets('welcome check: all allowed shows the done message and Continue', (tester) async {
    kv.values[SettingsKeys.onboardingComplete] = 'true';
    final svc = AppServices(
      capabilities: _Caps(FieldAvailability.available),
      control: _Control(log, buffer),
      permissions: _Perms(log, battery: true),
      buffer: buffer,
      settings: kv,
      backend: const Backend.unconfigured(),
      backgroundPopupStatus: () async => 'allowed',
    );
    await tester.pumpWidget(QoESenseApp(services: svc));
    await tester.pumpAndSettle();
    expect(find.text('Welcome, you are now done with all the steps.'), findsOneWidget);
    expect(find.byKey(const ValueKey('missing:overlay')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('welcomeContinue')));
    await tester.pumpAndSettle();
    expect(find.text('Collection'), findsOneWidget);
  });

  testWidgets('welcome check: a missing item opens its settings screen; Xiaomi pop-ups are listed', (tester) async {
    kv.values[SettingsKeys.onboardingComplete] = 'true';
    final svc = AppServices(
      capabilities: _Caps.withMissing(FieldAvailability.available, {FieldGroup.surveyOverlay}),
      control: _Control(log, buffer),
      permissions: _Perms(log, battery: true),
      buffer: buffer,
      settings: kv,
      backend: const Backend.unconfigured(),
      backgroundPopupStatus: () async => 'denied',
    );
    await tester.pumpWidget(QoESenseApp(services: svc));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('missing:overlay')), findsOneWidget);
    expect(find.byKey(const ValueKey('missing:backgroundPopups')), findsOneWidget);
    expect(find.byKey(const ValueKey('missing:location')), findsNothing);
    await tester.tap(
      find.descendant(of: find.byKey(const ValueKey('missing:backgroundPopups')), matching: find.text('Allow')),
    );
    await tester.pumpAndSettle();
    expect(log, contains('settings:backgroundPopup'));
  });

  testWidgets('the last onboarding step shows the brand auto-start instructions and opens its screen', (tester) async {
    await tester.pumpWidget(QoESenseApp(services: services()));
    await tester.pumpAndSettle();
    await tapText(tester, 'Get started');
    await tapText(tester, 'I agree, continue');
    await tapText(tester, 'Grant permissions');
    await tapText(tester, 'Grant access');
    await tester.scrollUntilVisible(find.byKey(const ValueKey('autoStart')), 200);
    expect(find.textContaining('Infinix, Tecno and itel'), findsOneWidget);
    await tester.ensureVisible(find.text('Open auto-start settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open auto-start settings'));
    expect(log, contains('settings:autoStart'));
  });

  testWidgets('without consent there is no way to start collection from onboarding', (tester) async {
    await tester.pumpWidget(QoESenseApp(services: services()));
    await tester.pumpAndSettle();
    await tapText(tester, 'Get started');
    expect(find.byKey(const ValueKey('finish')), findsNothing);
    expect(log, isNot(contains('collection:true')));
  });

  testWidgets('status screen: toggle, buffered count, test capture, unconfigured backend notice', (tester) async {
    kv.values[SettingsKeys.onboardingComplete] = 'true';
    kv.values[SettingsKeys.welcomeCheckSeen] = 'true';
    await tester.pumpWidget(QoESenseApp(services: services()));
    await tester.pumpAndSettle();
    expect(find.textContaining("Uploads aren't set up"), findsOneWidget);
    expect(find.text('never'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('buffered'))).data, '0');

    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.byKey(const ValueKey('testCapture')), 200, scrollable: list);
    await tester.tap(find.byKey(const ValueKey('testCapture')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('message')), 200, scrollable: list);
    expect(find.byKey(const ValueKey('message')), findsOneWidget);
    expect(await buffer.count(), 1);

    await tester.scrollUntilVisible(find.byKey(const ValueKey('collection')), -200, scrollable: list);
    await tester.tap(find.byKey(const ValueKey('collection')));
    await tester.pumpAndSettle();
    expect(log, contains('collection:true'));
  });

  testWidgets('the mobile-data switch shows on Android and stores the choice; hidden when null (iOS)', (tester) async {
    kv.values[SettingsKeys.onboardingComplete] = 'true';
    kv.values[SettingsKeys.welcomeCheckSeen] = 'true';
    final svc = services();
    await tester.pumpWidget(QoESenseApp(services: svc));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mobileData')), findsNothing);

    final control = svc.control as _Control..mobileData = true;
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(QoESenseApp(services: svc));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('mobileData')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Upload without Wi-Fi'), findsOneWidget);
    expect(find.text('Your messages, browsing history and contacts are never collected.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mobileData')));
    await tester.pumpAndSettle();
    expect(control.log, contains('mobileData:false'));
  });

  testWidgets('opening the app restarts collection that should be on but was killed', (tester) async {
    kv.values[SettingsKeys.onboardingComplete] = 'true';
    kv.values[SettingsKeys.welcomeCheckSeen] = 'true';
    final svc = services();
    (svc.control as _Control).enabled = true; // flag on...
    final control = svc.control as _Control;
    control.runningOverride = false; // ...but the service isn't running
    await tester.pumpWidget(QoESenseApp(services: svc));
    await tester.pumpAndSettle();
    expect(log, contains('collection:true'));
  });

  testWidgets('French strings are used on a French device', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('fr')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(QoESenseApp(services: services()));
    await tester.pumpAndSettle();
    expect(find.text('Étude de recherche QoESense'), findsOneWidget);
  });

  test('capability channel message maps 1:1 onto the domain model', () {
    final caps = mapCapabilityReport(
      CapabilityReportMessage(
        platform: 'ANDROID',
        osMajorVersion: 34,
        deviceModel: 'SM-A155F',
        radioSignal: Availability.available,
        cqi: Availability.available,
        physicalChannel: Availability.restricted,
        radioAccessTechnology: Availability.permissionMissing,
        connectivity: Availability.available,
        throughput: Availability.available,
        foregroundApp: Availability.permissionMissing,
        callDetection: Availability.permissionMissing,
        location: Availability.available,
        backgroundLocation: Availability.permissionMissing,
        notifications: Availability.available,
        surveyOverlay: Availability.unsupportedOnPlatform,
      ),
    );
    expect(caps.groups, hasLength(FieldGroup.values.length));
    expect(caps.of(FieldGroup.physicalChannel), FieldAvailability.restricted);
  });
}

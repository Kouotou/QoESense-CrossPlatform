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
  @override
  Future<PlatformCapabilities> load() async => PlatformCapabilities(
    platform: ClientPlatform.android,
    osMajorVersion: 34,
    deviceModel: 'SM-A155F',
    groups: {for (final g in FieldGroup.values) g: FieldAvailability.permissionMissing},
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

  @override
  Future<CollectorStatus> status() async => CollectorStatus(enabled: enabled, running: enabled);
  @override
  Future<void> presentTestSurvey() async => log.add('testSurvey');
  @override
  Future<TelemetrySample> runTestCapture() async {
    await buffer.append(androidFull);
    return androidFull;
  }

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
  Future<void> requestForeground() async => log.add('perm:foreground');
  @override
  Future<void> requestBackground() async => log.add('perm:background');
  @override
  Future<bool> isBatteryOptimizationIgnored() async => false;
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
    expect(find.text('Collection'), findsOneWidget); // status screen
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
    await tester.pumpWidget(QoESenseApp(services: services()));
    await tester.pumpAndSettle();
    expect(find.textContaining("Uploads aren't set up"), findsOneWidget);
    expect(find.text('never'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('buffered'))).data, '0');

    await tester.tap(find.byKey(const ValueKey('testCapture')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('message')), findsOneWidget);
    expect(await buffer.count(), 1);

    await tester.tap(find.byKey(const ValueKey('collection')));
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

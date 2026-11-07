import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qoesense/src/domain/capabilities.dart';
import 'package:qoesense/src/domain/enums.dart';
import 'package:qoesense/src/platform/capability_source.dart';
import 'package:qoesense/src/platform/telemetry_api.g.dart';
import 'package:qoesense/src/presentation/qoesense_app.dart';

class _FakeSource implements CapabilitySource {
  _FakeSource(this.result);
  final PlatformCapabilities result;
  @override
  Future<PlatformCapabilities> load() async => result;
}

class _FailingSource implements CapabilitySource {
  @override
  Future<PlatformCapabilities> load() => Future.error(StateError('channel down'));
}

void main() {
  final ios = PlatformCapabilities(
    platform: ClientPlatform.ios,
    osMajorVersion: 18,
    deviceModel: 'iPhone14,5',
    groups: {
      for (final g in FieldGroup.values) g: FieldAvailability.unsupportedOnPlatform,
      FieldGroup.location: FieldAvailability.permissionMissing,
      FieldGroup.connectivity: FieldAvailability.available,
    },
  );

  testWidgets('lists every field group with its availability', (tester) async {
    await tester.pumpWidget(QoESenseApp(capabilities: _FakeSource(ios)));
    await tester.pumpAndSettle();
    expect(find.text('IOS 18 · iPhone14,5'), findsOneWidget);
    for (final g in FieldGroup.values) {
      await tester.scrollUntilVisible(find.byKey(ValueKey(g)), 50);
      expect(find.byKey(ValueKey(g)), findsOneWidget);
    }
    expect(find.text('Permission needed'), findsOneWidget);
  });

  testWidgets('a channel failure is shown, not swallowed', (tester) async {
    await tester.pumpWidget(QoESenseApp(capabilities: _FailingSource()));
    await tester.pumpAndSettle();
    expect(find.textContaining('channel down'), findsOneWidget);
  });

  testWidgets('French strings are available', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('fr')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(QoESenseApp(capabilities: _FakeSource(ios)));
    await tester.pumpAndSettle();
    expect(find.text("Capacités de l'appareil"), findsOneWidget);
  });

  test('channel message maps 1:1 onto the domain model', () {
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
    expect(caps.platform, ClientPlatform.android);
    expect(caps.groups, hasLength(FieldGroup.values.length));
    expect(caps.of(FieldGroup.physicalChannel), FieldAvailability.restricted);
    expect(caps.of(FieldGroup.surveyOverlay), FieldAvailability.unsupportedOnPlatform);
  });
}

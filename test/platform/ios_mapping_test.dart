import 'package:flutter_test/flutter_test.dart';
import 'package:qoesense/src/application/captured_sample.dart';
import 'package:qoesense/src/application/mos_pipeline.dart';
import 'package:qoesense/src/data/upload/batch_serializer.dart';
import 'package:qoesense/src/domain/capabilities.dart';
import 'package:qoesense/src/domain/contract_rules.dart';
import 'package:qoesense/src/domain/enums.dart';
import 'package:qoesense/src/platform/android_collector.dart';
import 'package:qoesense/src/platform/capability_source.dart';
import 'package:qoesense/src/platform/telemetry_api.g.dart';

import '../support/fixtures.dart';

/// The Swift capture -> domain mapping (docs/PHASE4_IOS.md §2). The message is what
/// IosSampleCapturer.assemble builds; these tests pin that it becomes a contract-valid iOS
/// row, field for field the same as the I1 / I2 golden records.
void main() {
  /// Mirrors IosSampleCapturer: radio, CQI, physical channel and foreground app are always
  /// NOT_SUPPORTED with null values; isRoaming is always null.
  CapturedSampleMessage message({
    String? networkType = 'LTE',
    MeasurementStatus networkTypeStatus = MeasurementStatus.ok,
    String? connectionType = 'CELLULAR',
    int? throughput = 98304,
    int? window = 15000,
    MeasurementStatus throughputStatus = MeasurementStatus.ok,
    SessionTypeMessage session = SessionTypeMessage.videoConferencing,
    MeasurementStatus locationStatus = MeasurementStatus.ok,
    List<String> capabilities = const ['CONNECTIVITY', 'THROUGHPUT', 'NETWORK_TYPE', 'LOCATION'],
  }) {
    final hasFix = locationStatus == MeasurementStatus.ok || locationStatus == MeasurementStatus.stale;
    return CapturedSampleMessage(
      radioStatus: MeasurementStatus.notSupported,
      cqiStatus: MeasurementStatus.notSupported,
      physicalChannelStatus: MeasurementStatus.notSupported,
      networkType: networkType,
      networkTypeStatus: networkTypeStatus,
      connectionType: connectionType,
      connectivityStatus: connectionType == null ? MeasurementStatus.unavailable : MeasurementStatus.ok,
      throughputBytesPerSecond: throughput,
      throughputWindowMs: window,
      throughputStatus: throughputStatus,
      appSessionType: session,
      foregroundAppStatus: MeasurementStatus.notSupported,
      latitude: hasFix ? 3.848 : null,
      longitude: hasFix ? 11.5021 : null,
      locationAccuracyMeters: hasFix ? 65.0 : null,
      locationAgeMs: hasFix ? 3100 : null,
      locationStatus: locationStatus,
      capabilitySet: capabilities,
      deviceModel: 'iPhone14,5',
      osSdkInt: 18,
      osVersion: '18.1',
      appId: 'io.github.kouotou.qoesense',
      appVersion: '2.0.0',
      appBuild: 1,
    );
  }

  test('an iOS capture in a call assembles to exactly the I1 golden record', () {
    final s = assembleSample(
      c: mapCapturedSample(message(), platform: ClientPlatform.ios),
      rtt: const RttResult(FieldStatus.ok, 131),
      rttMethod: 'DART_HTTPS_GET_GENERATE_204',
      timestampMs: 1762500075000,
      captureDurationMs: 4020,
      utcOffsetMinutes: 60,
    );
    expect(contractViolations(s), isEmpty);
    const v2 = BatchSerializer(version: ContractVersion.v2);
    expect(v2.lineFields(s, 'uid-123'), v2.lineFields(iosInCall, 'uid-123'));
  });

  test('every iOS capture is IOS_RAT, NOT_SUPPORTED for the radio groups, and contract-valid', () {
    for (final m in [
      message(),
      message(connectionType: 'WIFI', networkType: 'NR', session: SessionTypeMessage.none),
      message(connectionType: null, networkType: 'UNKNOWN'),
      message(throughput: null, window: null, throughputStatus: MeasurementStatus.unavailable),
      message(locationStatus: MeasurementStatus.permissionDenied, capabilities: ['CONNECTIVITY', 'THROUGHPUT']),
      message(locationStatus: MeasurementStatus.timeout),
      message(locationStatus: MeasurementStatus.stale),
      message(locationStatus: MeasurementStatus.restricted),
      // The simulator / a Wi-Fi-only iPad: no modem, so no RAT.
      message(
        networkType: null,
        networkTypeStatus: MeasurementStatus.notSupported,
        capabilities: ['CONNECTIVITY', 'THROUGHPUT', 'LOCATION'],
      ),
    ]) {
      final s = assembleSample(
        c: mapCapturedSample(m, platform: ClientPlatform.ios),
        rtt: const RttResult.notAttempted(),
        rttMethod: 'DART_HTTPS_GET_GENERATE_204',
        timestampMs: 1,
        captureDurationMs: 2,
        utcOffsetMinutes: 60,
      );
      expect(contractViolations(s), isEmpty, reason: '${m.networkType} ${m.connectionType} ${m.locationStatus}');
      expect(s.platform, ClientPlatform.ios);
      expect(s.telemetryCapabilityTier, TelemetryCapabilityTier.iosRat);
      expect(s.isRoaming, isNull);
      expect(s.rsrp, isNull);
      expect(s.cqiSupported, isFalse);
      expect(s.androidVersion, 18, reason: 'D-5: the iOS major version');
      for (final g in [
        SampleFieldGroup.radio,
        SampleFieldGroup.cqi,
        SampleFieldGroup.physicalChannel,
        SampleFieldGroup.foregroundApp,
      ]) {
        expect(s.provenance.statusOf(g), FieldStatus.notSupported);
        expect(s.provenance.capabilitySet, isNot(contains(g)));
      }
    }
  });

  test('iOS uploads stay byte-identical to v1 under the default serializer', () {
    final s = assembleSample(
      c: mapCapturedSample(message(), platform: ClientPlatform.ios),
      rtt: const RttResult(FieldStatus.ok, 131),
      rttMethod: 'DART_HTTPS_GET_GENERATE_204',
      timestampMs: 1762500075000,
      captureDurationMs: 4020,
      utcOffsetMinutes: 60,
    );
    final line = const BatchSerializer().lineFields(s, 'uid-123');
    expect(line.containsKey('platform'), isFalse, reason: 'v2 keys only after the v2 functions deploy');
    expect(line['telemetryCapabilityTier'], 'IOS_RAT');
  });

  test('a self-reported answer from the in-app sheet survives the channel both ways', () {
    const answer = SurveyAnswer(
      responseId: 'r1',
      score: 4,
      triggerType: MosTriggerType.postSession,
      tapMs: 1762500300000,
      promptedAtMs: 1762500250000,
      presentationMode: PresentationMode.notification,
      selfReport: SelfReportedContext(appPackage: 'com.whatsapp', sessionType: AppSessionType.videoConferencing),
    );
    final back = mapSurveyAnswer(surveyAnswerMessage(answer));
    expect(back.selfReport?.appPackage, 'com.whatsapp');
    expect(back.selfReport?.sessionType, AppSessionType.videoConferencing);
    expect(back.presentationMode, PresentationMode.notification);
    expect(back.promptedAtMs, 1762500250000);

    // A notification-action tap (no question asked) carries no self-report.
    final action = mapSurveyAnswer(
      SurveyAnswerMessage(
        responseId: 'r2',
        score: 3,
        triggerType: 'PERIODIC',
        tapMs: 9,
        presentationMode: 'NOTIFICATION_ACTION',
      ),
    );
    expect(action.selfReport, isNull);
    expect(action.presentationMode, PresentationMode.notificationAction);

    expect(
      () => mapSurveyAnswer(
        SurveyAnswerMessage(
          responseId: 'r3',
          score: 3,
          triggerType: 'PERIODIC',
          tapMs: 9,
          presentationMode: 'NOTIFICATION',
          contextSessionType: 'GAMING',
        ),
      ),
      throwsFormatException,
    );
  });

  test('the iOS capability report maps honestly: radio, CQI, physical channel, app and overlay unsupported', () {
    final caps = mapCapabilityReport(
      CapabilityReportMessage(
        platform: 'IOS',
        osMajorVersion: 26,
        deviceModel: 'iPhone15,3',
        radioSignal: Availability.unsupportedOnPlatform,
        cqi: Availability.unsupportedOnPlatform,
        physicalChannel: Availability.unsupportedOnPlatform,
        radioAccessTechnology: Availability.available,
        connectivity: Availability.available,
        throughput: Availability.available,
        foregroundApp: Availability.unsupportedOnPlatform,
        callDetection: Availability.available,
        location: Availability.available,
        backgroundLocation: Availability.permissionMissing,
        notifications: Availability.available,
        surveyOverlay: Availability.unsupportedOnPlatform,
      ),
    );
    expect(caps.platform, ClientPlatform.ios);
    expect(caps.of(FieldGroup.radioSignal), FieldAvailability.unsupportedOnPlatform);
    expect(caps.of(FieldGroup.foregroundApp), FieldAvailability.unsupportedOnPlatform);
    expect(caps.of(FieldGroup.surveyOverlay), FieldAvailability.unsupportedOnPlatform);
    expect(caps.of(FieldGroup.backgroundLocation), FieldAvailability.permissionMissing);
    expect(caps.isAvailable(FieldGroup.callDetection), isTrue);
  });
}

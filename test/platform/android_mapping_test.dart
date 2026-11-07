import 'package:flutter_test/flutter_test.dart';
import 'package:qoesense/src/application/captured_sample.dart';
import 'package:qoesense/src/domain/contract_rules.dart';
import 'package:qoesense/src/domain/enums.dart';
import 'package:qoesense/src/platform/android_collector.dart';
import 'package:qoesense/src/platform/telemetry_api.g.dart';

/// Native message -> domain mapping, the seam between Kotlin and the shared rules.
void main() {
  CapturedSampleMessage message({MeasurementStatus radio = MeasurementStatus.ok, int? cqi = 9, int? bw}) =>
      CapturedSampleMessage(
        rsrp: radio == MeasurementStatus.ok || radio == MeasurementStatus.stale ? -95 : null,
        signalStrengthLevel: radio == MeasurementStatus.ok || radio == MeasurementStatus.stale ? 3 : null,
        radioStatus: radio,
        cellInfoAgeMs: radio == MeasurementStatus.stale ? 90000 : null,
        cqi: cqi,
        cqiStatus: cqi == null ? MeasurementStatus.unavailable : MeasurementStatus.ok,
        cellBandwidthKhz: bw,
        physicalChannelStatus: bw == null ? MeasurementStatus.restricted : MeasurementStatus.ok,
        networkType: 'LTE',
        networkTypeStatus: MeasurementStatus.ok,
        connectionType: 'CELLULAR',
        isRoaming: false,
        connectivityStatus: MeasurementStatus.ok,
        throughputStatus: MeasurementStatus.unavailable,
        appSessionType: SessionTypeMessage.socialMedia,
        foregroundAppPackage: 'com.whatsapp',
        foregroundAppStatus: MeasurementStatus.ok,
        locationStatus: MeasurementStatus.timeout,
        capabilitySet: ['RADIO', 'CQI', 'NETWORK_TYPE', 'CONNECTIVITY', 'THROUGHPUT', 'FOREGROUND_APP', 'LOCATION'],
        deviceModel: 'SM-A155F',
        osSdkInt: 34,
        osVersion: '14',
        appId: 'io.github.kouotou.qoesense',
        appVersion: '2.0.0',
        appBuild: 1,
      );

  test('every native status maps onto exactly one contract status', () {
    final mapped = {for (final s in MeasurementStatus.values) mapStatus(s)};
    expect(mapped, FieldStatus.values.toSet());
  });

  test('a mapped + assembled capture satisfies the contract and resolves the tier like the reference', () {
    for (final (msg, tier) in [
      (message(), TelemetryCapabilityTier.cqi29),
      (message(cqi: null), TelemetryCapabilityTier.base26),
      (message(bw: 20000), TelemetryCapabilityTier.physchan30),
      (message(radio: MeasurementStatus.stale), TelemetryCapabilityTier.cqi29),
      (message(radio: MeasurementStatus.permissionDenied, cqi: null), TelemetryCapabilityTier.base26),
    ]) {
      final s = assembleSample(
        c: mapCapturedSample(msg),
        rtt: const RttResult(FieldStatus.ok, 70),
        rttMethod: 'DART_HTTPS_GET_GENERATE_204',
        timestampMs: 1,
        captureDurationMs: 2,
        utcOffsetMinutes: 60,
      );
      expect(contractViolations(s), isEmpty, reason: '$tier');
      expect(s.telemetryCapabilityTier, tier);
      expect(s.cqiSupported, msg.cqi != null);
      expect(s.platform, ClientPlatform.android);
      expect(s.provenance.capabilitySet, contains(SampleFieldGroup.rtt));
    }
  });

  test('an RTT that was not measured carries no method', () {
    final s = assembleSample(
      c: mapCapturedSample(message()),
      rtt: const RttResult(FieldStatus.timeout),
      rttMethod: 'DART_HTTPS_GET_GENERATE_204',
      timestampMs: 1,
      captureDurationMs: 2,
      utcOffsetMinutes: 60,
    );
    expect(s.rttMs, isNull);
    expect(s.provenance.rttMethod, isNull);
    expect(contractViolations(s), isEmpty);
  });

  test('survey answers map, and unknown wire values are rejected rather than guessed', () {
    final a = mapSurveyAnswer(
      SurveyAnswerMessage(
        responseId: 'r',
        score: 4,
        triggerType: 'POST_SESSION',
        tapMs: 9,
        presentationMode: 'NOTIFICATION',
      ),
    );
    expect(a.triggerType, MosTriggerType.postSession);
    expect(a.presentationMode, PresentationMode.notification);
    expect(
      () => mapSurveyAnswer(
        SurveyAnswerMessage(responseId: 'r', score: 4, triggerType: 'BOGUS', tapMs: 9, presentationMode: 'OVERLAY'),
      ),
      throwsFormatException,
    );
  });
}

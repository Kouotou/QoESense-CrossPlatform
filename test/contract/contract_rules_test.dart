import 'package:flutter_test/flutter_test.dart';
import 'package:qoesense/src/domain/contract_rules.dart';
import 'package:qoesense/src/domain/enums.dart';
import 'package:qoesense/src/domain/telemetry_sample.dart';

import '../support/fixtures.dart';

/// Copies [base], replacing selected fields - enough to break one rule at a time.
TelemetrySample mutate(
  TelemetrySample base, {
  int? rsrp,
  bool clearRsrp = false,
  int? rttMs,
  Map<SampleFieldGroup, FieldStatus>? status,
  Set<SampleFieldGroup>? capabilitySet,
  TelemetryCapabilityTier? tier,
  bool? isRoaming,
  int? cellInfoAgeMs,
  bool clearCellInfoAge = false,
}) {
  final p = base.provenance;
  return TelemetrySample(
    timestampMs: base.timestampMs,
    rsrp: clearRsrp ? null : rsrp ?? base.rsrp,
    rsrq: base.rsrq,
    rssnr: base.rssnr,
    timingAdvance: base.timingAdvance,
    networkType: base.networkType,
    cellIdentityHash: base.cellIdentityHash,
    trackingAreaCode: base.trackingAreaCode,
    signalStrengthLevel: base.signalStrengthLevel,
    cqi: base.cqi,
    cqiSupported: base.cqiSupported,
    cellBandwidthKhz: base.cellBandwidthKhz,
    downlinkChannelNumber: base.downlinkChannelNumber,
    uplinkChannelNumber: base.uplinkChannelNumber,
    connectionType: base.connectionType,
    isRoaming: isRoaming ?? base.isRoaming,
    throughputBytesPerSecond: base.throughputBytesPerSecond,
    rttMs: rttMs ?? base.rttMs,
    foregroundAppPackage: base.foregroundAppPackage,
    appSessionType: base.appSessionType,
    latitude: base.latitude,
    longitude: base.longitude,
    locationAccuracyMeters: base.locationAccuracyMeters,
    deviceModel: base.deviceModel,
    androidVersion: base.androidVersion,
    appVersion: base.appVersion,
    telemetryCapabilityTier: tier ?? base.telemetryCapabilityTier,
    platform: base.platform,
    provenance: SampleProvenance(
      fieldStatus: {...p.fieldStatus, ...?status},
      capabilitySet: capabilitySet ?? p.capabilitySet,
      appId: p.appId,
      appBuild: p.appBuild,
      osVersion: p.osVersion,
      utcOffsetMinutes: p.utcOffsetMinutes,
      captureDurationMs: p.captureDurationMs,
      cellInfoAgeMs: clearCellInfoAge ? null : cellInfoAgeMs ?? p.cellInfoAgeMs,
      locationAgeMs: p.locationAgeMs,
      throughputWindowMs: p.throughputWindowMs,
      rttMethod: p.rttMethod,
    ),
  );
}

void main() {
  test('every representative record satisfies the contract', () {
    for (final s in allSamples) {
      expect(contractViolations(s), isEmpty, reason: '${s.deviceModel} @ ${s.timestampMs}');
    }
    expect(contractViolations(sampleAt(1)), isEmpty);
  });

  test('a fabricated iOS radio value is rejected', () {
    final faked = mutate(iosInCall, rsrp: -100, status: {SampleFieldGroup.radio: FieldStatus.ok});
    expect(contractViolations(faked), contains('iOS radioStatus must be NOT_SUPPORTED'));
  });

  test('a value under a no-value status is rejected (RTT measured but marked NOT_ATTEMPTED)', () {
    final bad = mutate(androidDegraded, rttMs: 90);
    expect(contractViolations(bad).single, startsWith('rttStatus=NOT_ATTEMPTED but 1 value field'));
  });

  test('OK with every value null is rejected - use UNAVAILABLE/TIMEOUT/FAILED instead', () {
    final bad = mutate(androidDegraded, status: {SampleFieldGroup.rtt: FieldStatus.ok});
    expect(contractViolations(bad), anyElement(startsWith('rttStatus=OK but every value field is null')));
  });

  test('STALE needs the age that proves it', () {
    final bad = mutate(androidDegraded, clearCellInfoAge: true);
    expect(contractViolations(bad), contains('radioStatus=STALE needs cellInfoAgeMs'));
  });

  test('STALE is only defined for radio and location', () {
    final bad = mutate(androidFull, status: {SampleFieldGroup.rtt: FieldStatus.stale});
    expect(contractViolations(bad), contains('rttStatus=STALE is not defined for this group'));
  });

  test('capabilitySet must not claim a group the device cannot provide', () {
    final bad = mutate(androidDegraded, capabilitySet: SampleFieldGroup.values.toSet());
    expect(contractViolations(bad), anyElement(contains('LOCATION is in capabilitySet')));
  });

  test('iOS roaming must stay null, and the iOS tier must be IOS_RAT', () {
    expect(contractViolations(mutate(iosInCall, isRoaming: false)), contains(contains('isRoaming')));
    expect(
      contractViolations(mutate(iosInCall, tier: TelemetryCapabilityTier.base26)),
      contains('iOS tier must be IOS_RAT'),
    );
  });

  test('the Android tier must match what the values show (reference resolver rule)', () {
    final bad = mutate(androidFull, tier: TelemetryCapabilityTier.base26);
    expect(contractViolations(bad), contains(startsWith('tier BASE_26 does not match')));
  });

  test('a missing status is rejected', () {
    final s = androidFull;
    final p = s.provenance;
    final missing = TelemetrySample(
      timestampMs: s.timestampMs,
      cqiSupported: false,
      appSessionType: s.appSessionType,
      deviceModel: s.deviceModel,
      androidVersion: s.androidVersion,
      appVersion: s.appVersion,
      telemetryCapabilityTier: TelemetryCapabilityTier.base26,
      platform: s.platform,
      provenance: SampleProvenance(
        fieldStatus: {},
        capabilitySet: {},
        appId: p.appId,
        appBuild: p.appBuild,
        osVersion: p.osVersion,
        utcOffsetMinutes: p.utcOffsetMinutes,
      ),
    );
    expect(contractViolations(missing), hasLength(SampleFieldGroup.values.length));
  });
}

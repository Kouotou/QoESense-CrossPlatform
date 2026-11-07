import 'enums.dart';
import 'telemetry_sample.dart';

/// The executable form of docs/DATA_CONTRACT.md §5 ("status/value consistency"). Returns
/// human-readable violations, or an empty list when the sample is valid.
///
/// Used by the contract tests on every fixture, and in debug builds by the collector
/// (Phase 3) right after a sample is assembled. It is **never** used to drop data in
/// production: a sample that breaks a rule is a bug to fix in the adapter, and the sample
/// is still buffered and uploaded.
List<String> contractViolations(TelemetrySample s) {
  final v = <String>[];
  final p = s.provenance;
  final values = s.groupValues();

  for (final group in SampleFieldGroup.values) {
    final status = p.fieldStatus[group];
    if (status == null) {
      v.add('${group.statusKey} missing');
      continue;
    }
    final present = values[group]!.where((x) => x != null).length;
    if (!status.carriesValue && present > 0) {
      v.add('${group.statusKey}=${status.wireName} but $present value field(s) are non-null');
    }
    if (status.carriesValue && present == 0) {
      v.add('${group.statusKey}=${status.wireName} but every value field is null');
    }
    if (status.isCapabilityGap && p.capabilitySet.contains(group)) {
      v.add('${group.wireName} is in capabilitySet but ${group.statusKey}=${status.wireName}');
    }
  }

  // Staleness is only defined where the OS gives the reading's own timestamp.
  for (final entry in p.fieldStatus.entries.where((e) => e.value == FieldStatus.stale)) {
    switch (entry.key) {
      case SampleFieldGroup.radio:
        if (p.cellInfoAgeMs == null) v.add('radioStatus=STALE needs cellInfoAgeMs');
      case SampleFieldGroup.location:
        if (p.locationAgeMs == null) v.add('locationStatus=STALE needs locationAgeMs');
      default:
        v.add('${entry.key.statusKey}=STALE is not defined for this group');
    }
  }

  // Reference semantics: cqiSupported means "CQI was reported in this sample".
  if (s.cqiSupported != (s.cqi != null)) v.add('cqiSupported must equal (cqi != null)');

  // `== true`: a missing status was already reported above; don't crash on it.
  if (p.fieldStatus[SampleFieldGroup.throughput]?.carriesValue == true && p.throughputWindowMs == null) {
    v.add('a throughput value needs throughputWindowMs');
  }
  if (p.fieldStatus[SampleFieldGroup.rtt]?.carriesValue == true && p.rttMethod == null) {
    v.add('an RTT value needs rttMethod');
  }

  // Platform truths: iOS has no public API for these groups, so nothing may be estimated.
  if (s.platform == ClientPlatform.ios) {
    for (final g in const [
      SampleFieldGroup.radio,
      SampleFieldGroup.cqi,
      SampleFieldGroup.physicalChannel,
      SampleFieldGroup.foregroundApp,
    ]) {
      if (p.fieldStatus[g] != FieldStatus.notSupported) v.add('iOS ${g.statusKey} must be NOT_SUPPORTED');
    }
    if (s.isRoaming != null) v.add('iOS isRoaming must be null (CTCarrier is deprecated)');
    if (s.telemetryCapabilityTier != TelemetryCapabilityTier.iosRat) v.add('iOS tier must be IOS_RAT');
  } else {
    if (s.telemetryCapabilityTier == TelemetryCapabilityTier.iosRat) v.add('IOS_RAT on an Android sample');
    final expected = (s.cellBandwidthKhz ?? s.downlinkChannelNumber ?? s.uplinkChannelNumber) != null
        ? TelemetryCapabilityTier.physchan30
        : s.cqiSupported
        ? TelemetryCapabilityTier.cqi29
        : TelemetryCapabilityTier.base26;
    if (s.telemetryCapabilityTier != expected) {
      v.add('tier ${s.telemetryCapabilityTier.wireName} does not match the values (expected ${expected.wireName})');
    }
  }

  // Units and ranges that are structural, not modem-dependent.
  void nonNegative(String name, int? x) {
    if (x != null && x < 0) v.add('$name must be >= 0');
  }

  nonNegative('throughputBytesPerSecond', s.throughputBytesPerSecond);
  nonNegative('rttMs', s.rttMs);
  nonNegative('captureDurationMs', p.captureDurationMs);
  nonNegative('cellInfoAgeMs', p.cellInfoAgeMs);
  nonNegative('locationAgeMs', p.locationAgeMs);
  nonNegative('throughputWindowMs', p.throughputWindowMs);
  if (s.signalStrengthLevel != null && (s.signalStrengthLevel! < 0 || s.signalStrengthLevel! > 4)) {
    v.add('signalStrengthLevel must be 0-4');
  }
  if (s.latitude != null && (s.latitude!.abs() > 90 || !s.latitude!.isFinite)) v.add('latitude out of range');
  if (s.longitude != null && (s.longitude!.abs() > 180 || !s.longitude!.isFinite)) v.add('longitude out of range');
  if (s.locationAccuracyMeters != null && !(s.locationAccuracyMeters! >= 0)) {
    v.add('locationAccuracyMeters must be >= 0');
  }
  if (p.utcOffsetMinutes.abs() > 14 * 60) v.add('utcOffsetMinutes out of range');
  return v;
}

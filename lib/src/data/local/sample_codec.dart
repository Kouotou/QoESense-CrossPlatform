import 'dart:convert';

import '../../domain/enums.dart';
import '../../domain/telemetry_sample.dart';
import '../upload/batch_serializer.dart';

/// How a buffered sample is stored: its full contract-v2 line, minus `deviceId`, as JSON.
///
/// Storing the contract form instead of one column per field means a new contract field
/// never needs a database migration. (The reference app's Room v1 has 27 columns and no
/// migrations, which is a known risk.) The upload path re-serializes at whatever contract
/// version is configured, so a sample buffered today uploads correctly after a v2 switch-over.
abstract final class SampleCodec {
  static const _v2 = BatchSerializer(version: ContractVersion.v2);

  static String encode(TelemetrySample s) {
    final fields = _v2.lineFields(s, '')..remove('deviceId');
    return jsonEncode(fields);
  }

  static TelemetrySample decode(String json) => fromWire(jsonDecode(json) as Map<String, Object?>);

  /// Rebuilds a sample from a v2 wire map. Throws [FormatException] on a malformed map,
  /// which means corrupt storage: a bug, never silently skipped.
  static TelemetrySample fromWire(Map<String, Object?> m) {
    T req<T>(String k) {
      final v = m[k];
      if (v is! T) throw FormatException('field $k: expected $T, got ${v.runtimeType}');
      return v;
    }

    T? opt<T>(String k) {
      final v = m[k];
      if (v == null) return null;
      if (v is! T) throw FormatException('field $k: expected $T, got ${v.runtimeType}');
      return v as T;
    }

    double? optDouble(String k) => opt<num>(k)?.toDouble();

    E byWire<E extends Enum>(List<E> values, String Function(E) wire, String k) {
      final raw = req<String>(k);
      return values.firstWhere((e) => wire(e) == raw, orElse: () => throw FormatException('field $k: unknown "$raw"'));
    }

    final statuses = <SampleFieldGroup, FieldStatus>{
      for (final g in SampleFieldGroup.values) g: byWire(FieldStatus.values, (s) => s.wireName, g.statusKey),
    };
    final caps = req<List<Object?>>('capabilitySet').cast<String>().toSet();

    return TelemetrySample(
      timestampMs: req<int>('timestampMs'),
      rsrp: opt<int>('rsrp'),
      rsrq: opt<int>('rsrq'),
      rssnr: opt<int>('rssnr'),
      timingAdvance: opt<int>('timingAdvance'),
      networkType: opt<String>('networkType'),
      cellIdentityHash: opt<String>('cellIdentityHash'),
      trackingAreaCode: opt<int>('trackingAreaCode'),
      signalStrengthLevel: opt<int>('signalStrengthLevel'),
      cqi: opt<int>('cqi'),
      cqiSupported: req<bool>('cqiSupported'),
      cellBandwidthKhz: opt<int>('cellBandwidthKhz'),
      downlinkChannelNumber: opt<int>('downlinkChannelNumber'),
      uplinkChannelNumber: opt<int>('uplinkChannelNumber'),
      connectionType: opt<String>('connectionType'),
      isRoaming: opt<bool>('isRoaming'),
      throughputBytesPerSecond: opt<int>('throughputBytesPerSecond'),
      rttMs: opt<int>('rttMs'),
      foregroundAppPackage: opt<String>('foregroundAppPackage'),
      appSessionType: byWire(AppSessionType.values, (e) => e.wireName, 'appSessionType'),
      latitude: optDouble('latitude'),
      longitude: optDouble('longitude'),
      locationAccuracyMeters: optDouble('locationAccuracyMeters'),
      deviceModel: req<String>('deviceModel'),
      androidVersion: req<int>('androidVersion'),
      appVersion: req<String>('appVersion'),
      telemetryCapabilityTier: byWire(TelemetryCapabilityTier.values, (e) => e.wireName, 'telemetryCapabilityTier'),
      platform: byWire(ClientPlatform.values, (e) => e.wireName, 'platform'),
      provenance: SampleProvenance(
        fieldStatus: statuses,
        capabilitySet: {
          for (final g in SampleFieldGroup.values)
            if (caps.contains(g.wireName)) g,
        },
        appId: req<String>('appId'),
        appBuild: req<int>('appBuild'),
        osVersion: req<String>('osVersion'),
        utcOffsetMinutes: req<int>('utcOffsetMinutes'),
        captureDurationMs: opt<int>('captureDurationMs'),
        cellInfoAgeMs: opt<int>('cellInfoAgeMs'),
        locationAgeMs: opt<int>('locationAgeMs'),
        throughputWindowMs: opt<int>('throughputWindowMs'),
        rttMethod: opt<String>('rttMethod'),
      ),
    );
  }
}

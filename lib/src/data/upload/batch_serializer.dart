import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:typed_data';

import '../../domain/enums.dart';
import '../../domain/telemetry_sample.dart';

/// Produces the exact bytes uploaded to Cloud Storage: NDJSON (one object per line, `\n`
/// separated, no trailing newline), UTF-8, gzip.
///
/// - **v1** is byte-for-byte the reference app's line: 27 fields, explicit nulls, then `deviceId`.
/// - **v2** is the v1 line followed by the contract-v2 block (DATA_CONTRACT §4). It must
///   only be sent after the v2 functions are deployed, because the deployed load job uses
///   `ignoreUnknownValues:false` and an unknown key fails the whole batch.
class BatchSerializer {
  const BatchSerializer({this.version = defaultVersion});

  /// **Stays v1 until the v2 functions deploy is confirmed.** A contract test pins this.
  static const ContractVersion defaultVersion = ContractVersion.v1;

  final ContractVersion version;

  String toNdjson(List<TelemetrySample> samples, String deviceId) =>
      samples.map((s) => jsonEncode(lineFields(s, deviceId))).join('\n');

  Uint8List toGzippedNdjson(List<TelemetrySample> samples, String deviceId) =>
      Uint8List.fromList(gzip.encode(utf8.encode(toNdjson(samples, deviceId))));

  Map<String, Object?> lineFields(TelemetrySample sample, String deviceId) => <String, Object?>{
    ...sample.toV1Fields(),
    'deviceId': deviceId,
    if (version == ContractVersion.v2) ..._v2Block(sample),
  };

  static Map<String, Object?> _v2Block(TelemetrySample s) {
    final p = s.provenance;
    return <String, Object?>{
      'schemaVersion': ContractVersion.v2.number,
      'platform': s.platform.wireName,
      for (final g in SampleFieldGroup.values) g.statusKey: p.statusOf(g).wireName,
      // Enum order, so identical sets always serialize identically.
      'capabilitySet': [
        for (final g in SampleFieldGroup.values)
          if (p.capabilitySet.contains(g)) g.wireName,
      ],
      'appId': p.appId,
      'appBuild': p.appBuild,
      'osVersion': p.osVersion,
      'utcOffsetMinutes': p.utcOffsetMinutes,
      'captureDurationMs': p.captureDurationMs,
      'cellInfoAgeMs': p.cellInfoAgeMs,
      'locationAgeMs': p.locationAgeMs,
      'throughputWindowMs': p.throughputWindowMs,
      'rttMethod': p.rttMethod,
    };
  }
}

/// `telemetry/{uid}/{yyyy-MM-dd}/{batchId}.json.gz`, the same for every contract version.
/// The date is the device's local date at upload time, as in the reference app
/// (SimpleDateFormat with the default zone).
String telemetryObjectPath({required String deviceId, required DateTime localNow, required String batchId}) {
  String two(int v) => v.toString().padLeft(2, '0');
  final date = '${localNow.year.toString().padLeft(4, '0')}-${two(localNow.month)}-${two(localNow.day)}';
  return 'telemetry/$deviceId/$date/$batchId.json.gz';
}

import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:typed_data';

import '../../domain/telemetry_sample.dart';

/// Produces the exact bytes uploaded to Cloud Storage: NDJSON (one object per line, `\n`
/// separated, no trailing newline), UTF-8, gzip - byte-for-byte the reference app's
/// `BatchSerializer` line format (field order, explicit nulls, `deviceId` appended).
class BatchSerializer {
  const BatchSerializer({this.emitPlatformField = defaultEmitPlatformField});

  /// **Must stay false until the `platform` column's functions deploy is confirmed.** The
  /// deployed loadTelemetryBatch uses ignoreUnknownValues:false - an unknown key fails the
  /// whole batch. See docs/DATA_CONTRACT.md section 2; a contract test pins this default.
  static const bool defaultEmitPlatformField = false;

  final bool emitPlatformField;

  String toNdjson(List<TelemetrySample> samples, String deviceId) =>
      samples.map((s) => jsonEncode(lineFields(s, deviceId))).join('\n');

  Uint8List toGzippedNdjson(List<TelemetrySample> samples, String deviceId) =>
      Uint8List.fromList(gzip.encode(utf8.encode(toNdjson(samples, deviceId))));

  Map<String, Object?> lineFields(TelemetrySample sample, String deviceId) => <String, Object?>{
    ...sample.toWireFields(),
    'deviceId': deviceId,
    if (emitPlatformField) 'platform': sample.platform.wireName,
  };
}

/// `telemetry/{uid}/{yyyy-MM-dd}/{batchId}.json.gz` - the date is the device's local date at
/// upload time, as in the reference app (SimpleDateFormat with the default zone).
String telemetryObjectPath({required String deviceId, required DateTime localNow, required String batchId}) {
  String two(int v) => v.toString().padLeft(2, '0');
  final date = '${localNow.year.toString().padLeft(4, '0')}-${two(localNow.month)}-${two(localNow.day)}';
  return 'telemetry/$deviceId/$date/$batchId.json.gz';
}

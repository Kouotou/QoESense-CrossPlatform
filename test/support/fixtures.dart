import 'dart:convert';
import 'dart:io';

import 'package:qoesense/src/domain/enums.dart';
import 'package:qoesense/src/domain/telemetry_sample.dart';

/// An Android sample with every BASE_26/CQI_29 field populated.
const androidSample = TelemetrySample(
  timestampMs: 1762500000000,
  rsrp: -95,
  rsrq: -11,
  rssnr: 12,
  timingAdvance: 3,
  networkType: 'LTE',
  cellIdentityHash: 'a1b2c3d4e5f60718',
  trackingAreaCode: 12345,
  signalStrengthLevel: 3,
  cqi: 9,
  cqiSupported: true,
  connectionType: 'CELLULAR',
  isRoaming: false,
  throughputBytesPerSecond: 20480,
  rttMs: 84,
  foregroundAppPackage: 'com.whatsapp',
  appSessionType: AppSessionType.socialMedia,
  latitude: 4.0511,
  longitude: 9.7679,
  locationAccuracyMeters: 12.5,
  deviceModel: 'SM-A155F',
  androidVersion: 34,
  appVersion: '2.0.0',
  telemetryCapabilityTier: TelemetryCapabilityTier.cqi29,
  platform: ClientPlatform.android,
);

/// An iOS sample: everything iOS can't measure is null, never estimated.
const iosSample = TelemetrySample(
  timestampMs: 1762500060000,
  networkType: 'NR',
  cqiSupported: false,
  connectionType: 'WIFI',
  appSessionType: AppSessionType.videoConferencing,
  deviceModel: 'iPhone14,5',
  androidVersion: 18,
  appVersion: '2.0.0',
  telemetryCapabilityTier: TelemetryCapabilityTier.iosRat,
  platform: ClientPlatform.ios,
);

TelemetrySample sampleAt(int timestampMs) => TelemetrySample(
  timestampMs: timestampMs,
  cqiSupported: false,
  appSessionType: AppSessionType.none,
  deviceModel: 'test',
  androidVersion: 34,
  appVersion: '2.0.0',
  telemetryCapabilityTier: TelemetryCapabilityTier.base26,
  platform: ClientPlatform.android,
);

/// `flutter test` runs with the package root as the working directory.
String readRepoFile(String path) => File(path).readAsStringSync().replaceAll('\r\n', '\n');

class SchemaField {
  SchemaField(this.name, this.type, this.mode);
  final String name;
  final String type;
  final String mode;
  bool get required => mode == 'REQUIRED';
}

List<SchemaField> loadSchema(String path) {
  final json = jsonDecode(readRepoFile(path)) as Map<String, Object?>;
  return [
    for (final f in (json['fields']! as List<Object?>).cast<Map<String, Object?>>())
      SchemaField(f['name']! as String, f['type']! as String, f['mode']! as String),
  ];
}

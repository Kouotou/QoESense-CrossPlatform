import 'dart:convert';
import 'dart:io';

import 'package:qoesense/src/domain/enums.dart';
import 'package:qoesense/src/domain/mos_response.dart';
import 'package:qoesense/src/domain/telemetry_sample.dart';

// Representative records for the contract tests and for docs/DATA_CONTRACT.md §9.
// Android values are plausible reference-app readings. iOS records carry NO radio values:
// iOS has no public API for them, so they are null with status NOT_SUPPORTED, never
// estimated.

const _appId = 'io.github.kouotou.qoesense';
const _rtt = SampleProvenance.rttMethodDartGenerate204;

Map<SampleFieldGroup, FieldStatus> statuses({
  required FieldStatus radio,
  required FieldStatus cqi,
  required FieldStatus physicalChannel,
  required FieldStatus networkType,
  required FieldStatus connectivity,
  required FieldStatus throughput,
  required FieldStatus rtt,
  required FieldStatus foregroundApp,
  required FieldStatus location,
}) => {
  SampleFieldGroup.radio: radio,
  SampleFieldGroup.cqi: cqi,
  SampleFieldGroup.physicalChannel: physicalChannel,
  SampleFieldGroup.networkType: networkType,
  SampleFieldGroup.connectivity: connectivity,
  SampleFieldGroup.throughput: throughput,
  SampleFieldGroup.rtt: rtt,
  SampleFieldGroup.foregroundApp: foregroundApp,
  SampleFieldGroup.location: location,
};

Set<SampleFieldGroup> capabilitiesFrom(Map<SampleFieldGroup, FieldStatus> s) => {
  for (final e in s.entries)
    if (!e.value.isCapabilityGap) e.key,
};

/// A1. Android, everything measured. A WhatsApp session, RTT tick, CQI reported.
/// PhysicalChannelConfig is RESTRICTED, since no participant device has carrier privileges.
final androidFull = () {
  final s = statuses(
    radio: FieldStatus.ok,
    cqi: FieldStatus.ok,
    physicalChannel: FieldStatus.restricted,
    networkType: FieldStatus.ok,
    connectivity: FieldStatus.ok,
    throughput: FieldStatus.ok,
    rtt: FieldStatus.ok,
    foregroundApp: FieldStatus.ok,
    location: FieldStatus.ok,
  );
  return TelemetrySample(
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
    provenance: SampleProvenance(
      fieldStatus: s,
      capabilitySet: capabilitiesFrom(s),
      appId: _appId,
      appBuild: 1,
      osVersion: '14',
      utcOffsetMinutes: 60,
      captureDurationMs: 2310,
      cellInfoAgeMs: 850,
      locationAgeMs: 1200,
      throughputWindowMs: 60000,
      rttMethod: _rtt,
    ),
  );
}();

/// A2. Android, degraded but honest. The modem returned a cached CellInfo 95 s old - older than the
/// 60 s interval, so STALE (
/// values kept). Location permission was revoked. There's no usage access, so the foreground
/// app is unknown. This is the first sample after a restart, so there's no throughput baseline.
/// At rest, and not an RTT tick.
final androidDegraded = () {
  final s = statuses(
    radio: FieldStatus.stale,
    cqi: FieldStatus.unavailable,
    physicalChannel: FieldStatus.restricted,
    networkType: FieldStatus.ok,
    connectivity: FieldStatus.ok,
    throughput: FieldStatus.unavailable,
    rtt: FieldStatus.notAttempted,
    foregroundApp: FieldStatus.permissionDenied,
    location: FieldStatus.permissionDenied,
  );
  return TelemetrySample(
    timestampMs: 1762500060000,
    rsrp: -112,
    rsrq: -15,
    rssnr: -2,
    networkType: 'LTE',
    cellIdentityHash: '0f9e8d7c6b5a4938',
    trackingAreaCode: 12345,
    signalStrengthLevel: 1,
    cqiSupported: false,
    connectionType: 'CELLULAR',
    isRoaming: false,
    appSessionType: AppSessionType.none,
    deviceModel: 'TECNO KI5k',
    androidVersion: 33,
    appVersion: '2.0.0',
    telemetryCapabilityTier: TelemetryCapabilityTier.base26,
    platform: ClientPlatform.android,
    provenance: SampleProvenance(
      fieldStatus: s,
      capabilitySet: capabilitiesFrom(s),
      appId: _appId,
      appBuild: 1,
      osVersion: '13',
      utcOffsetMinutes: 60,
      captureDurationMs: 140,
      cellInfoAgeMs: 95000,
    ),
  );
}();

/// I1. iOS, during a CallKit-detected call (counted as VIDEO_CONFERENCING, decision D-4),
/// so RTT is measured every tick. Radio, CQI, physical channel and foreground app are
/// NOT_SUPPORTED. Roaming is null, since CTCarrier is deprecated.
final iosInCall = () {
  final s = statuses(
    radio: FieldStatus.notSupported,
    cqi: FieldStatus.notSupported,
    physicalChannel: FieldStatus.notSupported,
    networkType: FieldStatus.ok,
    connectivity: FieldStatus.ok,
    throughput: FieldStatus.ok,
    rtt: FieldStatus.ok,
    foregroundApp: FieldStatus.notSupported,
    location: FieldStatus.ok,
  );
  return TelemetrySample(
    timestampMs: 1762500075000,
    networkType: 'LTE',
    cqiSupported: false,
    connectionType: 'CELLULAR',
    throughputBytesPerSecond: 98304,
    rttMs: 131,
    appSessionType: AppSessionType.videoConferencing,
    latitude: 3.848,
    longitude: 11.5021,
    locationAccuracyMeters: 65.0,
    deviceModel: 'iPhone14,5',
    androidVersion: 18,
    appVersion: '2.0.0',
    telemetryCapabilityTier: TelemetryCapabilityTier.iosRat,
    platform: ClientPlatform.ios,
    provenance: SampleProvenance(
      fieldStatus: s,
      capabilitySet: capabilitiesFrom(s),
      appId: _appId,
      appBuild: 1,
      osVersion: '18.1',
      utcOffsetMinutes: 60,
      captureDurationMs: 4020,
      locationAgeMs: 3100,
      throughputWindowMs: 15000,
      rttMethod: _rtt,
    ),
  );
}();

/// I2. iOS on Wi-Fi, with location only "When In Use", so it's denied in the background.
/// The RTT probe failed, and there's no throughput baseline yet. networkType "NR" is the
/// cellular RAT reported while Wi-Fi carries the data.
final iosOnWifi = () {
  final s = statuses(
    radio: FieldStatus.notSupported,
    cqi: FieldStatus.notSupported,
    physicalChannel: FieldStatus.notSupported,
    networkType: FieldStatus.ok,
    connectivity: FieldStatus.ok,
    throughput: FieldStatus.unavailable,
    rtt: FieldStatus.failed,
    foregroundApp: FieldStatus.notSupported,
    location: FieldStatus.permissionDenied,
  );
  return TelemetrySample(
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
    provenance: SampleProvenance(
      fieldStatus: s,
      capabilitySet: capabilitiesFrom(s),
      appId: _appId,
      appBuild: 1,
      osVersion: '18.1',
      utcOffsetMinutes: 60,
      captureDurationMs: 4005,
    ),
  );
}();

/// The two records whose v1 lines are pinned by contracts/fixtures/batch_v1.ndjson.
final androidSample = androidFull;
final iosSample = iosOnWifi;

final allSamples = [androidFull, androidDegraded, iosInCall, iosOnWifi];

/// A minimal valid Android sample at [timestampMs], for buffer/upload tests.
TelemetrySample sampleAt(int timestampMs) {
  final s = statuses(
    radio: FieldStatus.unavailable,
    cqi: FieldStatus.unavailable,
    physicalChannel: FieldStatus.restricted,
    networkType: FieldStatus.unavailable,
    connectivity: FieldStatus.unavailable,
    throughput: FieldStatus.unavailable,
    rtt: FieldStatus.notAttempted,
    foregroundApp: FieldStatus.permissionDenied,
    location: FieldStatus.permissionDenied,
  );
  return TelemetrySample(
    timestampMs: timestampMs,
    cqiSupported: false,
    appSessionType: AppSessionType.none,
    deviceModel: 'test',
    androidVersion: 34,
    appVersion: '2.0.0',
    telemetryCapabilityTier: TelemetryCapabilityTier.base26,
    platform: ClientPlatform.android,
    provenance: SampleProvenance(
      fieldStatus: s,
      capabilitySet: capabilitiesFrom(s),
      appId: _appId,
      appBuild: 1,
      osVersion: '14',
      utcOffsetMinutes: 60,
    ),
  );
}

/// M1. Android overlay rating, context observed from usage stats.
final mosAndroidOverlay = MosResponse.forTap(
  responseId: '3f2a9c1e-7b4d-4e5f-9a8b-0c1d2e3f4a5b',
  score: 2,
  tapMs: 1762500120000,
  triggerType: MosTriggerType.anomaly,
  contextAppPackage: 'com.whatsapp',
  contextSessionType: AppSessionType.socialMedia,
  platform: ClientPlatform.android,
  contextSource: ContextSource.observed,
  presentationMode: PresentationMode.overlay,
  appId: _appId,
  appVersion: '2.0.0',
  appBuild: 1,
  utcOffsetMinutes: 60,
  promptedAtMs: 1762500114000,
);

/// M2. iOS rating from the notification's action buttons. The participant answered
/// "WhatsApp call", which maps to the Android package name (decision D-6).
final mosIosSelfReported = MosResponse.forTap(
  responseId: '8c7b6a59-4d3e-4f2a-b1c0-9d8e7f6a5b4c',
  score: 4,
  tapMs: 1762500300000,
  triggerType: MosTriggerType.postSession,
  contextAppPackage: 'com.whatsapp',
  contextSessionType: AppSessionType.videoConferencing,
  platform: ClientPlatform.ios,
  contextSource: ContextSource.selfReported,
  presentationMode: PresentationMode.notificationAction,
  appId: _appId,
  appVersion: '2.0.0',
  appBuild: 1,
  utcOffsetMinutes: 60,
  promptedAtMs: 1762500250000,
);

/// M3. iOS rating where the self-report question was skipped.
final mosIosUnknownContext = MosResponse.forTap(
  responseId: '1a2b3c4d-5e6f-4a7b-8c9d-0e1f2a3b4c5d',
  score: 5,
  tapMs: 1762500600000,
  triggerType: MosTriggerType.periodic,
  contextAppPackage: null,
  contextSessionType: AppSessionType.none,
  platform: ClientPlatform.ios,
  contextSource: ContextSource.unknown,
  presentationMode: PresentationMode.notification,
  appId: _appId,
  appVersion: '2.0.0',
  appBuild: 1,
  utcOffsetMinutes: 60,
  promptedAtMs: 1762500500000,
);

final allMos = [mosAndroidOverlay, mosIosSelfReported, mosIosUnknownContext];

/// `flutter test` runs with the package root as the working directory.
String readRepoFile(String path) => File(path).readAsStringSync().replaceAll('\r\n', '\n');

class SchemaField {
  SchemaField(this.name, this.type, this.mode);
  final String name;
  final String type;
  final String mode;
  bool get required => mode == 'REQUIRED';
  bool get repeated => mode == 'REPEATED';
}

List<SchemaField> loadSchema(String path) {
  final json = jsonDecode(readRepoFile(path)) as Map<String, Object?>;
  return [
    for (final f in (json['fields']! as List<Object?>).cast<Map<String, Object?>>())
      SchemaField(f['name']! as String, f['type']! as String, f['mode']! as String),
  ];
}

/// Whether a decoded JSON value fits a BigQuery column (null always fits a non-REQUIRED one).
bool fitsColumn(SchemaField f, Object? value) {
  if (value == null) return !f.required;
  if (f.repeated) return value is List && value.every((e) => fitsScalar(f.type, e));
  return fitsScalar(f.type, value);
}

bool fitsScalar(String type, Object? value) => switch (type) {
  'INTEGER' => value is int,
  'FLOAT' => value is num,
  'BOOLEAN' => value is bool,
  'STRING' => value is String,
  _ => false,
};

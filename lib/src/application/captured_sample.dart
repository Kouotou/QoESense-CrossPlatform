import '../domain/enums.dart';
import '../domain/telemetry_sample.dart';
import 'capability_tier_resolver.dart';

/// Everything one native capture call returns: the whole sample except RTT, which is
/// measured by shared Dart code concurrently with the native location wait. One channel call
/// per tick; Flutter never calls native code per measurement.
class CapturedSample {
  const CapturedSample({
    required this.platform,
    this.rsrp,
    this.rsrq,
    this.rssnr,
    this.timingAdvance,
    this.cellIdentityHash,
    this.trackingAreaCode,
    this.signalStrengthLevel,
    required this.radioStatus,
    this.cellInfoAgeMs,
    this.cqi,
    required this.cqiStatus,
    this.cellBandwidthKhz,
    this.downlinkChannelNumber,
    this.uplinkChannelNumber,
    required this.physicalChannelStatus,
    this.networkType,
    required this.networkTypeStatus,
    this.connectionType,
    this.isRoaming,
    required this.connectivityStatus,
    this.throughputBytesPerSecond,
    this.throughputWindowMs,
    required this.throughputStatus,
    this.foregroundAppPackage,
    required this.appSessionType,
    required this.foregroundAppStatus,
    this.latitude,
    this.longitude,
    this.locationAccuracyMeters,
    this.locationAgeMs,
    required this.locationStatus,
    required this.capabilitySet,
    required this.app,
  });

  final ClientPlatform platform;
  final int? rsrp, rsrq, rssnr, timingAdvance, trackingAreaCode, signalStrengthLevel;
  final String? cellIdentityHash;
  final FieldStatus radioStatus;
  final int? cellInfoAgeMs;
  final int? cqi;
  final FieldStatus cqiStatus;
  final int? cellBandwidthKhz, downlinkChannelNumber, uplinkChannelNumber;
  final FieldStatus physicalChannelStatus;
  final String? networkType;
  final FieldStatus networkTypeStatus;
  final String? connectionType;
  final bool? isRoaming;
  final FieldStatus connectivityStatus;
  final int? throughputBytesPerSecond, throughputWindowMs;
  final FieldStatus throughputStatus;
  final String? foregroundAppPackage;
  final AppSessionType appSessionType;
  final FieldStatus foregroundAppStatus;
  final double? latitude, longitude, locationAccuracyMeters;
  final int? locationAgeMs;
  final FieldStatus locationStatus;

  /// Field groups this device could provide right now (supported + permitted + not restricted),
  /// excluding RTT, which is always possible.
  final Set<SampleFieldGroup> capabilitySet;
  final AppInfo app;
}

/// App and device identity, reported by native code.
class AppInfo {
  const AppInfo({
    required this.deviceModel,
    required this.osMajorVersion,
    required this.osVersion,
    required this.appId,
    required this.appVersion,
    required this.appBuild,
  });
  final String deviceModel;

  /// SDK_INT on Android, the iOS major version on iOS (D-5).
  final int osMajorVersion;
  final String osVersion;
  final String appId;
  final String appVersion;
  final int appBuild;
}

/// AppInfo <-> a flat string map, for storing it in a KeyValueStore.
Map<String, String> appInfoToMap(AppInfo a) => {
  'deviceModel': a.deviceModel,
  'osMajorVersion': '${a.osMajorVersion}',
  'osVersion': a.osVersion,
  'appId': a.appId,
  'appVersion': a.appVersion,
  'appBuild': '${a.appBuild}',
};

AppInfo? appInfoFromMap(Map<String, String?> m) {
  final major = int.tryParse(m['osMajorVersion'] ?? '');
  final build = int.tryParse(m['appBuild'] ?? '');
  final model = m['deviceModel'], os = m['osVersion'], id = m['appId'], version = m['appVersion'];
  if (major == null || build == null || model == null || os == null || id == null || version == null) return null;
  return AppInfo(
    deviceModel: model,
    osMajorVersion: major,
    osVersion: os,
    appId: id,
    appVersion: version,
    appBuild: build,
  );
}

/// Shared RTT probe result.
class RttResult {
  const RttResult(this.status, [this.ms]);
  const RttResult.notAttempted() : status = FieldStatus.notAttempted, ms = null;
  final FieldStatus status;
  final int? ms;
}

/// Builds the contract-v2 sample from one capture + the RTT result. Pure, and covered by
/// the mapping regression tests.
TelemetrySample assembleSample({
  required CapturedSample c,
  required RttResult rtt,
  required String? rttMethod,
  required int timestampMs,
  required int captureDurationMs,
  required int utcOffsetMinutes,
}) {
  final cqiSupported = c.cqi != null;
  final statuses = <SampleFieldGroup, FieldStatus>{
    SampleFieldGroup.radio: c.radioStatus,
    SampleFieldGroup.cqi: c.cqiStatus,
    SampleFieldGroup.physicalChannel: c.physicalChannelStatus,
    SampleFieldGroup.networkType: c.networkTypeStatus,
    SampleFieldGroup.connectivity: c.connectivityStatus,
    SampleFieldGroup.throughput: c.throughputStatus,
    SampleFieldGroup.rtt: rtt.status,
    SampleFieldGroup.foregroundApp: c.foregroundAppStatus,
    SampleFieldGroup.location: c.locationStatus,
  };
  return TelemetrySample(
    timestampMs: timestampMs,
    rsrp: c.rsrp,
    rsrq: c.rsrq,
    rssnr: c.rssnr,
    timingAdvance: c.timingAdvance,
    networkType: c.networkType,
    cellIdentityHash: c.cellIdentityHash,
    trackingAreaCode: c.trackingAreaCode,
    signalStrengthLevel: c.signalStrengthLevel,
    cqi: c.cqi,
    cqiSupported: cqiSupported,
    cellBandwidthKhz: c.cellBandwidthKhz,
    downlinkChannelNumber: c.downlinkChannelNumber,
    uplinkChannelNumber: c.uplinkChannelNumber,
    connectionType: c.connectionType,
    isRoaming: c.isRoaming,
    throughputBytesPerSecond: c.throughputBytesPerSecond,
    rttMs: rtt.ms,
    foregroundAppPackage: c.foregroundAppPackage,
    appSessionType: c.appSessionType,
    latitude: c.latitude,
    longitude: c.longitude,
    locationAccuracyMeters: c.locationAccuracyMeters,
    deviceModel: c.app.deviceModel,
    androidVersion: c.app.osMajorVersion,
    appVersion: c.app.appVersion,
    telemetryCapabilityTier: CapabilityTierResolver.resolve(
      platform: c.platform,
      cqiSupported: cqiSupported,
      cellBandwidthKhz: c.cellBandwidthKhz,
      downlinkChannelNumber: c.downlinkChannelNumber,
      uplinkChannelNumber: c.uplinkChannelNumber,
    ),
    platform: c.platform,
    provenance: SampleProvenance(
      fieldStatus: statuses,
      // Enforced here rather than trusted from native: a group whose status says the device
      // can't provide it is never in capabilitySet (DATA_CONTRACT §5).
      capabilitySet: {
        for (final g in {...c.capabilitySet, SampleFieldGroup.rtt})
          if (!statuses[g]!.isCapabilityGap) g,
      },
      appId: c.app.appId,
      appBuild: c.app.appBuild,
      osVersion: c.app.osVersion,
      utcOffsetMinutes: utcOffsetMinutes,
      captureDurationMs: captureDurationMs,
      cellInfoAgeMs: c.cellInfoAgeMs,
      locationAgeMs: c.locationAgeMs,
      throughputWindowMs: c.throughputWindowMs,
      rttMethod: rtt.status.carriesValue ? rttMethod : null,
    ),
  );
}

import 'enums.dart';

/// One capture tick's worth of telemetry - the cross-platform equivalent of the reference
/// app's `TelemetrySample` (../QoESense data/model/TelemetrySample.kt), field for field.
///
/// Every field beyond the required identifiers is nullable by design: null means "not
/// available on this device / platform / permission state", never a failed capture. A
/// partial sample is still written, not dropped.
class TelemetrySample {
  const TelemetrySample({
    required this.timestampMs,
    this.rsrp,
    this.rsrq,
    this.rssnr,
    this.timingAdvance,
    this.networkType,
    this.cellIdentityHash,
    this.trackingAreaCode,
    this.signalStrengthLevel,
    this.cqi,
    required this.cqiSupported,
    this.cellBandwidthKhz,
    this.downlinkChannelNumber,
    this.uplinkChannelNumber,
    this.connectionType,
    this.isRoaming,
    this.throughputBytesPerSecond,
    this.rttMs,
    this.foregroundAppPackage,
    required this.appSessionType,
    this.latitude,
    this.longitude,
    this.locationAccuracyMeters,
    required this.deviceModel,
    required this.androidVersion,
    required this.appVersion,
    required this.telemetryCapabilityTier,
    required this.platform,
  });

  final int timestampMs;

  // Cellular - BASE_26 tier (Android only; always null on iOS).
  final int? rsrp;
  final int? rsrq;
  final int? rssnr;
  final int? timingAdvance;
  final String? networkType;
  final String? cellIdentityHash;
  final int? trackingAreaCode;
  final int? signalStrengthLevel;

  // Cellular - CQI_29 tier.
  final int? cqi;
  final bool cqiSupported;

  // Cellular - PHYSCHAN_30 tier.
  final int? cellBandwidthKhz;
  final int? downlinkChannelNumber;
  final int? uplinkChannelNumber;

  // Connectivity.
  final String? connectionType;
  final bool? isRoaming;
  final int? throughputBytesPerSecond;
  final int? rttMs;

  // App/session context.
  final String? foregroundAppPackage;
  final AppSessionType appSessionType;

  // Location.
  final double? latitude;
  final double? longitude;
  final double? locationAccuracyMeters;

  // Device. `androidVersion` carries the iOS major version on iOS (decision D-5).
  final String deviceModel;
  final int androidVersion;
  final String appVersion;
  final TelemetryCapabilityTier telemetryCapabilityTier;

  /// Always known on the client. Whether it is *sent* is the serializer's decision - see
  /// BatchSerializer.emitPlatformField and DATA_CONTRACT section 2.
  final ClientPlatform platform;

  /// The sample's own wire fields in contract order (DATA_CONTRACT section 2, rows 1-27).
  /// Nulls are explicit. `deviceId` and `platform` are appended by the serializer.
  Map<String, Object?> toWireFields() => <String, Object?>{
    'timestampMs': timestampMs,
    'rsrp': rsrp,
    'rsrq': rsrq,
    'rssnr': rssnr,
    'timingAdvance': timingAdvance,
    'networkType': networkType,
    'cellIdentityHash': cellIdentityHash,
    'trackingAreaCode': trackingAreaCode,
    'signalStrengthLevel': signalStrengthLevel,
    'cqi': cqi,
    'cqiSupported': cqiSupported,
    'cellBandwidthKhz': cellBandwidthKhz,
    'downlinkChannelNumber': downlinkChannelNumber,
    'uplinkChannelNumber': uplinkChannelNumber,
    'connectionType': connectionType,
    'isRoaming': isRoaming,
    'throughputBytesPerSecond': throughputBytesPerSecond,
    'rttMs': rttMs,
    'foregroundAppPackage': foregroundAppPackage,
    'appSessionType': appSessionType.wireName,
    'latitude': latitude,
    'longitude': longitude,
    'locationAccuracyMeters': locationAccuracyMeters,
    'deviceModel': deviceModel,
    'androidVersion': androidVersion,
    'appVersion': appVersion,
    'telemetryCapabilityTier': telemetryCapabilityTier.wireName,
  };
}

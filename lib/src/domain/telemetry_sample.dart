import 'enums.dart';

/// One capture tick's worth of telemetry - the cross-platform equivalent of the reference
/// app's `TelemetrySample` (../QoESense data/model/TelemetrySample.kt). The first 27 fields
/// are the reference fields, unchanged in name, unit and meaning (docs/DATA_CONTRACT.md §3).
/// The [provenance] block is the contract-v2 addition (§4).
///
/// A null value never stands for a "failed capture" by itself. The reason a value is
/// missing lives in [SampleProvenance.fieldStatus]. A partial sample is still written,
/// never dropped. All of these are raw observations: derived features and predictions never
/// travel in a sample (§6).
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
    required this.provenance,
  });

  /// Wall clock (Unix epoch ms, UTC) when the capture *completed*, as in the reference app.
  final int timestampMs;

  // Cellular, BASE_26 tier: the serving (registered) LTE cell. Always null on iOS.
  /// dBm.
  final int? rsrp;

  /// dB.
  final int? rsrq;

  /// dB.
  final int? rssnr;

  /// LTE timing-advance units, as reported by the modem.
  final int? timingAdvance;

  /// "LTE", "NR", "UNKNOWN" or "OTHER".
  final String? networkType;

  /// First 16 hex characters of SHA-256 of "{ci}:{tac}". The raw cell ID never leaves the device.
  final String? cellIdentityHash;
  final int? trackingAreaCode;

  /// OS signal bars, 0-4.
  final int? signalStrengthLevel;

  // Cellular, CQI_29 tier.
  /// 0-15.
  final int? cqi;

  /// True when CQI was reported *in this sample* - not whether the device can report it.
  final bool cqiSupported;

  // Cellular, PHYSCHAN_30 tier.
  final int? cellBandwidthKhz;

  /// EARFCN.
  final int? downlinkChannelNumber;

  /// EARFCN.
  final int? uplinkChannelNumber;

  // Connectivity.
  /// "WIFI", "CELLULAR" or "OTHER".
  final String? connectionType;
  final bool? isRoaming;

  /// Device-wide rx+tx bytes per second, averaged since the previous capture.
  final int? throughputBytesPerSecond;

  /// Milliseconds for one HTTPS GET of generate_204 on a fresh connection (DNS + TCP + TLS +
  /// request). This is not an ICMP RTT. See [SampleProvenance.rttMethod].
  final int? rttMs;

  // App/session context.
  final String? foregroundAppPackage;
  final AppSessionType appSessionType;

  // Location.
  /// WGS84 degrees.
  final double? latitude;

  /// WGS84 degrees.
  final double? longitude;

  /// Metres, 68% radius.
  final double? locationAccuracyMeters;

  // Device. On iOS, androidVersion holds the iOS major version (decision D-5).
  final String deviceModel;
  final int androidVersion;
  final String appVersion;
  final TelemetryCapabilityTier telemetryCapabilityTier;

  final ClientPlatform platform;

  /// Contract-v2 metadata. It always exists on the client; the serializer decides whether
  /// it's sent.
  final SampleProvenance provenance;

  /// The 27 reference fields in contract order (DATA_CONTRACT §3), with explicit nulls.
  Map<String, Object?> toV1Fields() => <String, Object?>{
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

  /// The value fields of each status group. The contract checks use this to verify that a
  /// group whose status carries no value really has null values.
  Map<SampleFieldGroup, List<Object?>> groupValues() => {
    SampleFieldGroup.radio: [rsrp, rsrq, rssnr, timingAdvance, cellIdentityHash, trackingAreaCode, signalStrengthLevel],
    SampleFieldGroup.cqi: [cqi],
    SampleFieldGroup.physicalChannel: [cellBandwidthKhz, downlinkChannelNumber, uplinkChannelNumber],
    SampleFieldGroup.networkType: [networkType],
    SampleFieldGroup.connectivity: [connectionType, isRoaming],
    SampleFieldGroup.throughput: [throughputBytesPerSecond],
    SampleFieldGroup.rtt: [rttMs],
    SampleFieldGroup.foregroundApp: [foregroundAppPackage],
    SampleFieldGroup.location: [latitude, longitude, locationAccuracyMeters],
  };
}

/// Contract-v2 metadata that tells sources apart and qualifies each measurement
/// (DATA_CONTRACT §4). Every key is a nullable column in BigQuery. v1 rows have NULL here.
class SampleProvenance {
  const SampleProvenance({
    required this.fieldStatus,
    required this.capabilitySet,
    required this.appId,
    required this.appBuild,
    required this.osVersion,
    required this.utcOffsetMinutes,
    this.captureDurationMs,
    this.cellInfoAgeMs,
    this.locationAgeMs,
    this.throughputWindowMs,
    this.rttMethod,
  });

  /// One status per [SampleFieldGroup]. All nine are required in v2.
  final Map<SampleFieldGroup, FieldStatus> fieldStatus;

  /// Groups this device could provide at capture time: supported, permitted and not
  /// restricted. This is independent of whether this tick actually measured them.
  final Set<SampleFieldGroup> capabilitySet;

  /// Application / bundle ID, e.g. "io.github.kouotou.qoesense". It separates the new app's
  /// rows from the reference app's rows (com.example.qoesense) during the D-1 handover.
  final String appId;

  /// versionCode / CFBundleVersion. appVersion stays the human-readable version.
  final int appBuild;

  /// Full OS version string: Build.VERSION.RELEASE ("14") or the iOS version ("18.1").
  final String osVersion;

  /// Local UTC offset at capture, in minutes (e.g. +60 in Cameroon). Lets analyses rebuild
  /// the participant's local time without a time-zone database.
  final int utcOffsetMinutes;

  /// Monotonic-clock duration of the capture (tick start until [TelemetrySample.timestampMs]).
  final int? captureDurationMs;

  /// Age of the radio reading at capture, in ms: CellInfo's own timestamp on Android.
  /// Null when there's no radio reading, or when the OS gives no timestamp.
  final int? cellInfoAgeMs;

  /// Age of the location fix at capture, in ms. Null when there's no fix.
  final int? locationAgeMs;

  /// The interval the throughput average covers, in ms.
  final int? throughputWindowMs;

  /// Identifies the RTT implementation, since timings aren't comparable across
  /// implementations. Null when RTT wasn't measured.
  final String? rttMethod;

  /// The new app's RTT probe: Dart HttpClient, new connection per probe, HTTPS GET
  /// https://www.gstatic.com/generate_204, 4 s timeout. Reference (v1) rows used Android
  /// HttpURLConnection against the same URL with the same timeout.
  static const String rttMethodDartGenerate204 = 'DART_HTTPS_GET_GENERATE_204';

  FieldStatus statusOf(SampleFieldGroup group) => fieldStatus[group]!;
}

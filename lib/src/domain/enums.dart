/// Wire enums shared by both platforms. Each `wireName` is the exact string the backend
/// stores; it must never change for an existing value (see docs/DATA_CONTRACT.md section 6).
library;

/// Which OTT session, if any, was going on when a sample was captured.
///
/// On iOS, [videoConferencing] means "a CallKit-visible call was active" - CallKit can't tell
/// a WhatsApp video call from a cellular voice call (decision D-4).
enum AppSessionType {
  none('NONE'),
  socialMedia('SOCIAL_MEDIA'),
  videoConferencing('VIDEO_CONFERENCING');

  const AppSessionType(this.wireName);
  final String wireName;
}

/// What prompted a MOS survey.
enum MosTriggerType {
  periodic('PERIODIC'),
  postSession('POST_SESSION'),

  /// Android: RSRP drop/spike/prolonged stability. iOS: RTT/throughput/path change.
  anomaly('ANOMALY');

  const MosTriggerType(this.wireName);
  final String wireName;
}

/// What a sample could actually contain, derived from what the platform returned.
enum TelemetryCapabilityTier {
  /// RSRP, RSRQ, SINR, TA, network type, cell identity (Android API 26+).
  base26('BASE_26'),

  /// [base26] plus CQI (Android API 29+, where the chipset reports it).
  cqi29('CQI_29'),

  /// [cqi29] plus PhysicalChannelConfig - needs carrier privileges; rarely reached.
  physchan30('PHYSCHAN_30'),

  /// iOS: radio access technology, connectivity, RTT, throughput, location only.
  /// Decision D-3 (2026-11-07). A new STRING value, not a schema change.
  iosRat('IOS_RAT');

  const TelemetryCapabilityTier(this.wireName);
  final String wireName;
}

/// Wire-contract version (docs/DATA_CONTRACT.md section 7). v1 is the deployed reference
/// format: no `schemaVersion` key, and NULL in BigQuery. v2 adds cross-platform metadata and
/// per-field status. A client may only send v2 after the v2 functions are deployed.
enum ContractVersion {
  v1(1),
  v2(2);

  const ContractVersion(this.number);
  final int number;
}

/// Measurement groups that get a per-sample status in contract v2. A group shares one
/// acquisition path, so it succeeds or fails as a unit. [wireName] is the value used in
/// `capabilitySet`, and [statusKey] is the NDJSON/BigQuery column for its status.
enum SampleFieldGroup {
  /// rsrp, rsrq, rssnr, timingAdvance, cellIdentityHash, trackingAreaCode, signalStrengthLevel.
  radio('RADIO', 'radioStatus'),

  /// cqi, cqiSupported.
  cqi('CQI', 'cqiStatus'),

  /// cellBandwidthKhz, downlinkChannelNumber, uplinkChannelNumber.
  physicalChannel('PHYSICAL_CHANNEL', 'physicalChannelStatus'),

  /// networkType.
  networkType('NETWORK_TYPE', 'networkTypeStatus'),

  /// connectionType, isRoaming.
  connectivity('CONNECTIVITY', 'connectivityStatus'),

  /// throughputBytesPerSecond.
  throughput('THROUGHPUT', 'throughputStatus'),

  /// rttMs.
  rtt('RTT', 'rttStatus'),

  /// foregroundAppPackage. appSessionType is always present, so it has no status of its own.
  foregroundApp('FOREGROUND_APP', 'foregroundAppStatus'),

  /// latitude, longitude, locationAccuracyMeters.
  location('LOCATION', 'locationStatus');

  const SampleFieldGroup(this.wireName, this.statusKey);
  final String wireName;
  final String statusKey;
}

/// Why a measurement group does or doesn't have a value in this sample (contract v2). These
/// are the distinctions that v1 collapses into a single `null`.
enum FieldStatus {
  /// Measured during this capture; the value is current.
  ok('OK'),

  /// A value is present but older than the current sampling interval (so not from this tick), e.g. a modem-cached
  /// CellInfo or a cached location fix. The value is kept, and its age is in the *AgeMs field.
  stale('STALE'),

  /// The platform, OS version or hardware has no way to measure it. On iOS this is
  /// permanent for every radio field. The value is always null.
  notSupported('NOT_SUPPORTED'),

  /// Supported, but the participant hasn't granted the permission. The value is always null.
  permissionDenied('PERMISSION_DENIED'),

  /// An API exists, but the system, carrier or a device policy won't let this app use it.
  /// Example: PhysicalChannelConfig without carrier privileges. The value is always null.
  restricted('RESTRICTED'),

  /// Deliberately not measured this tick, e.g. RTT at rest except every 5th tick. The value
  /// is always null.
  notAttempted('NOT_ATTEMPTED'),

  /// Attempted, but the OS returned nothing usable: no registered LTE cell, no service, a
  /// sentinel value, or no throughput baseline yet. The value is always null.
  unavailable('UNAVAILABLE'),

  /// Attempted, but ran out of its time budget (location wait, RTT probe). The value is
  /// always null.
  timeout('TIMEOUT'),

  /// Attempted and errored: an exception, or a probe that failed. The value is always null.
  failed('FAILED');

  const FieldStatus(this.wireName);
  final String wireName;

  /// The statuses under which the group's value fields may be non-null.
  bool get carriesValue => this == ok || this == stale;

  /// The statuses meaning the device can't provide the group at all right now. These groups
  /// are excluded from `capabilitySet`.
  bool get isCapabilityGap => this == notSupported || this == permissionDenied || this == restricted;
}

/// Where a MOS rating's context (app / session category) came from (contract v2).
enum ContextSource {
  /// Observed by the device: Android usage stats and call detection.
  observed('OBSERVED'),

  /// The participant's answer to "what were you doing?" (iOS, decision D-6).
  selfReported('SELF_REPORTED'),

  /// Neither observed nor answered. contextSessionType is then NONE and
  /// contextAppPackage is null.
  unknown('UNKNOWN');

  const ContextSource(this.wireName);
  final String wireName;
}

/// How the rating prompt reached the participant (contract v2). It affects how much
/// attention the rating got, and the delay between the network event and the rating.
enum PresentationMode {
  /// Android: the survey drawn over other apps.
  overlay('OVERLAY'),

  /// A notification the participant tapped to open the survey.
  notification('NOTIFICATION'),

  /// iOS: the rating chosen directly from the notification's action buttons.
  notificationAction('NOTIFICATION_ACTION'),

  /// Rated inside the app: the status screen's test survey, or an open survey sheet.
  inApp('IN_APP');

  const PresentationMode(this.wireName);
  final String wireName;
}

/// Values of the additive, nullable BigQuery `platform` column.
enum ClientPlatform {
  android('ANDROID'),
  ios('IOS');

  const ClientPlatform(this.wireName);
  final String wireName;

  static ClientPlatform fromWireName(String value) => ClientPlatform.values.firstWhere(
    (p) => p.wireName == value,
    orElse: () => throw ArgumentError.value(value, 'platform'),
  );
}

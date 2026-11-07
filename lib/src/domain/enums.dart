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
  /// PROVISIONAL - pending decision D-3. A new STRING value, not a schema change.
  iosRat('IOS_RAT');

  const TelemetryCapabilityTier(this.wireName);
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

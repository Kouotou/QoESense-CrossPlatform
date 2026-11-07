import '../domain/enums.dart';

/// Derives the tier a sample *actually achieved* from what the platform returned - port of
/// the reference app's `TelemetryCapabilityResolver`, plus the iOS tier (decision D-3).
abstract final class CapabilityTierResolver {
  static TelemetryCapabilityTier resolve({
    required ClientPlatform platform,
    bool cqiSupported = false,
    int? cellBandwidthKhz,
    int? downlinkChannelNumber,
    int? uplinkChannelNumber,
  }) {
    if (platform == ClientPlatform.ios) return TelemetryCapabilityTier.iosRat;
    final hasPhysChan = cellBandwidthKhz != null || downlinkChannelNumber != null || uplinkChannelNumber != null;
    if (hasPhysChan) return TelemetryCapabilityTier.physchan30;
    if (cqiSupported) return TelemetryCapabilityTier.cqi29;
    return TelemetryCapabilityTier.base26;
  }
}

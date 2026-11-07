import 'package:flutter_test/flutter_test.dart';
import 'package:qoesense/src/application/capability_tier_resolver.dart';
import 'package:qoesense/src/domain/enums.dart';

void main() {
  test('Android with nothing extra is BASE_26', () {
    expect(CapabilityTierResolver.resolve(platform: ClientPlatform.android), TelemetryCapabilityTier.base26);
  });

  test('Android with CQI is CQI_29', () {
    expect(
      CapabilityTierResolver.resolve(platform: ClientPlatform.android, cqiSupported: true),
      TelemetryCapabilityTier.cqi29,
    );
  });

  test('any physical-channel field promotes to PHYSCHAN_30', () {
    expect(
      CapabilityTierResolver.resolve(platform: ClientPlatform.android, uplinkChannelNumber: 1),
      TelemetryCapabilityTier.physchan30,
    );
  });

  test('iOS is always IOS_RAT, whatever is passed', () {
    expect(
      CapabilityTierResolver.resolve(platform: ClientPlatform.ios, cqiSupported: true, cellBandwidthKhz: 20000),
      TelemetryCapabilityTier.iosRat,
    );
  });

  test('tier wire names match the reference enum plus the provisional iOS value', () {
    expect(TelemetryCapabilityTier.values.map((t) => t.wireName), ['BASE_26', 'CQI_29', 'PHYSCHAN_30', 'IOS_RAT']);
  });
}

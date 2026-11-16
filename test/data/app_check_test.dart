import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qoesense/src/data/backend/app_check.dart';

/// App Check providers (docs/APP_CHECK.md). Activation itself needs a device.
void main() {
  test('debug builds use the debug providers (their tokens are allow-listed in the console)', () {
    final p = appCheckProviders(debug: true);
    expect(p.android, isA<AndroidDebugProvider>());
    expect(p.apple, isA<AppleDebugProvider>());
  });

  test('release builds use Play Integrity and DeviceCheck (no App Attest entitlement needed yet)', () {
    final p = appCheckProviders(debug: false);
    expect(p.android, isA<AndroidPlayIntegrityProvider>());
    expect(p.apple, isA<AppleDeviceCheckProvider>());
  });
}

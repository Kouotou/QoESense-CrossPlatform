import 'dart:developer' as developer;

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Firebase App Check (2026-11-16, docs/APP_CHECK.md): attaches a token proving "this request
/// comes from the genuine QoESense app" to Firestore, Storage and Auth calls, so that, once
/// enforcement is switched on in the console, nobody can drain the free daily quotas with a
/// copied API key.
///
/// **Monitoring mode only.** Enforcement is off: the release providers need the Play Console's
/// app-signing key (Android) and the paid Apple Developer Program (iOS), and the reference app
/// (com.example.qoesense) has no App Check, so enforcing would block its participants.
///
/// Fail-open: if activation fails, the app works exactly as before (requests without a token
/// are accepted while enforcement is off). Called by every engine (UI, collector, upload).
Future<void> activateAppCheck() async {
  final p = appCheckProviders(debug: kDebugMode);
  try {
    await FirebaseAppCheck.instance.activate(providerAndroid: p.android, providerApple: p.apple);
  } on Object catch (e) {
    developer.log('App Check not activated; continuing without it', name: 'QoESense', error: e);
  }
}

/// Debug builds use the debug provider: its token is printed once in logcat / the Xcode console
/// and must be added in the console before enforcement, or debug builds will be refused.
/// Release builds: Play Integrity on Android; DeviceCheck on iOS, which needs no extra
/// entitlement, so the free signing team still works. Switch iOS to App Attest (with DeviceCheck
/// fallback) once the paid Apple account adds the App Attest capability.
({AndroidAppCheckProvider android, AppleAppCheckProvider apple}) appCheckProviders({required bool debug}) => debug
    ? (android: const AndroidDebugProvider(), apple: const AppleDebugProvider())
    : (android: const AndroidPlayIntegrityProvider(), apple: const AppleDeviceCheckProvider());

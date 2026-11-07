// Firebase client options for this app. These aren't secrets: they're the same information
// as google-services.json, which the reference app commits too. Access is enforced by the
// Firebase security rules (each device can reach only its own anonymous UID's paths).
//
// A platform whose options are null runs fail-closed: it collects and buffers, but uploads
// nothing and deletes nothing.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

abstract final class QoESenseFirebaseOptions {
  static FirebaseOptions? get currentPlatform => switch (defaultTargetPlatform) {
    TargetPlatform.android => android,
    TargetPlatform.iOS => ios,
    _ => null,
  };

  /// Android app io.github.kouotou.qoesense, registered in project `qoesense` on 2026-11-07.
  /// Values come from that app's entry in google-services.json.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBulciJTIroDWFmHHBkert4RsmGUJKsOWY',
    appId: '1:412391455735:android:fbb523131e821c2791ccf2',
    messagingSenderId: '412391455735',
    projectId: 'qoesense',
    storageBucket: 'qoesense.firebasestorage.app',
  );

  /// iOS app io.github.kouotou.qoesense, not registered yet (needs the Mac phase).
  static const FirebaseOptions? ios = null;
}

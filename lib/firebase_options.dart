// Firebase client options for this app (not secrets: the same information as
// google-services.json). They stay null until io.github.kouotou.qoesense is registered in
// the `qoesense` Firebase console. Until then the app runs fail-closed: it collects and
// buffers, but uploads nothing and deletes nothing.
//
// After registration, fill in the values from the console (Project settings → Your apps),
// or run `flutterfire configure`, and keep the class name below.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

abstract final class QoESenseFirebaseOptions {
  static FirebaseOptions? get currentPlatform => switch (defaultTargetPlatform) {
    TargetPlatform.android => android,
    TargetPlatform.iOS => ios,
    _ => null,
  };

  /// Android app io.github.kouotou.qoesense, not registered yet.
  static const FirebaseOptions? android = null;

  /// iOS app io.github.kouotou.qoesense, not registered yet (needs the Mac phase).
  static const FirebaseOptions? ios = null;
}

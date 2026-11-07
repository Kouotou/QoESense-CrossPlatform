import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../firebase_options.dart';
import 'backend_ports.dart';

/// Connects to the existing `qoesense` Firebase project with the same paths and semantics as
/// the reference app (FirebaseAuthDeviceIdentityProvider, FirebaseStorageUploadDestination,
/// MosSurveyRepository, ConsentRepository). Returns [Backend.unconfigured] until this app is
/// registered in the console and lib/firebase_options.dart holds its options.
Future<Backend> openBackend() async {
  final options = QoESenseFirebaseOptions.currentPlatform;
  if (options == null) return const Backend.unconfigured();
  if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: options);
  return Backend(
    identity: FirebaseDeviceIdentity(),
    batches: FirebaseBatchDestination(),
    mos: FirestoreMosSink(),
    consent: FirestoreConsentSink(),
  );
}

const _timeout = Duration(seconds: 60);

class FirebaseDeviceIdentity implements DeviceIdentity {
  @override
  Future<String?> deviceId() async {
    final auth = FirebaseAuth.instance;
    final current = auth.currentUser;
    if (current != null) return current.uid;
    try {
      return (await auth.signInAnonymously().timeout(_timeout)).user?.uid;
    } on Object {
      return null; // offline: retried on the next run
    }
  }
}

class FirebaseBatchDestination implements BatchDestination {
  @override
  Future<bool> upload({required String objectPath, required Uint8List gzippedNdjson}) async {
    try {
      // Resolves only once the object is stored, which fires loadTelemetryBatch.
      await FirebaseStorage.instance.ref(objectPath).putData(gzippedNdjson).timeout(const Duration(minutes: 5));
      return true;
    } on Object {
      return false;
    }
  }
}

class FirestoreMosSink implements MosSink {
  @override
  Future<bool> submit(String deviceId, String responseId, Map<String, Object?> body) async {
    try {
      // `set` on the tap-time ID: a retry after a lost ack overwrites the same document, and
      // exportMosResponse (onDocumentCreated) fires only once.
      await FirebaseFirestore.instance
          .collection('devices')
          .doc(deviceId)
          .collection('mosResponses')
          .doc(responseId)
          .set(body)
          .timeout(_timeout);
      return true;
    } on Object {
      return false;
    }
  }
}

class FirestoreConsentSink implements ConsentSink {
  @override
  Future<bool> recordConsentGiven(String deviceId, int timestampMs) async {
    try {
      await FirebaseFirestore.instance
          .collection('devices')
          .doc(deviceId)
          .set({'consentGivenAtMs': timestampMs}, SetOptions(merge: true))
          .timeout(_timeout);
      return true;
    } on Object {
      return false;
    }
  }
}

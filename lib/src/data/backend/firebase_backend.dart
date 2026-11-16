import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../firebase_options.dart';
import 'app_check.dart';
import 'backend_ports.dart';
import 'batch_document.dart';

/// Connects to the existing `qoesense` Firebase project with the same paths and semantics as
/// the reference app (FirebaseAuthDeviceIdentityProvider, FirebaseStorageUploadDestination,
/// MosSurveyRepository, ConsentRepository). Returns [Backend.unconfigured] until this app is
/// registered in the console and lib/firebase_options.dart holds its options.
Future<Backend> openBackend() async {
  final options = QoESenseFirebaseOptions.currentPlatform;
  if (options == null) return const Backend.unconfigured();
  if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: options);
  // Before the first Firestore/Auth call, so every request can carry a token.
  await activateAppCheck();
  try {
    // No Firestore offline cache. Every write that matters is already queued durably in the
    // app's own SQLite (telemetry buffer, pending-MOS queue), and caching ~60 KB batch blobs
    // would only grow the cache. It can only be set before first use, so a second engine in
    // the same process may throw here, harmlessly.
    FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
  } on Object {
    // Already configured by another engine in this process.
  }
  return Backend(
    identity: FirebaseDeviceIdentity(),
    batches: switch (activeUploadTarget) {
      UploadTarget.cloudStorage => FirebaseBatchDestination(),
      UploadTarget.firestore => FirestoreBatchDestination(),
    },
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

/// Free-tier upload target: the batch's gzipped NDJSON bytes in one Firestore document.
/// Like the Storage path, it reports success only after the server has acknowledged the write.
/// Rows are deleted from the phone's buffer only then.
class FirestoreBatchDestination implements BatchDestination {
  @override
  Future<bool> upload({required String objectPath, required Uint8List gzippedNdjson}) async {
    if (gzippedNdjson.length > maxBatchDocumentBytes) return false; // never expected (~60 KB/batch)
    try {
      final doc = BatchDocument.fromObjectPath(
        objectPath: objectPath,
        gzippedNdjson: gzippedNdjson,
        nowMs: DateTime.now().millisecondsSinceEpoch,
      );
      final data = {
        for (final e in doc.fields.entries) e.key: e.value is Uint8List ? Blob(e.value as Uint8List) : e.value,
      };
      await FirebaseFirestore.instance.doc(doc.path).set(data).timeout(const Duration(minutes: 2));
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

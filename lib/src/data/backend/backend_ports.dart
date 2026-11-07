import 'dart:typed_data';

import '../../domain/mos_response.dart';

/// Ports to the existing Firebase backend. Phase 2 implements them with FlutterFire
/// (firebase_auth / firebase_storage / cloud_firestore) against the unchanged `qoesense`
/// project. Every port reports success only once the backend has durably accepted the
/// write - never optimistically.

/// Anonymous Firebase Auth UID - the device identifier everywhere. Null when sign-in is not
/// (yet) possible, e.g. offline on first launch.
abstract interface class DeviceIdentity {
  Future<String?> deviceId();
}

/// Cloud Storage `telemetry/{uid}/{date}/{batchId}.json.gz`.
abstract interface class BatchDestination {
  Future<bool> upload({required String objectPath, required Uint8List gzippedNdjson});
}

/// Firestore `devices/{uid}/mosResponses/{responseId}` - idempotent `set` on the tap-time id.
abstract interface class MosSink {
  Future<bool> submit(String deviceId, MosResponse response);
}

/// Firestore `devices/{uid}` merge `{consentGivenAtMs}` - best effort; the local consent flag
/// is what actually gates collection.
abstract interface class ConsentSink {
  Future<bool> recordConsentGiven(String deviceId, int timestampMs);
}

/// Fail-closed placeholders used until FlutterFire is configured (Phase 2) - mirrors the
/// reference app's UnconfiguredUploadDestination. Nothing is ever reported as uploaded, so
/// nothing is ever deleted from the buffer.
class UnconfiguredDeviceIdentity implements DeviceIdentity {
  const UnconfiguredDeviceIdentity();
  @override
  Future<String?> deviceId() async => null;
}

class UnconfiguredBatchDestination implements BatchDestination {
  const UnconfiguredBatchDestination();
  @override
  Future<bool> upload({required String objectPath, required Uint8List gzippedNdjson}) async => false;
}

class UnconfiguredMosSink implements MosSink {
  const UnconfiguredMosSink();
  @override
  Future<bool> submit(String deviceId, MosResponse response) async => false;
}

class UnconfiguredConsentSink implements ConsentSink {
  const UnconfiguredConsentSink();
  @override
  Future<bool> recordConsentGiven(String deviceId, int timestampMs) async => false;
}

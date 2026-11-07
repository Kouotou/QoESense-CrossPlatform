import 'dart:typed_data';

/// Ports to the existing, unchanged Firebase backend (project `qoesense`). Every port
/// reports success only after the backend has durably accepted the write, never
/// optimistically. Firebase implementations are in firebase_backend.dart; the fail-closed
/// placeholders below are used until this app is registered in the Firebase console.

/// The installation's anonymous Firebase Auth UID, which is the device ID everywhere. Null
/// when sign-in isn't possible yet, e.g. offline on first launch.
abstract interface class DeviceIdentity {
  Future<String?> deviceId();
}

/// Cloud Storage `telemetry/{uid}/{date}/{batchId}.json.gz`.
abstract interface class BatchDestination {
  Future<bool> upload({required String objectPath, required Uint8List gzippedNdjson});
}

/// Firestore `devices/{uid}/mosResponses/{responseId}`, written with an idempotent `set`
/// keyed on the tap-time ID.
abstract interface class MosSink {
  Future<bool> submit(String deviceId, String responseId, Map<String, Object?> firestoreBody);
}

/// Firestore `devices/{uid}`, merged with `{consentGivenAtMs}`. Best effort: the local
/// consent flag is what actually gates collection.
abstract interface class ConsentSink {
  Future<bool> recordConsentGiven(String deviceId, int timestampMs);
}

/// Fail-closed placeholders that mirror the reference app's UnconfiguredUploadDestination.
/// Nothing is ever reported as uploaded, so nothing is ever deleted from the buffer.
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
  Future<bool> submit(String deviceId, String responseId, Map<String, Object?> firestoreBody) async => false;
}

class UnconfiguredConsentSink implements ConsentSink {
  const UnconfiguredConsentSink();
  @override
  Future<bool> recordConsentGiven(String deviceId, int timestampMs) async => false;
}

/// The four ports together, so every entrypoint wires the same backend.
class Backend {
  const Backend({required this.identity, required this.batches, required this.mos, required this.consent});

  const Backend.unconfigured()
    : identity = const UnconfiguredDeviceIdentity(),
      batches = const UnconfiguredBatchDestination(),
      mos = const UnconfiguredMosSink(),
      consent = const UnconfiguredConsentSink();

  final DeviceIdentity identity;
  final BatchDestination batches;
  final MosSink mos;
  final ConsentSink consent;

  bool get isConfigured => identity is! UnconfiguredDeviceIdentity;
}

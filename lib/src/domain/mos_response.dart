import 'enums.dart';

/// One participant rating on the unchanged 1-5 MOS scale, tied to the telemetry window
/// immediately preceding the tap (early-fusion labelling), as in the reference app.
///
/// The seven reference fields keep their names, units and meaning. The contract-v2 fields
/// (platform onwards) are written to Firestore from the start, which is safe because the
/// deployed exportMosResponse maps fields explicitly and ignores unknown ones. They reach
/// BigQuery once the v2 function is deployed.
class MosResponse {
  MosResponse({
    required this.responseId,
    required this.score,
    required this.submittedAtMs,
    required this.triggerType,
    required this.contextAppPackage,
    required this.contextSessionType,
    required this.windowStartMs,
    required this.windowEndMs,
    required this.platform,
    required this.contextSource,
    required this.presentationMode,
    required this.appId,
    required this.appVersion,
    required this.appBuild,
    required this.utcOffsetMinutes,
    this.promptedAtMs,
  }) {
    if (score < minScore || score > maxScore) {
      throw ArgumentError.value(score, 'score', 'MOS must be $minScore-$maxScore');
    }
    if (windowStartMs > windowEndMs) {
      throw ArgumentError('windowStartMs must not be after windowEndMs');
    }
    if (contextSource == ContextSource.unknown &&
        (contextAppPackage != null || contextSessionType != AppSessionType.none)) {
      throw ArgumentError('UNKNOWN context must have no app and session type NONE');
    }
    if (promptedAtMs != null && promptedAtMs! > submittedAtMs) {
      throw ArgumentError('promptedAtMs must not be after submittedAtMs');
    }
  }

  /// Builds the response for a tap at [tapMs], with window = the [contextWindowMs] before it.
  /// [responseId] must be generated at tap time and reused on every retry, for idempotency.
  factory MosResponse.forTap({
    required String responseId,
    required int score,
    required int tapMs,
    required MosTriggerType triggerType,
    required String? contextAppPackage,
    required AppSessionType contextSessionType,
    required ClientPlatform platform,
    required ContextSource contextSource,
    required PresentationMode presentationMode,
    required String appId,
    required String appVersion,
    required int appBuild,
    required int utcOffsetMinutes,
    int? promptedAtMs,
  }) => MosResponse(
    responseId: responseId,
    score: score,
    submittedAtMs: tapMs,
    triggerType: triggerType,
    contextAppPackage: contextAppPackage,
    contextSessionType: contextSessionType,
    windowStartMs: tapMs - contextWindowMs,
    windowEndMs: tapMs,
    platform: platform,
    contextSource: contextSource,
    presentationMode: presentationMode,
    appId: appId,
    appVersion: appVersion,
    appBuild: appBuild,
    utcOffsetMinutes: utcOffsetMinutes,
    promptedAtMs: promptedAtMs,
  );

  static const int minScore = 1;
  static const int maxScore = 5;

  /// Same 10-minute window as the reference app's MosSubmitWorker.CONTEXT_WINDOW_MS.
  static const int contextWindowMs = 10 * 60 * 1000;

  final String responseId;
  final int score;

  /// Tap time, Unix epoch ms, UTC.
  final int submittedAtMs;
  final MosTriggerType triggerType;

  /// Android package name: observed on Android, mapped from the self-report on iOS (D-6).
  final String? contextAppPackage;
  final AppSessionType contextSessionType;
  final int windowStartMs;
  final int windowEndMs;

  // Contract v2.
  final ClientPlatform platform;
  final ContextSource contextSource;
  final PresentationMode presentationMode;
  final String appId;
  final String appVersion;
  final int appBuild;
  final int utcOffsetMinutes;

  /// When the prompt was shown (epoch ms). Null when the rating wasn't prompted, e.g. the
  /// status screen's test survey.
  final int? promptedAtMs;

  /// The 7 reference fields: the Firestore body the reference app writes.
  Map<String, Object?> toV1Fields() => <String, Object?>{
    'score': score,
    'submittedAtMs': submittedAtMs,
    'triggerType': triggerType.wireName,
    'contextAppPackage': contextAppPackage,
    'contextSessionType': contextSessionType.wireName,
    'windowStartMs': windowStartMs,
    'windowEndMs': windowEndMs,
  };

  /// Body of Firestore `devices/{uid}/mosResponses/{responseId}`. The responseId is the
  /// document ID, not a field.
  Map<String, Object?> toFirestore() => <String, Object?>{
    ...toV1Fields(),
    'schemaVersion': ContractVersion.v2.number,
    'platform': platform.wireName,
    'contextSource': contextSource.wireName,
    'presentationMode': presentationMode.wireName,
    'appId': appId,
    'appVersion': appVersion,
    'appBuild': appBuild,
    'utcOffsetMinutes': utcOffsetMinutes,
    'promptedAtMs': promptedAtMs,
  };
}

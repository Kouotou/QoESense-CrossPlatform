import 'enums.dart';

/// One participant rating on the unchanged 1-5 MOS scale, tied to the telemetry window
/// immediately preceding the tap (early-fusion labelling), as in the reference app.
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
  }) {
    if (score < minScore || score > maxScore) {
      throw ArgumentError.value(score, 'score', 'MOS must be $minScore-$maxScore');
    }
    if (windowStartMs > windowEndMs) {
      throw ArgumentError('windowStartMs must not be after windowEndMs');
    }
  }

  /// Builds the response for a tap at [tapMs]: window = the [contextWindowMs] before it.
  /// [responseId] must be generated at tap time and reused on every retry (idempotency).
  factory MosResponse.forTap({
    required String responseId,
    required int score,
    required int tapMs,
    required MosTriggerType triggerType,
    required String? contextAppPackage,
    required AppSessionType contextSessionType,
    required ClientPlatform platform,
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
  );

  static const int minScore = 1;
  static const int maxScore = 5;

  /// Same 10-minute window as the reference app's MosSubmitWorker.CONTEXT_WINDOW_MS.
  static const int contextWindowMs = 10 * 60 * 1000;

  final String responseId;
  final int score;
  final int submittedAtMs;
  final MosTriggerType triggerType;
  final String? contextAppPackage;
  final AppSessionType contextSessionType;
  final int windowStartMs;
  final int windowEndMs;
  final ClientPlatform platform;

  /// Body of Firestore `devices/{uid}/mosResponses/{responseId}`. The responseId is the
  /// document ID, not a field. `platform` is safe to include before the functions deploy:
  /// the deployed exportMosResponse maps fields explicitly and ignores unknown ones.
  Map<String, Object?> toFirestore() => <String, Object?>{
    'score': score,
    'submittedAtMs': submittedAtMs,
    'triggerType': triggerType.wireName,
    'contextAppPackage': contextAppPackage,
    'contextSessionType': contextSessionType.wireName,
    'windowStartMs': windowStartMs,
    'windowEndMs': windowEndMs,
    'platform': platform.wireName,
  };
}

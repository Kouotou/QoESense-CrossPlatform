import '../data/backend/backend_ports.dart';
import '../data/local/telemetry_buffer.dart';
import '../domain/enums.dart';
import '../domain/mos_response.dart';
import 'captured_sample.dart';
import 'stores.dart';

/// A tap recorded by native survey UI (overlay activity or notification), waiting in the
/// native queue until Dart has durably queued it.
class SurveyAnswer {
  const SurveyAnswer({
    required this.responseId,
    required this.score,
    required this.triggerType,
    required this.tapMs,
    required this.presentationMode,
    this.promptedAtMs,
    this.selfReport,
  });
  final String responseId;
  final int score;
  final MosTriggerType triggerType;
  final int tapMs;
  final int? promptedAtMs;
  final PresentationMode presentationMode;

  /// The participant's answer to "what were you doing?" (iOS in-app sheet, D-6). Null when
  /// the question wasn't asked (Android, notification actions) or was skipped.
  final SelfReportedContext? selfReport;
}

/// A self-reported context: the Android package name of the chosen app (null for
/// "something else") and its session category.
class SelfReportedContext {
  const SelfReportedContext({required this.appPackage, required this.sessionType});
  final String? appPackage;
  final AppSessionType sessionType;
}

/// Native survey answer queue: read, then acknowledge only after the answers are durable here.
abstract interface class SurveyAnswerQueue {
  Future<List<SurveyAnswer>> pending();
  Future<void> acknowledge(List<String> responseIds);
}

/// Taps → MosResponse (context from the buffered sample in the 10-minute window, as the
/// reference MosSubmitWorker does) → durable pending queue → idempotent backend write.
///
/// Deliberate difference from the reference: a rating is **never dropped**. The reference
/// gave up after 10 WorkManager attempts; here it stays queued, with exponential backoff
/// capped at 1 h, until the backend confirms it.
class MosPipeline {
  MosPipeline({
    required this.answers,
    required this.buffer,
    required this.pending,
    required this.identity,
    required this.sink,
    required this.app,
    required this.platform,
    this.clock = DateTime.now,
  });

  final SurveyAnswerQueue answers;
  final TelemetryBuffer buffer;
  final PendingMosStore pending;
  final DeviceIdentity identity;
  final MosSink sink;
  final AppInfo app;
  final ClientPlatform platform;
  final DateTime Function() clock;

  final _nextAttemptAt = <String, int>{};
  bool _busy = false;

  static const int maxBackoffMs = 60 * 60 * 1000;

  static int backoffMs(int attempts) {
    final ms = 30000 * (1 << (attempts.clamp(0, 10)));
    return ms > maxBackoffMs ? maxBackoffMs : ms;
  }

  /// Drains new taps into the durable queue, then tries to submit what's due. Re-entrant
  /// calls while a run is in progress are ignored.
  Future<void> run() async {
    if (_busy) return;
    _busy = true;
    try {
      await intake();
      await submitDue();
    } finally {
      _busy = false;
    }
  }

  Future<int> intake() async {
    final taps = await answers.pending();
    if (taps.isEmpty) return 0;
    for (final t in taps) {
      final answered = t.selfReport;
      final context = await buffer.latestInWindow(t.tapMs - MosResponse.contextWindowMs, t.tapMs);
      // OBSERVED only when that sample actually saw the foreground app. Otherwise the context
      // is the participant's own answer (iOS, D-6) if there is one, else UNKNOWN (no app,
      // NONE) rather than a guess.
      final observed =
          context != null && context.provenance.fieldStatus[SampleFieldGroup.foregroundApp]?.carriesValue == true;
      final (String? contextApp, AppSessionType session, ContextSource source) = observed
          ? (context.foregroundAppPackage, context.appSessionType, ContextSource.observed)
          : answered != null
          ? (answered.appPackage, answered.sessionType, ContextSource.selfReported)
          : (null, AppSessionType.none, ContextSource.unknown);
      final response = MosResponse.forTap(
        responseId: t.responseId,
        score: t.score,
        tapMs: t.tapMs,
        triggerType: t.triggerType,
        contextAppPackage: contextApp,
        contextSessionType: session,
        platform: platform,
        contextSource: source,
        presentationMode: t.presentationMode,
        appId: app.appId,
        appVersion: app.appVersion,
        appBuild: app.appBuild,
        utcOffsetMinutes: DateTime.fromMillisecondsSinceEpoch(t.tapMs).timeZoneOffset.inMinutes,
        promptedAtMs: t.promptedAtMs,
      );
      await pending.enqueue(response, clock().millisecondsSinceEpoch);
    }
    // Only now is it safe to let native forget them.
    await answers.acknowledge([for (final t in taps) t.responseId]);
    return taps.length;
  }

  Future<int> submitDue() async {
    final queue = await pending.all();
    if (queue.isEmpty) return 0;
    final now = clock().millisecondsSinceEpoch;
    final due = queue.where((p) => (_nextAttemptAt[p.responseId] ?? 0) <= now).toList();
    if (due.isEmpty) return 0;
    final deviceId = await identity.deviceId();
    if (deviceId == null) return 0;
    var sent = 0;
    for (final p in due) {
      final ok = await sink.submit(deviceId, p.responseId, p.firestoreBody);
      if (ok) {
        await pending.remove(p.responseId);
        _nextAttemptAt.remove(p.responseId);
        sent++;
      } else {
        await pending.markAttempt(p.responseId);
        _nextAttemptAt[p.responseId] = now + backoffMs(p.attempts + 1);
      }
    }
    return sent;
  }
}

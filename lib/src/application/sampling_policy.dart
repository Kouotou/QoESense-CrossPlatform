import '../domain/enums.dart';

/// Adaptive sampling cadence - a port of the reference app's `SamplingScheduler`
/// (../QoESense service/SamplingScheduler.kt). Single source of truth for both platforms:
/// the Android foreground service and the iOS background host both ask this for the next
/// delay rather than keeping their own constants.
///
/// **60 s at rest, 15 s during a detected video call** (agreed Nov 2026; supersedes the
/// handbook's 20 s / 5 s, which produced long runs of duplicate rows).
///
/// Only changes how densely this device's *own* telemetry is captured - it never touches
/// network traffic.
abstract final class SamplingPolicy {
  static const int standardIntervalMs = 60000;
  static const int elevatedIntervalMs = 15000;

  /// Max wait for a location fix at rest.
  static const int standardLocationTimeoutMs = 15000;

  /// Must fit inside [elevatedIntervalMs] or the dense cadence silently collapses.
  static const int elevatedLocationTimeoutMs = 8000;

  /// At rest RTT is probed every Nth tick - every 5th at 60 s is about every 5 minutes.
  static const int rttSampleEveryN = 5;

  static int intervalFor(AppSessionType session) =>
      session == AppSessionType.videoConferencing ? elevatedIntervalMs : standardIntervalMs;

  static int locationTimeoutFor(AppSessionType session) =>
      session == AppSessionType.videoConferencing ? elevatedLocationTimeoutMs : standardLocationTimeoutMs;

  static bool shouldAlwaysMeasureRtt(AppSessionType session) => session == AppSessionType.videoConferencing;

  static bool shouldMeasureRtt(AppSessionType session, int sampleCount) =>
      shouldAlwaysMeasureRtt(session) || sampleCount % rttSampleEveryN == 0;

  /// Fixed-rate: ticks start every [intervalMs] from the previous tick's *start*. An overrun
  /// starts the next tick immediately (no catch-up burst); a clock oddity never waits more
  /// than one interval.
  static int delayUntilNextTick({required int tickStartMs, required int nowMs, required int intervalMs}) =>
      (intervalMs - (nowMs - tickStartMs)).clamp(0, intervalMs);
}

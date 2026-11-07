import 'dart:math' as math;

/// Why the RSRP stream warrants an immediate MOS prompt.
enum AnomalyReason { signalDrop, signalSpike, prolongedStability }

/// Port of the reference app's `TelemetryAnomalyDetector` (Android only - iOS has no RSRP;
/// its RTT/throughput/path detector arrives in Phase 3). Pure and stateless: the caller owns
/// the rolling window; [SurveyTriggerPolicy] rate-limits what this flags.
abstract final class RsrpAnomalyDetector {
  static const int recentWindowSize = 3;
  static const int baselineWindowSize = 10;
  static const int drasticChangeDb = 10;
  static const int stabilityWindowSize = 15;
  static const double stabilityStdDevDb = 2.0;

  static AnomalyReason? detect(List<int> readings) => _dropOrSpike(readings) ?? _prolongedStability(readings);

  static AnomalyReason? _dropOrSpike(List<int> readings) {
    if (readings.length < recentWindowSize + baselineWindowSize) return null;
    final recent = readings.sublist(readings.length - recentWindowSize);
    final start = readings.length - recentWindowSize - baselineWindowSize;
    final baseline = readings.sublist(start, start + baselineWindowSize);
    final delta = _mean(recent) - _mean(baseline);
    if (delta <= -drasticChangeDb) return AnomalyReason.signalDrop;
    if (delta >= drasticChangeDb) return AnomalyReason.signalSpike;
    return null;
  }

  static AnomalyReason? _prolongedStability(List<int> readings) {
    if (readings.length < stabilityWindowSize) return null;
    final window = readings.sublist(readings.length - stabilityWindowSize);
    final mean = _mean(window);
    final variance = window.fold<double>(0, (sum, r) => sum + (r - mean) * (r - mean)) / window.length;
    return math.sqrt(variance) <= stabilityStdDevDb ? AnomalyReason.prolongedStability : null;
  }

  static double _mean(List<int> values) => values.reduce((a, b) => a + b) / values.length;
}

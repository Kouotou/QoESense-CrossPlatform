import '../domain/enums.dart';
import '../domain/telemetry_sample.dart';
import 'rsrp_anomaly_detector.dart';

/// The iOS anomaly trigger (DATA_CONTRACT §10: "iOS anomalies come from RTT/throughput/path
/// signals"). iOS has no RSRP, so [RsrpAnomalyDetector] never fires there; this watches what
/// iOS does report. **Rules approved by the owner on 2026-11-11** (docs/PHASE4_IOS.md §6):
///
/// - [AnomalyReason.connectivityLoss]: a usable network path disappeared.
/// - [AnomalyReason.pathChange]: the transport changed between two usable paths
///   (Wi-Fi ↔ cellular).
/// - [AnomalyReason.ratDowngrade]: on cellular, the RAT fell from LTE/NR to an older one or
///   to none. NR ↔ LTE alone isn't counted: NR non-standalone flips between them all the time.
///   **RAT changes are ignored during a call and for [callGraceMs] after it** (owner decision,
///   2026-11-11). On the test network every voice call falls back from LTE to 3G (CSFB), so the
///   rule fired on every call and filled the daily prompt cap by mid-morning.
/// - [AnomalyReason.latencySpike]: an RTT at least twice the median of the previous
///   [rttBaselineSize] RTTs *and* at least [rttSpikeMinDeltaMs] above it, once [rttMinBaseline]
///   exist.
/// - [AnomalyReason.probeFailures]: [failedProbesInRow] RTT probes in a row timed out or failed
///   while a path was usable.
///
/// Throughput is deliberately **not** a trigger: it is device-wide and mostly measures how
/// much the participant is using the phone, not how good the network is.
///
/// Like the RSRP detector, it only flags; [SurveyTriggerPolicy] rate-limits (10 min cooldown,
/// 6 prompts a day, shared with every trigger). The reason itself is never uploaded.
class PathAnomalyDetector {
  static const int rttBaselineSize = 10;
  static const int rttMinBaseline = 5;
  static const int rttSpikeMinDeltaMs = 200;
  static const int failedProbesInRow = 2;

  /// After a call ends, the RAT needs a few seconds to climb back from 3G to LTE.
  static const int callGraceMs = 60 * 1000;

  String? _lastConnection;
  bool _lastPathUsable = false;
  String? _lastCellularRat;
  final List<int> _rtts = [];
  int _failedProbes = 0;
  bool _inCall = false;
  int? _callEndedAtMs;

  /// Feeds one sample (every tick, in order) and returns why it is an anomaly, if it is.
  AnomalyReason? observe(TelemetrySample s) {
    final p = s.provenance;
    final pathStatus = p.statusOf(SampleFieldGroup.connectivity);
    final usable = pathStatus == FieldStatus.ok && s.connectionType != null;
    AnomalyReason? reason;

    if (_lastPathUsable && !usable && pathStatus == FieldStatus.unavailable) {
      reason = AnomalyReason.connectivityLoss;
    } else if (_lastPathUsable && usable && s.connectionType != _lastConnection) {
      reason = AnomalyReason.pathChange;
    }

    // On iOS VIDEO_CONFERENCING means "a CallKit call is active" (D-4).
    final inCall = s.appSessionType == AppSessionType.videoConferencing;
    if (_inCall && !inCall) _callEndedAtMs = s.timestampMs;
    _inCall = inCall;
    final endedAt = _callEndedAtMs;
    final callAffected = inCall || (endedAt != null && s.timestampMs - endedAt < callGraceMs);

    final rat = p.statusOf(SampleFieldGroup.networkType) == FieldStatus.ok ? s.networkType : null;
    // During/just after a call the RAT is neither judged nor remembered, so the post-call
    // comparison is against the pre-call RAT.
    if (rat != null && usable && s.connectionType == 'CELLULAR' && !callAffected) {
      if (reason == null && _isModern(_lastCellularRat) && !_isModern(rat)) reason = AnomalyReason.ratDowngrade;
      _lastCellularRat = rat;
    }

    _lastPathUsable = usable;
    if (usable) _lastConnection = s.connectionType;

    final rttStatus = p.statusOf(SampleFieldGroup.rtt);
    final rtt = s.rttMs;
    if (rttStatus == FieldStatus.ok && rtt != null) {
      _failedProbes = 0;
      if (_rtts.length >= rttMinBaseline) {
        final median = _median(_rtts);
        if (reason == null && rtt >= 2 * median && rtt - median >= rttSpikeMinDeltaMs) {
          reason = AnomalyReason.latencySpike;
        }
      }
      _rtts.add(rtt);
      if (_rtts.length > rttBaselineSize) _rtts.removeAt(0);
    } else if (rttStatus == FieldStatus.timeout || rttStatus == FieldStatus.failed) {
      if (usable) {
        _failedProbes++;
        if (_failedProbes >= failedProbesInRow) {
          reason ??= AnomalyReason.probeFailures;
          _failedProbes = 0;
        }
      }
    }
    return reason;
  }

  static bool _isModern(String? rat) => rat == 'LTE' || rat == 'NR';

  static double _median(List<int> values) {
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd ? sorted[mid].toDouble() : (sorted[mid - 1] + sorted[mid]) / 2;
  }
}

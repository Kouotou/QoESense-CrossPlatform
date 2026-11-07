import '../data/backend/backend_ports.dart';
import '../data/local/telemetry_buffer.dart';
import '../data/upload/batch_serializer.dart';

/// Outcome of one upload run - maps onto WorkManager's success/retry on Android and onto
/// "reschedule soon" vs "normal cadence" for the iOS BGTask.
enum DrainOutcome {
  /// Buffer emptied, or the per-run batch cap was reached with every batch confirmed.
  success,

  /// No device identity yet, or an upload wasn't confirmed - try again later. Nothing was
  /// deleted for the failed batch.
  retry,
}

class DrainResult {
  const DrainResult({required this.outcome, required this.uploadedRows, required this.purgedRows});
  final DrainOutcome outcome;
  final int uploadedRows;
  final int purgedRows;
}

/// Shared upload logic - port of the reference app's TelemetryUploadWorker:
/// drain oldest-first in batches until empty / a failure / the per-run cap, deleting each
/// batch only after its upload is confirmed; **then** apply retention, so a backlog that has
/// just become uploadable is never purged first.
///
/// Network/battery gating (Wi-Fi only, battery not low) is the platform scheduler's job
/// (WorkManager constraints / iOS BGTask + path check) - this class assumes it was allowed
/// to run.
class UploadDrain {
  UploadDrain({
    required this.buffer,
    required this.identity,
    required this.destination,
    this.serializer = const BatchSerializer(),
    this.clock = DateTime.now,
    required this.newBatchId,
  });

  static const int batchLimit = 2000;
  static const int maxBatchesPerRun = 20;

  /// 45 days - widened from 14 during the Sept 2026 billing outage, as in the reference app.
  static const Duration retention = Duration(days: 45);

  final TelemetryBuffer buffer;
  final DeviceIdentity identity;
  final BatchDestination destination;
  final BatchSerializer serializer;
  final DateTime Function() clock;
  final String Function() newBatchId;

  Future<DrainResult> run() async {
    var uploaded = 0;
    final outcome = await _drain((n) => uploaded += n);
    final cutoff = clock().millisecondsSinceEpoch - retention.inMilliseconds;
    final purged = await buffer.deleteOlderThan(cutoff);
    return DrainResult(outcome: outcome, uploadedRows: uploaded, purgedRows: purged);
  }

  Future<DrainOutcome> _drain(void Function(int) onUploaded) async {
    String? deviceId;
    for (var i = 0; i < maxBatchesPerRun; i++) {
      final batch = await buffer.oldest(batchLimit);
      if (batch.isEmpty) return DrainOutcome.success;

      deviceId ??= await identity.deviceId();
      final id = deviceId;
      if (id == null) return DrainOutcome.retry;

      final bytes = serializer.toGzippedNdjson([for (final row in batch) row.sample], id);
      final path = telemetryObjectPath(deviceId: id, localNow: clock(), batchId: newBatchId());
      final ok = await destination.upload(objectPath: path, gzippedNdjson: bytes);
      if (!ok) return DrainOutcome.retry;

      await buffer.deleteByIds([for (final row in batch) row.id]);
      onUploaded(batch.length);
    }
    return DrainOutcome.success;
  }
}

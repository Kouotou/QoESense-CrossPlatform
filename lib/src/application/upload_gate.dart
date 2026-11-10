import 'stores.dart';

/// When the iOS collector engine drains the buffer (docs/PHASE4_IOS.md §3). Android's
/// WorkManager job runs hourly under an unmetered-network constraint; iOS has no such
/// scheduler for a running app, so the collector loop asks this gate after every tick:
/// at most one run per [interval], only when [allowed] says the constraints are met, and
/// never two runs at once (two concurrent drains would upload the same rows twice).
///
/// The attempt time is stored before the run, so a run that crashes still waits an interval.
class UploadGate {
  UploadGate({required this.store, this.clock = DateTime.now});

  static const Duration interval = Duration(hours: 1);
  static const String lastAttemptKey = 'upload.lastAttemptMs';

  final KeyValueStore store;
  final DateTime Function() clock;
  bool _running = false;

  bool get isRunning => _running;

  /// Runs [body] if it is due (or [force]d), [allowed] returns true and no run is in
  /// progress. Returns whether [body] ran.
  Future<bool> maybeRun({
    required Future<bool> Function() allowed,
    required Future<void> Function() body,
    bool force = false,
  }) async {
    if (_running) return false;
    _running = true;
    try {
      final now = clock().millisecondsSinceEpoch;
      final last = int.tryParse(await store.read(lastAttemptKey) ?? '');
      final due = force || last == null || now - last >= interval.inMilliseconds || now < last;
      if (!due || !await allowed()) return false;
      await store.write(lastAttemptKey, '$now');
      await body();
      return true;
    } finally {
      _running = false;
    }
  }
}

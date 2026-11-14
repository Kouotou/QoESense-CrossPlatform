import 'settings_keys.dart';
import 'stores.dart';

/// The "no upload for 3 days" reminder (report alignment, 2026-11-14). Uploads only run on
/// Wi-Fi, so a participant who never joins Wi-Fi keeps everything on the phone until
/// retention (45 days) would purge it. After [overdueAfter] without a successful upload the
/// participant gets one local notification, at most once per [minGap].
///
/// Pure, so it is unit-tested without a clock or a platform.
abstract final class UploadReminderPolicy {
  static const Duration overdueAfter = Duration(days: 3);
  static const Duration minGap = Duration(days: 1);

  /// [lastSuccessMs] is the last successful upload run; before the first one, [baselineMs]
  /// (the consent time) is used, so a new participant isn't reminded on day one.
  static bool shouldRemind({
    required int nowMs,
    required int? lastSuccessMs,
    required int? baselineMs,
    required int? lastReminderMs,
    required int bufferedRows,
  }) {
    if (bufferedRows <= 0) return false;
    final since = lastSuccessMs ?? baselineMs;
    if (since == null || nowMs < since) return false;
    if (nowMs - since < overdueAfter.inMilliseconds) return false;
    if (lastReminderMs == null || nowMs < lastReminderMs) return true;
    return nowMs - lastReminderMs >= minGap.inMilliseconds;
  }
}

/// Runs [UploadReminderPolicy] from the collector loop. It checks at most every
/// [checkEvery], so the extra store reads don't happen on every 15 s tick.
class UploadReminder {
  UploadReminder({
    required this.store,
    required this.bufferedRows,
    required this.show,
    this.nativeLastUploadMs,
    this.clock = DateTime.now,
  });

  static const Duration checkEvery = Duration(minutes: 15);

  final KeyValueStore store;
  final Future<int> Function() bufferedRows;

  /// Shows the notification natively (Android/iOS).
  final Future<void> Function() show;

  /// The native record of the last successful upload (CollectorStatus.lastUploadMs). It
  /// predates [SettingsKeys.uploadLastSuccessMs], so phones updated from an older build
  /// aren't reminded about uploads that did succeed (found on the test phone, 2026-11-14).
  final Future<int?> Function()? nativeLastUploadMs;
  final DateTime Function() clock;
  int? _lastCheckMs;

  /// Returns whether a reminder was shown.
  Future<bool> check() async {
    final now = clock().millisecondsSinceEpoch;
    final lastCheck = _lastCheckMs;
    if (lastCheck != null && now >= lastCheck && now - lastCheck < checkEvery.inMilliseconds) return false;
    _lastCheckMs = now;

    final stored = _int(await store.read(SettingsKeys.uploadLastSuccessMs));
    final native = await nativeLastUploadMs?.call();
    final lastSuccess = stored == null || native == null ? stored ?? native : (stored > native ? stored : native);
    final remind = UploadReminderPolicy.shouldRemind(
      nowMs: now,
      lastSuccessMs: lastSuccess,
      baselineMs: _int(await store.read(SettingsKeys.consentGivenAtMs)),
      lastReminderMs: _int(await store.read(SettingsKeys.uploadLastReminderMs)),
      bufferedRows: await bufferedRows(),
    );
    if (!remind) return false;
    // Stored first: a failing notification must not turn into one attempt per check.
    await store.write(SettingsKeys.uploadLastReminderMs, '$now');
    await show();
    return true;
  }

  static int? _int(String? v) => v == null ? null : int.tryParse(v);
}

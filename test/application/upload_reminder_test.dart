import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:qoesense/src/application/settings_keys.dart';
import 'package:qoesense/src/application/stores.dart';
import 'package:qoesense/src/application/upload_reminder.dart';
import 'package:qoesense/src/entrypoints.dart' show reminderTexts;

/// The "no upload for 3 days" reminder (report alignment, 2026-11-14).
void main() {
  const day = 24 * 60 * 60 * 1000;
  const t0 = 1763000000000;

  bool remind({int now = t0 + 3 * day, int? lastSuccess = t0, int? baseline, int? lastReminder, int rows = 10}) =>
      UploadReminderPolicy.shouldRemind(
        nowMs: now,
        lastSuccessMs: lastSuccess,
        baselineMs: baseline,
        lastReminderMs: lastReminder,
        bufferedRows: rows,
      );

  group('UploadReminderPolicy', () {
    test('reminds after 3 days without a successful upload, not before', () {
      expect(remind(now: t0 + 3 * day - 1), isFalse);
      expect(remind(now: t0 + 3 * day), isTrue);
    });

    test('an empty buffer never needs a reminder', () {
      expect(remind(now: t0 + 10 * day, rows: 0), isFalse);
    });

    test('before the first upload, the consent time is the baseline', () {
      expect(remind(lastSuccess: null, baseline: t0, now: t0 + 2 * day), isFalse);
      expect(remind(lastSuccess: null, baseline: t0, now: t0 + 3 * day), isTrue);
      expect(remind(lastSuccess: null, baseline: null, now: t0 + 30 * day), isFalse);
    });

    test('at most once a day', () {
      final now = t0 + 5 * day;
      expect(remind(now: now, lastReminder: now - day + 1), isFalse);
      expect(remind(now: now, lastReminder: now - day), isTrue);
    });

    test('a clock set backwards neither reminds early nor blocks forever', () {
      expect(remind(now: t0 - day), isFalse);
      final now = t0 + 5 * day;
      expect(remind(now: now, lastReminder: now + day), isTrue);
    });
  });

  group('UploadReminder', () {
    late InMemoryKeyValueStore kv;
    late DateTime now;
    late int shown;
    late int rows;

    UploadReminder reminder() =>
        UploadReminder(store: kv, bufferedRows: () async => rows, show: () async => shown++, clock: () => now);

    setUp(() {
      kv = InMemoryKeyValueStore();
      now = DateTime.fromMillisecondsSinceEpoch(t0 + 4 * day);
      shown = 0;
      rows = 100;
      kv.values[SettingsKeys.consentGivenAtMs] = '$t0';
    });

    test('shows once, records it, and does not repeat the same day', () async {
      final r = reminder();
      expect(await r.check(), isTrue);
      expect(kv.values[SettingsKeys.uploadLastReminderMs], '${now.millisecondsSinceEpoch}');
      now = now.add(const Duration(hours: 1));
      expect(await r.check(), isFalse);
      now = now.add(const Duration(days: 1));
      expect(await r.check(), isTrue);
      expect(shown, 2);
    });

    test('a recent upload recorded only natively (an install updated from an older build) prevents it', () async {
      final r = UploadReminder(
        store: kv,
        bufferedRows: () async => rows,
        show: () async => shown++,
        nativeLastUploadMs: () async => now.millisecondsSinceEpoch - day,
        clock: () => now,
      );
      expect(await r.check(), isFalse);
      expect(shown, 0);
    });

    test('a recent successful upload prevents it', () async {
      kv.values[SettingsKeys.uploadLastSuccessMs] = '${now.millisecondsSinceEpoch - day}';
      expect(await reminder().check(), isFalse);
      expect(shown, 0);
    });

    test('checks the store at most every 15 minutes', () async {
      final r = reminder();
      rows = 0;
      expect(await r.check(), isFalse);
      rows = 100;
      now = now.add(const Duration(minutes: 14));
      expect(await r.check(), isFalse, reason: 'throttled');
      now = now.add(const Duration(minutes: 1));
      expect(await r.check(), isTrue);
    });
  });

  test('the reminder text follows the phone language (French or English)', () {
    expect(reminderTexts(const Locale('fr')).title, contains('QoESense'));
    expect(reminderTexts(const Locale('fr')).body, contains('Wi-Fi'));
    expect(reminderTexts(const Locale('fr')).body, contains('3 jours'));
    expect(reminderTexts(const Locale('en')).body, contains('3 days'));
    expect(reminderTexts(const Locale('de')).body, contains('3 days'), reason: 'other languages fall back to English');
  });
}

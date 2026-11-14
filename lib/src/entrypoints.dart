import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter/widgets.dart';

import '../l10n/generated/app_localizations.dart';
import 'application/captured_sample.dart';
import 'application/collector.dart';
import 'application/mos_pipeline.dart';
import 'application/path_anomaly_detector.dart';
import 'application/settings_keys.dart';
import 'application/stores.dart';
import 'application/survey_scheduler.dart';
import 'application/upload_drain.dart';
import 'application/upload_gate.dart';
import 'application/upload_reminder.dart';
import 'data/backend/backend_ports.dart';
import 'data/backend/batch_document.dart';
import 'data/backend/firebase_backend.dart';
import 'data/local/database.dart';
import 'data/local/drift_stores.dart';
import 'data/local/telemetry_buffer.dart';
import 'data/network/http_rtt_probe.dart';
import 'data/upload/batch_serializer.dart';
import 'domain/enums.dart';
import 'domain/ids.dart';
import 'domain/telemetry_sample.dart';
import 'platform/android_collector.dart';
import 'platform/ios_collector.dart';
import 'platform/telemetry_api.g.dart';

void _log(String msg, [Object? error, StackTrace? stack]) =>
    developer.log(msg, name: 'QoESense', error: error, stackTrace: stack);

AppInfo appInfoOf(TelemetrySample s) => AppInfo(
  deviceModel: s.deviceModel,
  osMajorVersion: s.androidVersion,
  osVersion: s.provenance.osVersion,
  appId: s.provenance.appId,
  appVersion: s.appVersion,
  appBuild: s.provenance.appBuild,
);

/// What differs between the Android and iOS collector engines; the loop itself is shared.
class _CollectorPlatform {
  _CollectorPlatform.android(AndroidCollectorApi api)
    : platform = ClientPlatform.android,
      source = AndroidSampleSource(api),
      presenter = AndroidSurveyPresenter(api),
      answers = AndroidSurveyAnswerQueue(api),
      disable = (() => api.setCollectionEnabled(false)),
      showReminder = api.showUploadReminder,
      lastUploadMs = (() async => (await api.status()).lastUploadMs),
      ios = null;

  _CollectorPlatform.ios(IosCollectorApi api)
    : platform = ClientPlatform.ios,
      source = IosSampleSource(api),
      presenter = IosSurveyPresenter(api),
      answers = IosSurveyAnswerQueue(api),
      disable = (() => api.setCollectionEnabled(false)),
      showReminder = api.showUploadReminder,
      lastUploadMs = (() async => (await api.status()).lastUploadMs),
      ios = api;

  final ClientPlatform platform;
  final SampleSource source;
  final SurveyPresenter presenter;
  final SurveyAnswerQueue answers;
  final Future<void> Function() disable;

  /// Posts the 3-day upload reminder (title, body) as a local notification.
  final Future<void> Function(String, String) showReminder;

  /// The native last-successful-upload time (both platforms keep one).
  final Future<int?> Function() lastUploadMs;

  /// iOS uploads from the collector engine (docs/PHASE4_IOS.md §3).
  final IosCollectorApi? ios;
}

/// Body of the `collectorMain` entrypoint, run in the headless engine of the native
/// collector (the Android CollectorService, or the iOS IosCollectorHost). Runs until the
/// native side destroys the engine.
Future<void> runCollector() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final p = Platform.isIOS
      ? _CollectorPlatform.ios(IosCollectorApi())
      : _CollectorPlatform.android(AndroidCollectorApi());
  final db = QoESenseDatabase.open();
  final kv = DriftKeyValueStore(db);

  if (await kv.read(SettingsKeys.consentGivenAtMs) == null) {
    // Started without consent (e.g. data was cleared but the native flag survived): never collect.
    _log('no consent recorded - stopping collection');
    await p.disable();
    return;
  }

  final buffer = DriftTelemetryBuffer(db);
  final backend = await openBackend();
  MosPipeline? mos;
  final collector = Collector(
    source: p.source,
    rtt: HttpRttProbe(),
    buffer: buffer,
    surveys: SurveyScheduler(store: kv, presenter: p.presenter),
    pathAnomalies: p.platform == ClientPlatform.ios ? PathAnomalyDetector() : null,
    onError: (e, st) => _log('tick failed; continuing next interval', e, st),
    onSample: (s) {
      if (mos != null) return;
      final app = appInfoOf(s);
      // Lets the upload entrypoint build ratings even when the buffer is empty.
      unawaited(
        kv.writeAll({for (final e in appInfoToMap(app).entries) '${SettingsKeys.appInfoPrefix}${e.key}': e.value}),
      );
      mos = MosPipeline(
        answers: p.answers,
        buffer: buffer,
        pending: DriftPendingMosStore(db),
        identity: backend.identity,
        sink: backend.mos,
        app: app,
        platform: p.platform,
      );
    },
  );

  final iosApi = p.ios;
  final uploads = iosApi == null ? null : _IosUploads(iosApi, UploadGate(store: kv), buffer, backend, kv);
  final reminder = UploadReminder(
    store: kv,
    bufferedRows: buffer.count,
    nativeLastUploadMs: p.lastUploadMs,
    show: () {
      final t = reminderTexts();
      return p.showReminder(t.title, t.body);
    },
  );
  CollectorEvents.setUp(_CollectorEvents(collector, uploads));
  _log('collector started on ${p.platform.wireName} (backend configured: ${backend.isConfigured})');
  await collector.run(
    afterTick: () {
      unawaited(mos?.run().catchError((Object e, StackTrace st) => _log('MOS pipeline failed', e, st)));
      if (uploads != null) unawaited(uploads.run());
      unawaited(
        reminder.check().catchError((Object e, StackTrace st) {
          _log('upload reminder failed', e, st);
          return false;
        }),
      );
    },
  );
}

class _CollectorEvents implements CollectorEvents {
  _CollectorEvents(this._collector, this._uploads);
  final Collector _collector;
  final _IosUploads? _uploads;

  @override
  void wakeTick() => _collector.wake();

  @override
  void uploadRequested() {
    final uploads = _uploads;
    if (uploads != null) unawaited(uploads.run(force: true));
  }
}

/// iOS: the 3-hourly drain runs inside the collector engine, gated like Android's WorkManager
/// job (unmetered network, Low Power Mode off), and reports back so a pending BGTask can end.
class _IosUploads {
  _IosUploads(this._api, this._gate, this._buffer, this._backend, this._kv);
  final IosCollectorApi _api;
  final UploadGate _gate;
  final TelemetryBuffer _buffer;
  final Backend _backend;
  final KeyValueStore _kv;

  Future<void> run({bool force = false}) async {
    try {
      final ran = await _gate.maybeRun(
        force: force,
        allowed: _api.uploadConstraintsMet,
        body: () async {
          final r = await drainBuffer(_buffer, _backend, _kv);
          await _api.uploadRunFinished(r.success, r.uploaded);
        },
      );
      // A forced request that couldn't run still has to release a pending BGTask.
      if (force && !ran && !_gate.isRunning) await _api.uploadRunFinished(false, 0);
    } catch (e, st) {
      _log('upload run failed', e, st);
      await _api.uploadRunFinished(false, 0).catchError((Object _) {});
    }
  }
}

/// One upload run: drain, then retention (UploadDrain). Shared by both platforms. Batches
/// use [uploadContractVersion] (v2 on the free Firestore path). A successful run is
/// recorded for the 3-day upload reminder.
Future<({bool success, int uploaded})> drainBuffer(TelemetryBuffer buffer, Backend backend, KeyValueStore kv) async {
  final result = await UploadDrain(
    buffer: buffer,
    identity: backend.identity,
    destination: backend.batches,
    serializer: BatchSerializer(version: uploadContractVersion),
    newBatchId: newUuidV4,
  ).run();
  if (result.outcome == DrainOutcome.success || result.uploadedRows > 0) {
    await kv.write(SettingsKeys.uploadLastSuccessMs, '${DateTime.now().millisecondsSinceEpoch}');
  }
  if (result.purgedRows > 0) _log('retention purged ${result.purgedRows} never-uploaded samples');
  _log('upload run: ${result.outcome.name}, ${result.uploadedRows} rows');
  return (success: result.outcome == DrainOutcome.success, uploaded: result.uploadedRows);
}

/// The reminder text in the phone's language (French or English), from the app's arb files.
({String title, String body}) reminderTexts([Locale? locale]) {
  final code = (locale ?? PlatformDispatcher.instance.locale).languageCode;
  final l = lookupAppLocalizations(Locale(code == 'fr' ? 'fr' : 'en'));
  return (title: l.uploadReminderTitle, body: l.uploadReminderBody);
}

/// Body of the `uploadMain` entrypoint, run in a headless engine by the native Android
/// UploadWorker (WorkManager: every 3 h, Wi-Fi, battery not low). It always reports back
/// through uploadRunFinished so the worker can finish. iOS uploads from the collector engine.
Future<void> runUpload() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final api = AndroidCollectorApi();
  var success = false;
  var uploaded = 0;
  try {
    final db = QoESenseDatabase.open();
    final buffer = DriftTelemetryBuffer(db);
    final kv = DriftKeyValueStore(db);
    final backend = await openBackend();
    final drained = await drainBuffer(buffer, backend, kv);
    success = drained.success;
    uploaded = drained.uploaded;

    // Ratings that couldn't be sent from the collector get another chance on Wi-Fi.
    final app = appInfoFromMap({
      for (final k in const ['deviceModel', 'osMajorVersion', 'osVersion', 'appId', 'appVersion', 'appBuild'])
        k: await kv.read('${SettingsKeys.appInfoPrefix}$k'),
    });
    if (app != null) {
      await MosPipeline(
        answers: AndroidSurveyAnswerQueue(api),
        buffer: buffer,
        pending: DriftPendingMosStore(db),
        identity: backend.identity,
        sink: backend.mos,
        app: app,
        platform: ClientPlatform.android,
      ).run();
    }
  } catch (e, st) {
    _log('upload run failed', e, st);
  } finally {
    await api.uploadRunFinished(success, uploaded);
  }
}

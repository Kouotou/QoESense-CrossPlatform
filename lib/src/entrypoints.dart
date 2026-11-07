import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flutter/widgets.dart';

import 'application/captured_sample.dart';
import 'application/collector.dart';
import 'application/mos_pipeline.dart';
import 'application/settings_keys.dart';
import 'application/survey_scheduler.dart';
import 'application/upload_drain.dart';
import 'data/backend/firebase_backend.dart';
import 'data/local/database.dart';
import 'data/local/drift_stores.dart';
import 'data/network/http_rtt_probe.dart';
import 'domain/enums.dart';
import 'domain/ids.dart';
import 'domain/telemetry_sample.dart';
import 'platform/android_collector.dart';
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

/// Body of the `collectorMain` entrypoint, run in the headless engine of the native
/// CollectorService. Runs until the service destroys the engine.
Future<void> runCollector() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final api = AndroidCollectorApi();
  final db = QoESenseDatabase.open();
  final kv = DriftKeyValueStore(db);

  if (await kv.read(SettingsKeys.consentGivenAtMs) == null) {
    // Started without consent (e.g. data was cleared but the native flag survived): never collect.
    _log('no consent recorded - stopping collection');
    await api.setCollectionEnabled(false);
    return;
  }

  final buffer = DriftTelemetryBuffer(db);
  final backend = await openBackend();
  MosPipeline? mos;
  final collector = Collector(
    source: AndroidSampleSource(api),
    rtt: HttpRttProbe(),
    buffer: buffer,
    surveys: SurveyScheduler(store: kv, presenter: AndroidSurveyPresenter(api)),
    onError: (e, st) => _log('tick failed; continuing next interval', e, st),
    onSample: (s) {
      if (mos != null) return;
      final app = appInfoOf(s);
      // Lets the upload entrypoint build ratings even when the buffer is empty.
      unawaited(
        kv.writeAll({for (final e in appInfoToMap(app).entries) '${SettingsKeys.appInfoPrefix}${e.key}': e.value}),
      );
      mos = MosPipeline(
        answers: AndroidSurveyAnswerQueue(api),
        buffer: buffer,
        pending: DriftPendingMosStore(db),
        identity: backend.identity,
        sink: backend.mos,
        app: app,
        platform: ClientPlatform.android,
      );
    },
  );
  _log('collector started (backend configured: ${backend.isConfigured})');
  await collector.run(
    afterTick: () => unawaited(mos?.run().catchError((Object e, StackTrace st) => _log('MOS pipeline failed', e, st))),
  );
}

/// Body of the `uploadMain` entrypoint, run in a headless engine by the native
/// UploadWorker (WorkManager: hourly, Wi-Fi, battery not low). It always reports back
/// through uploadRunFinished so the worker can finish.
Future<void> runUpload() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final api = AndroidCollectorApi();
  var success = false;
  var uploaded = 0;
  try {
    final db = QoESenseDatabase.open();
    final buffer = DriftTelemetryBuffer(db);
    final backend = await openBackend();
    final result = await UploadDrain(
      buffer: buffer,
      identity: backend.identity,
      destination: backend.batches,
      newBatchId: newUuidV4,
    ).run();
    success = result.outcome == DrainOutcome.success;
    uploaded = result.uploadedRows;
    if (result.purgedRows > 0) _log('retention purged ${result.purgedRows} never-uploaded samples');

    // Ratings that couldn't be sent from the collector get another chance on Wi-Fi.
    final kv = DriftKeyValueStore(db);
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
    _log('upload run: ${result.outcome.name}, $uploaded rows');
  } catch (e, st) {
    _log('upload run failed', e, st);
  } finally {
    await api.uploadRunFinished(success, uploaded);
  }
}

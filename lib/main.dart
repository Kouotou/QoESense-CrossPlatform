import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import 'src/data/backend/firebase_backend.dart';
import 'src/data/local/database.dart';
import 'src/data/local/drift_stores.dart';
import 'src/domain/enums.dart';
import 'src/entrypoints.dart';
import 'src/platform/android_services.dart';
import 'src/platform/capability_source.dart';
import 'src/platform/ios_collector.dart';
import 'src/platform/telemetry_api.g.dart';
import 'src/presentation/app_services.dart';
import 'src/presentation/qoesense_app.dart';

/// UI entrypoint. The UI never collects: on both platforms a headless engine started by
/// native code runs [collectorMain]. Each platform only ever talks to its own channel.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = QoESenseDatabase.open();
  final buffer = DriftTelemetryBuffer(db);
  final backend = await openBackend();
  final AppServices services;
  if (Platform.isIOS) {
    final api = IosCollectorApi();
    services = AppServices(
      capabilities: PlatformChannelCapabilitySource(),
      control: IosCollectorControl(api, buffer),
      permissions: IosPermissionGateway(api),
      buffer: buffer,
      settings: DriftKeyValueStore(db),
      backend: backend,
      platform: ClientPlatform.ios,
      surveyInbox: IosSurveyInbox(api),
    );
  } else {
    services = AppServices(
      capabilities: PlatformChannelCapabilitySource(),
      control: AndroidCollectorControl(AndroidCollectorApi(), buffer),
      permissions: PermissionHandlerGateway(),
      buffer: buffer,
      settings: DriftKeyValueStore(db),
      backend: backend,
    );
  }
  runApp(QoESenseApp(services: services));
}

/// Headless entrypoint started by the native collector (Android CollectorService, iOS
/// IosCollectorHost); docs/ARCHITECTURE.md §4, docs/PHASE4_IOS.md §3.
@pragma('vm:entry-point')
Future<void> collectorMain() => runCollector();

/// Headless entrypoint started by the native Android UploadWorker.
@pragma('vm:entry-point')
Future<void> uploadMain() => runUpload();

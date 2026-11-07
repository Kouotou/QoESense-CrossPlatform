import 'package:flutter/material.dart';

import 'src/data/backend/firebase_backend.dart';
import 'src/data/local/database.dart';
import 'src/data/local/drift_stores.dart';
import 'src/entrypoints.dart';
import 'src/platform/android_services.dart';
import 'src/platform/capability_source.dart';
import 'src/platform/telemetry_api.g.dart';
import 'src/presentation/app_services.dart';
import 'src/presentation/qoesense_app.dart';

/// UI entrypoint.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = QoESenseDatabase.open();
  final buffer = DriftTelemetryBuffer(db);
  runApp(
    QoESenseApp(
      services: AppServices(
        capabilities: PlatformChannelCapabilitySource(),
        control: AndroidCollectorControl(AndroidCollectorApi(), buffer),
        permissions: PermissionHandlerGateway(),
        buffer: buffer,
        settings: DriftKeyValueStore(db),
        backend: await openBackend(),
      ),
    ),
  );
}

/// Headless entrypoint started by the native CollectorService (docs/ARCHITECTURE.md §4).
@pragma('vm:entry-point')
Future<void> collectorMain() => runCollector();

/// Headless entrypoint started by the native UploadWorker.
@pragma('vm:entry-point')
Future<void> uploadMain() => runUpload();

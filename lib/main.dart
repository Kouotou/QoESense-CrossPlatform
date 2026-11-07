import 'package:flutter/material.dart';

import 'src/platform/capability_source.dart';
import 'src/presentation/qoesense_app.dart';

/// UI entrypoint. Phase 3 adds two more `@pragma('vm:entry-point')` entrypoints that run
/// in headless engines started by native code: `collectorMain` (Android foreground service
/// tick / iOS background host) and `uploadMain` (WorkManager / BGTask). See
/// docs/ARCHITECTURE.md sections 4-5.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(QoESenseApp(capabilities: PlatformChannelCapabilitySource()));
}

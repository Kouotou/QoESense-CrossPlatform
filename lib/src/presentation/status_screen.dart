import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../domain/capabilities.dart';
import '../platform/capability_source.dart';

/// Phase 1 status screen: shows the native capability report, group by group.
class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key, required this.capabilities});

  final CapabilitySource capabilities;

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  late final Future<PlatformCapabilities> _report = widget.capabilities.load();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.statusTitle)),
      body: FutureBuilder<PlatformCapabilities>(
        future: _report,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Padding(padding: const EdgeInsets.all(16), child: Text(l10n.statusLoadFailed('${snapshot.error}')));
          }
          final report = snapshot.data;
          if (report == null) return const Center(child: CircularProgressIndicator());
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              ListTile(
                title: Text(l10n.statusIntro),
                subtitle: Text('${report.platform.wireName} ${report.osMajorVersion} · ${report.deviceModel}'),
              ),
              const Divider(),
              for (final group in FieldGroup.values)
                ListTile(
                  key: ValueKey(group),
                  dense: true,
                  leading: _icon(report.of(group)),
                  title: Text(_groupLabel(l10n, group)),
                  subtitle: Text(_availabilityLabel(l10n, report.of(group))),
                ),
            ],
          );
        },
      ),
    );
  }

  static Icon _icon(FieldAvailability a) => switch (a) {
    FieldAvailability.available => const Icon(Icons.check_circle_outline, color: Colors.green),
    FieldAvailability.permissionMissing => const Icon(Icons.lock_outline, color: Colors.orange),
    FieldAvailability.unsupportedOnPlatform => const Icon(Icons.block, color: Colors.grey),
    FieldAvailability.restricted => const Icon(Icons.remove_circle_outline, color: Colors.grey),
  };

  static String _availabilityLabel(AppLocalizations l10n, FieldAvailability a) => switch (a) {
    FieldAvailability.available => l10n.availabilityAvailable,
    FieldAvailability.permissionMissing => l10n.availabilityPermissionMissing,
    FieldAvailability.unsupportedOnPlatform => l10n.availabilityUnsupported,
    FieldAvailability.restricted => l10n.availabilityRestricted,
  };

  static String _groupLabel(AppLocalizations l10n, FieldGroup g) => switch (g) {
    FieldGroup.radioSignal => l10n.groupRadioSignal,
    FieldGroup.cqi => l10n.groupCqi,
    FieldGroup.physicalChannel => l10n.groupPhysicalChannel,
    FieldGroup.radioAccessTechnology => l10n.groupRadioAccessTechnology,
    FieldGroup.connectivity => l10n.groupConnectivity,
    FieldGroup.throughput => l10n.groupThroughput,
    FieldGroup.foregroundApp => l10n.groupForegroundApp,
    FieldGroup.callDetection => l10n.groupCallDetection,
    FieldGroup.location => l10n.groupLocation,
    FieldGroup.backgroundLocation => l10n.groupBackgroundLocation,
    FieldGroup.notifications => l10n.groupNotifications,
    FieldGroup.surveyOverlay => l10n.groupSurveyOverlay,
  };
}

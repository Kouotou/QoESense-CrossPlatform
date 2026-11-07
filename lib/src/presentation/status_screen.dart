import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../domain/capabilities.dart';
import 'app_services.dart';

/// The reference Status screen: collection toggle, buffered count, last upload, anonymous
/// ID, test capture and test survey. It also lists what this phone can measure: the
/// explicit capability report.
class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> with WidgetsBindingObserver {
  late Future<PlatformCapabilities> _report = widget.services.capabilities.load();
  CollectorStatus? _status;
  String? _deviceId;
  String? _message;
  bool _busy = false;

  AppServices get _s => widget.services;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final status = await _s.control.status();
    final id = _s.backend.isConfigured ? await _s.backend.identity.deviceId() : null;
    if (!mounted) return;
    setState(() {
      _status = status;
      _deviceId = id;
      _report = _s.capabilities.load();
    });
  }

  Future<void> _run(Future<String?> Function() action) async {
    setState(() => _busy = true);
    try {
      final msg = await action();
      if (mounted) setState(() => _message = msg);
    } catch (e) {
      if (mounted) setState(() => _message = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
      await _refresh();
    }
  }

  String _lastUpload(AppLocalizations l10n, int? ms) {
    if (ms == null) return l10n.statusLastUploadNever;
    final minutes = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms)).inMinutes;
    if (minutes < 1) return l10n.statusLastUploadJustNow;
    if (minutes < 60) return l10n.statusLastUploadMinutesAgo(minutes);
    return l10n.statusLastUploadHoursAgo(minutes ~/ 60);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final enabled = _status?.enabled ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListTile(title: Text(l10n.statusSubtitle, style: Theme.of(context).textTheme.titleMedium)),
          SwitchListTile(
            key: const ValueKey('collection'),
            title: Text(l10n.statusCollectionTitle),
            subtitle: Text(enabled ? l10n.statusCollectionActiveDesc : l10n.statusCollectionInactiveDesc),
            value: enabled,
            onChanged: _busy
                ? null
                : (v) => _run(() async {
                    await _s.control.setCollectionEnabled(v);
                    return null;
                  }),
          ),
          if (!_s.backend.isConfigured)
            ListTile(leading: const Icon(Icons.cloud_off), title: Text(l10n.statusBackendNotConfigured)),
          StreamBuilder<int>(
            stream: _s.buffer.watchCount(),
            builder: (context, snap) => ListTile(
              title: Text(l10n.statusLabelBufferedSamples),
              trailing: Text('${snap.data ?? '…'}', key: const ValueKey('buffered')),
            ),
          ),
          ListTile(title: Text(l10n.statusLabelLastUpload), trailing: Text(_lastUpload(l10n, _status?.lastUploadMs))),
          ListTile(
            title: Text(l10n.statusLabelAnonymousId),
            subtitle: SelectableText(_deviceId ?? l10n.statusAnonymousIdPending),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  key: const ValueKey('testCapture'),
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                          final s = await _s.control.runTestCapture();
                          return l10n.statusTestCaptureDone(
                            '${s.networkType ?? '-'} · RSRP ${s.rsrp ?? '-'} · RTT ${s.rttMs ?? '-'} ms',
                          );
                        }),
                  child: Text(l10n.statusButtonRunTest),
                ),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                          await _s.control.presentTestSurvey();
                          return l10n.statusTestSurveySent;
                        }),
                  child: Text(l10n.statusButtonSendTestSurvey),
                ),
                OutlinedButton(
                  onPressed: _busy || !_s.backend.isConfigured
                      ? null
                      : () => _run(() async {
                          await _s.control.uploadNow();
                          return null;
                        }),
                  child: Text(l10n.statusUploadNow),
                ),
              ],
            ),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_message!, key: const ValueKey('message')),
            ),
          const Divider(),
          ListTile(title: Text(l10n.statusCapabilitiesTitle, style: Theme.of(context).textTheme.titleMedium)),
          CapabilityList(report: _report),
        ],
      ),
    );
  }
}

/// The capability report, one row per field group.
class CapabilityList extends StatelessWidget {
  const CapabilityList({super.key, required this.report});
  final Future<PlatformCapabilities> report;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<PlatformCapabilities>(
      future: report,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(padding: const EdgeInsets.all(16), child: Text(l10n.statusLoadFailed('${snapshot.error}')));
        }
        final r = snapshot.data;
        if (r == null) return const Center(child: CircularProgressIndicator());
        return Column(
          children: [
            ListTile(
              dense: true,
              title: Text(l10n.statusIntro),
              subtitle: Text('${r.platform.wireName} ${r.osMajorVersion} · ${r.deviceModel}'),
            ),
            for (final g in FieldGroup.values)
              ListTile(
                key: ValueKey(g),
                dense: true,
                leading: _icon(r.of(g)),
                title: Text(_groupLabel(l10n, g)),
                subtitle: Text(_availabilityLabel(l10n, r.of(g))),
              ),
          ],
        );
      },
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

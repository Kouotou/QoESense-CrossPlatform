import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../domain/capabilities.dart';
import 'app_services.dart';

/// The reference app's onboarding flow, in its order, with its text:
/// welcome → consent → location + phone state → background location + notifications →
/// usage access, battery and overlay. Collection starts automatically at the end, as in the
/// reference. Consent is stored locally first (authoritative), and best-effort on the
/// server via [onConsented].
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.services, required this.onConsented, required this.onFinished});

  final AppServices services;
  final Future<void> Function(int timestampMs) onConsented;
  final Future<void> Function() onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with WidgetsBindingObserver {
  int _step = 0;
  PlatformCapabilities? _caps;
  bool _batteryOk = false;

  AppServices get _s => widget.services;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Coming back from a system settings screen re-checks what was granted.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final caps = await _s.capabilities.load();
    final battery = await _s.permissions.isBatteryOptimizationIgnored();
    if (mounted) {
      setState(() {
        _caps = caps;
        _batteryOk = battery;
      });
    }
  }

  void _next() => setState(() => _step++);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (title, body, actions) = switch (_step) {
      0 => (l10n.welcomeTitle, l10n.welcomeBody, [FilledButton(onPressed: _next, child: Text(l10n.welcomeButton))]),
      1 => (
        l10n.consentTitle,
        l10n.consentBody,
        [
          FilledButton(
            key: const ValueKey('consent'),
            onPressed: () async {
              await widget.onConsented(DateTime.now().millisecondsSinceEpoch);
              _next();
            },
            child: Text(l10n.consentButton),
          ),
        ],
      ),
      2 => (
        l10n.locationTitle,
        l10n.locationBody,
        [
          FilledButton(
            onPressed: () async {
              await _s.permissions.requestForeground();
              await _refresh();
              _next();
            },
            child: Text(l10n.locationButtonGrant),
          ),
          TextButton(onPressed: _next, child: Text(l10n.actionSkipForNow)),
        ],
      ),
      3 => (
        l10n.backgroundTitle,
        _caps?.isAvailable(FieldGroup.location) == false
            ? '${l10n.backgroundBody}\n\n${l10n.backgroundHintNoForeground}'
            : l10n.backgroundBody,
        [
          FilledButton(
            onPressed: () async {
              await _s.permissions.requestBackground();
              await _refresh();
              _next();
            },
            child: Text(l10n.backgroundButtonGrant),
          ),
          TextButton(onPressed: _next, child: Text(l10n.actionSkipForNow)),
        ],
      ),
      _ => (
        l10n.usageTitle,
        l10n.usageBody,
        [
          _accessRow(
            _caps?.isAvailable(FieldGroup.foregroundApp) == true,
            l10n.usageAccessStatusGranted,
            l10n.usageAccessStatusNotGranted,
            l10n.usageAccessButton,
            SettingsTarget.usageAccess,
          ),
          _accessRow(
            _batteryOk,
            l10n.batteryStatusGranted,
            l10n.batteryStatusNotGranted,
            l10n.batteryButton,
            SettingsTarget.batteryOptimization,
          ),
          _accessRow(
            _caps?.isAvailable(FieldGroup.surveyOverlay) == true,
            l10n.overlayStatusGranted,
            l10n.overlayStatusNotGranted,
            l10n.overlayButton,
            SettingsTarget.overlay,
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('finish'),
            onPressed: widget.onFinished,
            child: Text(l10n.usageButtonFinish),
          ),
        ],
      ),
    };
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Text(body),
            const SizedBox(height: 24),
            ...actions,
          ],
        ),
      ),
    );
  }

  Widget _accessRow(bool granted, String yes, String no, String button, SettingsTarget target) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(granted ? Icons.check_circle : Icons.radio_button_unchecked, color: granted ? Colors.green : null),
        const SizedBox(width: 8),
        Expanded(child: Text(granted ? yes : no)),
        if (!granted) TextButton(onPressed: () => _s.control.openSettings(target), child: Text(button)),
      ],
    ),
  );
}

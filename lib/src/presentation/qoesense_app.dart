import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../application/settings_keys.dart';
import 'app_services.dart';
import 'onboarding_screen.dart';
import 'status_screen.dart';

/// Root: the onboarding flow until it's finished, then the status screen (reference
/// MainActivity behaviour).
class QoESenseApp extends StatefulWidget {
  const QoESenseApp({super.key, required this.services});
  final AppServices services;

  @override
  State<QoESenseApp> createState() => _QoESenseAppState();
}

class _QoESenseAppState extends State<QoESenseApp> {
  bool? _onboarded;

  AppServices get _s => widget.services;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final done = await _s.settings.read(SettingsKeys.onboardingComplete) == 'true';
    if (mounted) setState(() => _onboarded = done);
  }

  Future<void> _consented(int ms) async {
    // Local first: this is what gates collection (SettingsKeys.consentGivenAtMs).
    await _s.settings.write(SettingsKeys.consentGivenAtMs, '$ms');
    await _s.control.recordConsent(ms);
    // Best-effort server record, as in the reference ConsentRepository.
    final id = await _s.backend.identity.deviceId();
    if (id != null) unawaited(_s.backend.consent.recordConsentGiven(id, ms));
  }

  Future<void> _finished() async {
    await _s.settings.write(SettingsKeys.onboardingComplete, 'true');
    await _s.control.setCollectionEnabled(true); // reference: collection starts after onboarding
    if (mounted) setState(() => _onboarded = true);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(colorSchemeSeed: Colors.indigo),
    darkTheme: ThemeData(colorSchemeSeed: Colors.indigo, brightness: Brightness.dark),
    home: switch (_onboarded) {
      null => const Scaffold(body: Center(child: CircularProgressIndicator())),
      false => OnboardingScreen(services: _s, onConsented: _consented, onFinished: _finished),
      true => StatusScreen(services: _s),
    },
  );
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../application/settings_keys.dart';
import 'app_services.dart';
import 'onboarding_screen.dart';
import 'status_screen.dart';
import 'survey_sheet.dart';

/// Root: the onboarding flow until it's finished, then the status screen (reference
/// MainActivity behaviour).
class QoESenseApp extends StatefulWidget {
  const QoESenseApp({super.key, required this.services});
  final AppServices services;

  @override
  State<QoESenseApp> createState() => _QoESenseAppState();
}

class _QoESenseAppState extends State<QoESenseApp> with WidgetsBindingObserver {
  bool? _onboarded;
  final _navigator = GlobalKey<NavigatorState>();
  StreamSubscription<void>? _surveyTaps;
  bool _sheetOpen = false;

  AppServices get _s => widget.services;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _surveyTaps = _s.surveyInbox?.opened.listen((_) => unawaited(_showOpenedSurvey()));
    unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_surveyTaps?.cancel());
    super.dispose();
  }

  // iOS: a tapped survey notification can arrive before the UI is up, or while it's paused.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_showOpenedSurvey());
  }

  Future<void> _showOpenedSurvey() async {
    final inbox = _s.surveyInbox;
    final context = _navigator.currentContext;
    if (inbox == null || context == null || _sheetOpen || _onboarded != true) return;
    final prompt = await inbox.takeOpened();
    if (prompt == null || !context.mounted) return;
    _sheetOpen = true;
    try {
      await SurveySheet.show(context, prompt, inbox);
    } finally {
      _sheetOpen = false;
    }
  }

  Future<void> _load() async {
    final done = await _s.settings.read(SettingsKeys.onboardingComplete) == 'true';
    if (done) {
      // Safety net: some OEMs (e.g. Infinix/Transsion "AutoStart Limit") block the boot and
      // after-update restarts. Opening the app brings collection back if it should be on.
      final status = await _s.control.status();
      if (status.enabled && !status.running) await _s.control.setCollectionEnabled(true);
    }
    if (mounted) setState(() => _onboarded = done);
    if (done) WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_showOpenedSurvey()));
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
    navigatorKey: _navigator,
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

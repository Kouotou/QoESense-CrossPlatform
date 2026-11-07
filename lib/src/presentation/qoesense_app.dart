import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../platform/capability_source.dart';
import 'status_screen.dart';

class QoESenseApp extends StatelessWidget {
  const QoESenseApp({super.key, required this.capabilities});

  final CapabilitySource capabilities;

  @override
  Widget build(BuildContext context) => MaterialApp(
    onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(colorSchemeSeed: Colors.indigo),
    darkTheme: ThemeData(colorSchemeSeed: Colors.indigo, brightness: Brightness.dark),
    home: StatusScreen(capabilities: capabilities),
  );
}

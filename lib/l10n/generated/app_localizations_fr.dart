// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'QoESense';

  @override
  String get statusTitle => 'Capacités de l\'appareil';

  @override
  String get statusIntro =>
      'Ce que ce téléphone peut mesurer pour l\'étude. Cette version ne collecte encore aucune donnée.';

  @override
  String statusLoadFailed(String error) {
    return 'Impossible de lire les capacités de l\'appareil : $error';
  }

  @override
  String get availabilityAvailable => 'Disponible';

  @override
  String get availabilityPermissionMissing => 'Autorisation requise';

  @override
  String get availabilityUnsupported => 'Impossible sur cette plateforme';

  @override
  String get availabilityRestricted => 'Restreint par le système ou l\'opérateur';

  @override
  String get groupRadioSignal => 'Qualité du signal (RSRP, RSRQ, SINR, avance temporelle, cellule)';

  @override
  String get groupCqi => 'Indicateur de qualité du canal (CQI)';

  @override
  String get groupPhysicalChannel => 'Canal physique (bande passante, numéros de canal)';

  @override
  String get groupRadioAccessTechnology => 'Type de réseau (LTE / 5G)';

  @override
  String get groupConnectivity => 'Type de connexion (Wi-Fi / mobile)';

  @override
  String get groupThroughput => 'Débit';

  @override
  String get groupForegroundApp => 'Application utilisée';

  @override
  String get groupCallDetection => 'Détection d\'appel';

  @override
  String get groupLocation => 'Localisation';

  @override
  String get groupBackgroundLocation => 'Localisation en arrière-plan';

  @override
  String get groupNotifications => 'Notifications';

  @override
  String get groupSurveyOverlay => 'Questionnaire par-dessus les autres applications';
}

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
  String get statusIntro => 'Ce que ce téléphone peut mesurer pour l\'étude en ce moment.';

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

  @override
  String get actionContinue => 'Continuer';

  @override
  String get actionSkipForNow => 'Ignorer pour l\'instant';

  @override
  String get actionGrant => 'Autoriser';

  @override
  String get actionOpenSettings => 'Ouvrir les paramètres';

  @override
  String get permissionGranted => 'Autorisé';

  @override
  String get permissionNotGranted => 'Non autorisé';

  @override
  String get welcomeTitle => 'Étude de recherche QoESense';

  @override
  String get welcomeBody =>
      'Cette application fait partie d\'un projet de recherche de Master (MSc) étudiant la qualité d\'expérience des réseaux mobiles. Fonctionnant discrètement en arrière-plan, elle enregistre des mesures du signal réseau (comme la force et la qualité du signal), la localisation approximative, et quelle application est au premier plan - uniquement pour indiquer *quand* et *dans quelles conditions* une mesure a été prise.\n\nElle ne lit jamais le contenu des messages, l\'historique de navigation, ou quoi que ce soit que vous tapez. Sur les écrans suivants, nous vous demanderons les autorisations dont l\'application a besoin pour fonctionner de manière fiable, en expliquant précisément pourquoi chacune est nécessaire avant de la demander.';

  @override
  String get welcomeButton => 'Commencer';

  @override
  String get consentTitle => 'Consentement à la recherche et confidentialité';

  @override
  String get consentButton => 'J\'accepte, continuer';

  @override
  String get consentBody =>
      'À PROPOS DE CETTE ÉTUDE\n\nQoESense fait partie d\'un projet de recherche de Master (MSc) étudiant comment les conditions du signal réseau affectent l\'expérience réelle des applications, afin qu\'à terme la qualité d\'expérience puisse être prédite directement à partir des données réseau. La participation est entièrement volontaire : vous pouvez arrêter à tout moment en désactivant la collecte dans l\'application ou en la désinstallant, sans aucune conséquence.\n\nCE QUE NOUS COLLECTONS\n\n- Mesures du signal réseau : force et qualité du signal (RSRP, RSRQ, SINR), avance temporelle (timing advance), type de réseau LTE, un identifiant d\'antenne relais haché à sens unique (pas l\'identifiant réel), et, sur certains appareils, des détails supplémentaires sur les canaux.\n- Informations de connexion : Wi-Fi ou données mobiles, statut d\'itinérance (roaming), une estimation du débit et de la latence.\n- Localisation approximative, relevée en même temps que chaque mesure réseau, afin de cartographier la couverture le long de vos trajets habituels.\n- Quelle application est au premier plan, vérifié périodiquement - utilisé uniquement pour détecter si une application de réseau social ou un appel vidéo est actif, afin de pouvoir associer les conditions réseau à ce type d\'usage. Nous ne voyons jamais ce que vous tapez, envoyez ou consultez dans une application.\n- Le modèle de votre appareil, la version d\'Android, et le numéro de version de l\'application elle-même.\n- Vos évaluations occasionnelles de la qualité du réseau (de 1 à 5), lorsque vous répondez à une invite.\n\nCE QUE NOUS NE COLLECTONS JAMAIS\n\nLe contenu des messages, le contenu des appels, l\'historique de navigation, les photos, les contacts, les frappes au clavier, ou tout ce qui est saisi dans une application - cette application n\'a accès à rien de tout cela et ne le demande pas.\n\nCOMMENT VOS DONNÉES SONT IDENTIFIÉES\n\nOn ne vous demande jamais votre nom, votre numéro de téléphone ou votre e-mail. Chaque installation reçoit un identifiant anonyme aléatoire généré par l\'application, et toutes vos données sont liées uniquement à cet identifiant - jamais à vous personnellement. Nous n\'avons aucun moyen de retrouver à qui appartient un identifiant donné à partir des données seules. Votre identifiant anonyme est affiché sur l\'écran d\'état de l\'application si vous avez besoin de le consulter.\n\nOÙ VONT VOS DONNÉES ET COMMENT ELLES SONT PROTÉGÉES\n\nLes données sont envoyées uniquement via Wi-Fi (jamais en utilisant vos données mobiles), chiffrées pendant le transfert, et stockées sur l\'infrastructure Google Firebase/Cloud avec un accès restreint à l\'équipe de recherche. Les données brutes du signal sont mises en attente localement sur votre appareil et ne sont supprimées qu\'une fois l\'envoi confirmé avec succès.\n\nCOMMENT VOS DONNÉES SONT UTILISÉES\n\nVos données seront utilisées pour construire et évaluer plusieurs modèles d\'apprentissage profond (deep learning) permettant de prédire la qualité d\'expérience réseau, dans le cadre d\'un projet de recherche de Master. Des résultats agrégés ou anonymisés pourront être publiés dans des travaux académiques ; les données brutes individuelles ne seront jamais partagées publiquement ni avec des tiers.\n\nAUTORISATIONS SPÉCIALES DEMANDÉES PAR CETTE APPLICATION, ET POURQUOI\n\n- Localisation (au premier plan et en arrière-plan) : exigée par Android lui-même pour renvoyer toute information sur le signal cellulaire, et utilisée pour cartographier la couverture réseau le long de vos trajets.\n- Accès à l\'utilisation (Usage Access) : permet à l\'application de détecter quelle application est au premier plan, pour les raisons décrites ci-dessus - pas pour surveiller votre activité à d\'autres fins.\n- Affichage par-dessus d\'autres applications : permet à l\'invite occasionnelle d\'évaluation de la qualité d\'apparaître immédiatement, afin que votre réponse reste proche dans le temps des conditions réseau concernées, plutôt que de devoir vous souvenir d\'ouvrir l\'application plus tard.\n- Notifications : utilisées uniquement pour un indicateur de statut « collecte active » à faible priorité et pour les invites d\'évaluation de la qualité.\n- Exemption d\'optimisation de la batterie : nécessaire pour que l\'application puisse continuer à collecter les données de manière fiable pendant les semaines que dure l\'étude, car Android suspend autrement agressivement les applications en arrière-plan.\n\nVOS DROITS\n\nLa participation est volontaire. Vous pouvez arrêter la collecte de données à tout moment depuis l\'écran d\'état de l\'application, ou vous retirer complètement en désinstallant l\'application - dans les deux cas, aucune donnée supplémentaire ne sera collectée depuis votre appareil. Pour demander la suppression des données déjà envoyées et liées à votre appareil, contactez bilalkouotou@gmail.com en indiquant votre identifiant anonyme visible sur l\'écran d\'état.\n\nQUESTIONS OU PRÉOCCUPATIONS\n\nCette étude est menée par ENGR. KOUOTOU AHMAD BILAL, de l\'UNIVERSITY OF BUEA, sous l\'approbation DU VICE-CHANCELIER. Contactez bilalkouotou@gmail.com pour toute question.\n\nEn appuyant sur « J\'accepte, continuer » ci-dessous, vous confirmez avoir lu ce document et acceptez volontairement de participer.';

  @override
  String get locationTitle => 'Localisation et informations réseau';

  @override
  String get locationBody =>
      'Android exige l\'autorisation de localisation avant de renvoyer la moindre mesure du signal cellulaire (RSRP, RSRQ, SINR) - il s\'agit d\'une restriction de la plateforme, pas d\'une particularité de cette application. La localisation approximative est aussi utilisée pour cartographier la couverture le long de vos trajets habituels, pour la partie « drive-test » de l\'étude.\n\nNous demandons également l\'accès à l\'état du téléphone, nécessaire sur certaines versions d\'Android pour lire l\'ensemble des informations cellulaires.';

  @override
  String get locationButtonGrant => 'Autoriser les permissions';

  @override
  String get locationHintDenied =>
      'Sans cela, les données de signal et la cartographie des trajets ne peuvent pas être collectées. Vous pouvez l\'autoriser plus tard depuis l\'écran Permissions de l\'application.';

  @override
  String get backgroundTitle => 'Accès en arrière-plan';

  @override
  String get backgroundBody =>
      'Les données doivent être enregistrées même lorsque l\'application n\'est pas ouverte, Android exige donc une autorisation de localisation distincte « Toujours autoriser » pour la collecte en arrière-plan (sur Android 11+, cela peut ouvrir un écran des paramètres système plutôt qu\'une boîte de dialogue - choisissez « Toujours autoriser » à cet endroit).\n\nNous demandons également l\'accès aux notifications, utilisé uniquement pour la notification de statut « collecte active » à faible priorité et pour l\'invite occasionnelle d\'évaluation de la qualité en un clic - jamais pour des publicités ou des alertes sans rapport.';

  @override
  String get backgroundButtonGrant => 'Autoriser l\'accès';

  @override
  String get backgroundHintNoForeground =>
      'La localisation au premier plan n\'a pas été autorisée sur l\'écran précédent, la localisation en arrière-plan ne peut donc pas encore être demandée.';

  @override
  String get usageTitle => 'Accès à l\'utilisation, batterie et pop-ups';

  @override
  String get usageBody =>
      'Pour associer les mesures à l\'application active - en particulier pour détecter une session de réseau social ou d\'appel vidéo à des fins d\'étiquetage de la qualité - l\'application a besoin de l\'Accès à l\'utilisation. Il s\'agit d\'un paramètre protégé par le système, Android vous emmènera donc vers un écran des paramètres où vous pourrez trouver « QoESense » et l\'activer.\n\nNous vous demandons également d\'exempter l\'application de l\'optimisation de la batterie, car Android suspend sinon agressivement les applications en arrière-plan, ce qui créerait des lacunes de données manquantes pendant les semaines que dure l\'étude.\n\nEnfin, « affichage par-dessus d\'autres applications » permet à l\'évaluation occasionnelle de la qualité en un clic d\'apparaître exactement au bon moment, par-dessus l\'application que vous utilisez à ce moment-là, plutôt que de s\'afficher uniquement sous forme de notification que vous devriez ouvrir vous-même. Elle disparaît d\'elle-même au bout de quelques secondes dans tous les cas.';

  @override
  String get usageButtonFinish => 'Terminer la configuration';

  @override
  String get usageAccessStatusGranted => 'Accès à l\'utilisation : autorisé';

  @override
  String get usageAccessStatusNotGranted => 'Accès à l\'utilisation : non autorisé';

  @override
  String get usageAccessButton => 'Ouvrir les paramètres d\'accès à l\'utilisation';

  @override
  String get batteryStatusGranted => 'Optimisation de la batterie : désactivée (bien)';

  @override
  String get batteryStatusNotGranted => 'Optimisation de la batterie : activée';

  @override
  String get batteryButton => 'Désactiver l\'optimisation de la batterie';

  @override
  String get overlayStatusGranted => 'Affichage par-dessus d\'autres applications : autorisé';

  @override
  String get overlayStatusNotGranted => 'Affichage par-dessus d\'autres applications : non autorisé';

  @override
  String get overlayButton => 'Autoriser l\'affichage par-dessus d\'autres applications';

  @override
  String get statusSubtitle => 'État de la collecte en arrière-plan';

  @override
  String get statusCollectionTitle => 'Collecte';

  @override
  String get statusCollectionInactiveDesc =>
      'La collecte en arrière-plan est désactivée. Elle démarre normalement automatiquement après la configuration initiale - ce bouton sert surtout aux tests.';

  @override
  String get statusLabelBufferedSamples => 'Échantillons en mémoire tampon';

  @override
  String get statusLabelLastUpload => 'Dernier envoi';

  @override
  String get statusLabelAnonymousId => 'Votre identifiant anonyme';

  @override
  String get statusButtonStopCollection => 'Arrêter la collecte en arrière-plan';

  @override
  String get statusButtonStartCollection => 'Démarrer la collecte en arrière-plan';

  @override
  String get statusButtonRunTest => 'Lancer un test de télémétrie';

  @override
  String get statusButtonSendTestSurvey => 'Envoyer un sondage MOS de test';

  @override
  String get statusPermissionsTitle => 'Permissions et accès';

  @override
  String get statusPermissionLocation => 'Localisation';

  @override
  String get statusPermissionBackgroundLocation => 'Localisation en arrière-plan';

  @override
  String get statusPermissionNotifications => 'Notifications';

  @override
  String get statusPermissionPhoneState => 'État du téléphone';

  @override
  String get statusPermissionUsageAccess => 'Accès à l\'utilisation';

  @override
  String get statusPermissionBattery => 'Optimisation de la batterie désactivée';

  @override
  String get statusPermissionOverlay => 'Affichage par-dessus d\'autres applications';

  @override
  String get statusLastUploadNever => 'jamais';

  @override
  String get statusLastUploadJustNow => 'à l\'instant';

  @override
  String statusLastUploadMinutesAgo(int count) {
    return 'il y a $count min';
  }

  @override
  String statusLastUploadHoursAgo(int count) {
    return 'il y a ${count}h';
  }

  @override
  String get statusCollectionActiveDesc =>
      'Le service en arrière-plan effectue une mesure toutes les ~60 s (toutes les ~15 s pendant un appel vidéo). Les données restent sur ce téléphone jusqu\'à ce qu\'un envoi via Wi-Fi soit confirmé.';

  @override
  String get statusBackendNotConfigured =>
      'Les envois ne sont pas encore configurés dans cette version : toutes les données restent en sécurité sur ce téléphone.';

  @override
  String get statusUploadNow => 'Envoyer maintenant (Wi-Fi)';

  @override
  String statusTestCaptureDone(String summary) {
    return 'Mesure de test enregistrée : $summary';
  }

  @override
  String get statusTestSurveySent => 'Questionnaire de test affiché.';

  @override
  String get statusCapabilitiesTitle => 'Ce que ce téléphone peut mesurer';

  @override
  String get statusAnonymousIdPending => 'pas encore attribué';

  @override
  String get onboardingPermissionsTitle => 'Autorisations';
}

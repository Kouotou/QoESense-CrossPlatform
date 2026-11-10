import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en'), Locale('fr')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'QoESense'**
  String get appTitle;

  /// No description provided for @statusTitle.
  ///
  /// In en, this message translates to:
  /// **'Device capabilities'**
  String get statusTitle;

  /// No description provided for @statusIntro.
  ///
  /// In en, this message translates to:
  /// **'What this phone can measure for the study right now.'**
  String get statusIntro;

  /// No description provided for @statusLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read device capabilities: {error}'**
  String statusLoadFailed(String error);

  /// No description provided for @availabilityAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get availabilityAvailable;

  /// No description provided for @availabilityPermissionMissing.
  ///
  /// In en, this message translates to:
  /// **'Permission needed'**
  String get availabilityPermissionMissing;

  /// No description provided for @availabilityUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Not possible on this platform'**
  String get availabilityUnsupported;

  /// No description provided for @availabilityRestricted.
  ///
  /// In en, this message translates to:
  /// **'Restricted by the system or carrier'**
  String get availabilityRestricted;

  /// No description provided for @groupRadioSignal.
  ///
  /// In en, this message translates to:
  /// **'Signal quality (RSRP, RSRQ, SINR, timing advance, cell)'**
  String get groupRadioSignal;

  /// No description provided for @groupCqi.
  ///
  /// In en, this message translates to:
  /// **'Channel quality indicator (CQI)'**
  String get groupCqi;

  /// No description provided for @groupPhysicalChannel.
  ///
  /// In en, this message translates to:
  /// **'Physical channel (bandwidth, channel numbers)'**
  String get groupPhysicalChannel;

  /// No description provided for @groupRadioAccessTechnology.
  ///
  /// In en, this message translates to:
  /// **'Network type (LTE / 5G)'**
  String get groupRadioAccessTechnology;

  /// No description provided for @groupConnectivity.
  ///
  /// In en, this message translates to:
  /// **'Connection type (Wi-Fi / mobile)'**
  String get groupConnectivity;

  /// No description provided for @groupThroughput.
  ///
  /// In en, this message translates to:
  /// **'Throughput'**
  String get groupThroughput;

  /// No description provided for @groupForegroundApp.
  ///
  /// In en, this message translates to:
  /// **'App in use'**
  String get groupForegroundApp;

  /// No description provided for @groupCallDetection.
  ///
  /// In en, this message translates to:
  /// **'Call detection'**
  String get groupCallDetection;

  /// No description provided for @groupLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get groupLocation;

  /// No description provided for @groupBackgroundLocation.
  ///
  /// In en, this message translates to:
  /// **'Location in the background'**
  String get groupBackgroundLocation;

  /// No description provided for @groupNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get groupNotifications;

  /// No description provided for @groupSurveyOverlay.
  ///
  /// In en, this message translates to:
  /// **'Survey over other apps'**
  String get groupSurveyOverlay;

  /// No description provided for @actionContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get actionContinue;

  /// No description provided for @actionSkipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get actionSkipForNow;

  /// No description provided for @actionGrant.
  ///
  /// In en, this message translates to:
  /// **'Grant'**
  String get actionGrant;

  /// No description provided for @actionOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get actionOpenSettings;

  /// No description provided for @permissionGranted.
  ///
  /// In en, this message translates to:
  /// **'Granted'**
  String get permissionGranted;

  /// No description provided for @permissionNotGranted.
  ///
  /// In en, this message translates to:
  /// **'Not granted'**
  String get permissionNotGranted;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'QoESense research study'**
  String get welcomeTitle;

  /// No description provided for @welcomeBody.
  ///
  /// In en, this message translates to:
  /// **'This app is part of an MSc research project studying mobile network quality of experience. Running quietly in the background, it records network signal metrics (like signal strength and quality), approximate location, and which app is in the foreground - only to tag *when* and *under what conditions* a measurement was taken.\n\nIt never reads message content, browsing history, or anything you type. Over the next few screens we\'ll ask for the permissions the app needs to do this reliably, and explain exactly why each one is needed before asking.'**
  String get welcomeBody;

  /// No description provided for @welcomeButton.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get welcomeButton;

  /// No description provided for @consentTitle.
  ///
  /// In en, this message translates to:
  /// **'Research consent & privacy'**
  String get consentTitle;

  /// No description provided for @consentButton.
  ///
  /// In en, this message translates to:
  /// **'I agree, continue'**
  String get consentButton;

  /// No description provided for @consentBody.
  ///
  /// In en, this message translates to:
  /// **'ABOUT THIS STUDY\n\nQoESense is part of an MSc research project studying how network signal conditions affect real-world app experience, so that quality of experience can eventually be predicted directly from network data. Participation is completely voluntary: you can stop at any time by disabling collection in the app or uninstalling it, with no consequences.\n\nWHAT WE COLLECT\n\n- Network signal metrics: signal strength and quality (RSRP, RSRQ, SINR), timing advance, network type LTE, a one-way hashed cell tower identifier (not the real ID), and, on some devices, additional channel details.\n- Connection info: Wi-Fi vs. cellular, roaming status, an estimate of throughput and latency.\n- Approximate location, sampled alongside each network reading, to map coverage along your usual routes.\n- Which app is in the foreground, checked periodically - used only to detect whether a social-media app or a video call is active, so we can tag the network conditions during that kind of use. We never see what you typed, sent, or viewed inside any app.\n- Your device model, Android version, and the app\'s own version number.\n- Your occasional 1-5 star ratings of network quality, when you respond to a prompt.\n\nWHAT WE NEVER COLLECT\n\nMessage content, call content, browsing history, photos, contacts, keystrokes, or anything typed into any app - this app has no access to and does not request any of that.\n\nHOW YOUR DATA IS IDENTIFIED\n\nYou are never asked for your name, phone number, or email. Each install gets a random anonymous ID generated by the app, and all your data is tied only to that ID - not to you personally. We have no way to look up who a given ID belongs to from the data alone. Your anonymous ID is shown on the app\'s Status screen if you ever need to reference it.\n\nWHERE YOUR DATA GOES AND HOW IT\'S PROTECTED\n\nData is uploaded only over Wi-Fi (never using your mobile data), encrypted in transit, and stored on Google Firebase/Cloud infrastructure with access restricted to the research team. Raw signal data is queued locally on your device and only deleted once a successful upload is confirmed.\n\nHOW YOUR DATA IS USED\n\nYour data will be used to build and evaluate multiple deep learning models for predicting network quality of experience, as part of an MSc research project. Aggregated or de-identified results may be published in academic work; individual raw data will not be shared publicly or with third parties.\n\nSPECIAL PERMISSIONS THIS APP ASKS FOR, AND WHY\n\n- Location (foreground and background): required by Android itself to return any cell signal information, and used to map network coverage along your routes.\n- Usage Access: lets the app detect which app is in the foreground, for the purposes described above - not to monitor your activity for any other reason.\n- Display over other apps: lets the occasional quality-rating prompt appear right away, so your answer stays close in time to the network conditions it\'s about, rather than needing you to remember to open the app later.\n- Notifications: used only for a low-priority \"collection active\" status indicator and the quality-rating prompts.\n- Battery optimization exemption: needed so the app can keep collecting reliably over the weeks-long study, since Android aggressively suspends background apps otherwise.\n\nYOUR RIGHTS\n\nParticipation is voluntary. You can stop data collection at any time from the app\'s Status screen, or withdraw completely by uninstalling the app - either way, no further data will be collected from your device. To request that already-uploaded data tied to your device be deleted, contact bilalkouotou@gmail.com with your anonymous device ID from the Status screen.\n\nQUESTIONS OR CONCERNS\n\nThis study is conducted by ENGR. KOUOTOU AHMAD BILAL, from the UNIVERSITY OF BUEA, under THE VICE CHANCELORS\' approval. Contact bilalkouotou@gmail.com with any questions.\n\nBy tapping \"I agree, continue\" below, you confirm you\'ve read this and voluntarily agree to participate.'**
  String get consentBody;

  /// No description provided for @locationTitle.
  ///
  /// In en, this message translates to:
  /// **'Location & network info'**
  String get locationTitle;

  /// No description provided for @locationBody.
  ///
  /// In en, this message translates to:
  /// **'Android requires location permission before it will return cell signal readings (RSRP, RSRQ, SINR) at all - this is a platform restriction, not something specific to this app. Approximate location is also used to map coverage along your usual routes for the drive-test portion of the study.\n\nWe also request phone-state access, needed on some Android versions to read full cell information.'**
  String get locationBody;

  /// No description provided for @locationButtonGrant.
  ///
  /// In en, this message translates to:
  /// **'Grant permissions'**
  String get locationButtonGrant;

  /// No description provided for @locationHintDenied.
  ///
  /// In en, this message translates to:
  /// **'Without this, signal telemetry and route mapping cannot be collected. You can grant it later from the app\'s Permissions screen.'**
  String get locationHintDenied;

  /// No description provided for @backgroundTitle.
  ///
  /// In en, this message translates to:
  /// **'Background access'**
  String get backgroundTitle;

  /// No description provided for @backgroundBody.
  ///
  /// In en, this message translates to:
  /// **'Telemetry needs to be recorded while the app isn\'t open, so Android requires a separate \"Allow all the time\" location grant for background collection (on Android 11+ this may open a system Settings screen rather than a dialog - choose \"Allow all the time\" there).\n\nWe also ask for notification access, used only for the low-priority \"collection active\" status notification and the occasional one-tap quality rating prompt - never for ads or unrelated alerts.'**
  String get backgroundBody;

  /// No description provided for @backgroundButtonGrant.
  ///
  /// In en, this message translates to:
  /// **'Grant access'**
  String get backgroundButtonGrant;

  /// No description provided for @backgroundHintNoForeground.
  ///
  /// In en, this message translates to:
  /// **'Foreground location wasn\'t granted on the previous screen, so background location can\'t be requested yet.'**
  String get backgroundHintNoForeground;

  /// No description provided for @usageTitle.
  ///
  /// In en, this message translates to:
  /// **'Usage access, battery & pop-ups'**
  String get usageTitle;

  /// No description provided for @usageBody.
  ///
  /// In en, this message translates to:
  /// **'To tag measurements with which app is active - specifically to detect a social-media or video-call session for quality labelling - the app needs Usage Access. This is a system-protected setting, so Android will take you to a Settings screen where you can find \"QoESense\" and turn it on.\n\nWe also ask you to exempt the app from battery optimization, since Android aggressively suspends background apps otherwise, which would create gaps of missing data over the weeks-long study.\n\nFinally, \"display over other apps\" lets the occasional one-tap quality rating pop up right when it\'s relevant, over whatever app you\'re using at the time, instead of only showing as a notification you\'d have to open yourself. It disappears on its own within a few seconds either way.'**
  String get usageBody;

  /// No description provided for @usageButtonFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish setup'**
  String get usageButtonFinish;

  /// No description provided for @usageAccessStatusGranted.
  ///
  /// In en, this message translates to:
  /// **'Usage access: granted'**
  String get usageAccessStatusGranted;

  /// No description provided for @usageAccessStatusNotGranted.
  ///
  /// In en, this message translates to:
  /// **'Usage access: not granted'**
  String get usageAccessStatusNotGranted;

  /// No description provided for @usageAccessButton.
  ///
  /// In en, this message translates to:
  /// **'Open Usage Access settings'**
  String get usageAccessButton;

  /// No description provided for @batteryStatusGranted.
  ///
  /// In en, this message translates to:
  /// **'Battery optimization: disabled (good)'**
  String get batteryStatusGranted;

  /// No description provided for @batteryStatusNotGranted.
  ///
  /// In en, this message translates to:
  /// **'Battery optimization: enabled'**
  String get batteryStatusNotGranted;

  /// No description provided for @batteryButton.
  ///
  /// In en, this message translates to:
  /// **'Disable battery optimization'**
  String get batteryButton;

  /// No description provided for @overlayStatusGranted.
  ///
  /// In en, this message translates to:
  /// **'Display over other apps: granted'**
  String get overlayStatusGranted;

  /// No description provided for @overlayStatusNotGranted.
  ///
  /// In en, this message translates to:
  /// **'Display over other apps: not granted'**
  String get overlayStatusNotGranted;

  /// No description provided for @overlayButton.
  ///
  /// In en, this message translates to:
  /// **'Allow display over other apps'**
  String get overlayButton;

  /// No description provided for @statusSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Background collection status'**
  String get statusSubtitle;

  /// No description provided for @statusCollectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get statusCollectionTitle;

  /// No description provided for @statusCollectionInactiveDesc.
  ///
  /// In en, this message translates to:
  /// **'Background collection is off. It normally starts automatically after onboarding - this toggle is mainly for testing.'**
  String get statusCollectionInactiveDesc;

  /// No description provided for @statusLabelBufferedSamples.
  ///
  /// In en, this message translates to:
  /// **'Buffered samples'**
  String get statusLabelBufferedSamples;

  /// No description provided for @statusLabelLastUpload.
  ///
  /// In en, this message translates to:
  /// **'Last upload'**
  String get statusLabelLastUpload;

  /// No description provided for @statusLabelAnonymousId.
  ///
  /// In en, this message translates to:
  /// **'Your anonymous ID'**
  String get statusLabelAnonymousId;

  /// No description provided for @statusButtonStopCollection.
  ///
  /// In en, this message translates to:
  /// **'Stop background collection'**
  String get statusButtonStopCollection;

  /// No description provided for @statusButtonStartCollection.
  ///
  /// In en, this message translates to:
  /// **'Start background collection'**
  String get statusButtonStartCollection;

  /// No description provided for @statusButtonRunTest.
  ///
  /// In en, this message translates to:
  /// **'Run telemetry test'**
  String get statusButtonRunTest;

  /// No description provided for @statusButtonSendTestSurvey.
  ///
  /// In en, this message translates to:
  /// **'Send test MOS survey'**
  String get statusButtonSendTestSurvey;

  /// No description provided for @statusPermissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Permissions & access'**
  String get statusPermissionsTitle;

  /// No description provided for @statusPermissionLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get statusPermissionLocation;

  /// No description provided for @statusPermissionBackgroundLocation.
  ///
  /// In en, this message translates to:
  /// **'Background location'**
  String get statusPermissionBackgroundLocation;

  /// No description provided for @statusPermissionNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get statusPermissionNotifications;

  /// No description provided for @statusPermissionPhoneState.
  ///
  /// In en, this message translates to:
  /// **'Phone state'**
  String get statusPermissionPhoneState;

  /// No description provided for @statusPermissionUsageAccess.
  ///
  /// In en, this message translates to:
  /// **'Usage access'**
  String get statusPermissionUsageAccess;

  /// No description provided for @statusPermissionBattery.
  ///
  /// In en, this message translates to:
  /// **'Battery optimization disabled'**
  String get statusPermissionBattery;

  /// No description provided for @statusPermissionOverlay.
  ///
  /// In en, this message translates to:
  /// **'Display over other apps'**
  String get statusPermissionOverlay;

  /// No description provided for @statusLastUploadNever.
  ///
  /// In en, this message translates to:
  /// **'never'**
  String get statusLastUploadNever;

  /// No description provided for @statusLastUploadJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get statusLastUploadJustNow;

  /// No description provided for @statusLastUploadMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String statusLastUploadMinutesAgo(int count);

  /// No description provided for @statusLastUploadHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String statusLastUploadHoursAgo(int count);

  /// No description provided for @statusCollectionActiveDesc.
  ///
  /// In en, this message translates to:
  /// **'The background service samples every ~60 s (every ~15 s during a video call). Data stays on this phone until a Wi-Fi upload is confirmed.'**
  String get statusCollectionActiveDesc;

  /// No description provided for @statusBackendNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Uploads aren\'t set up in this build yet, so all data stays safely on this phone.'**
  String get statusBackendNotConfigured;

  /// No description provided for @statusUploadNow.
  ///
  /// In en, this message translates to:
  /// **'Upload now (Wi-Fi)'**
  String get statusUploadNow;

  /// No description provided for @statusTestCaptureDone.
  ///
  /// In en, this message translates to:
  /// **'Test capture saved: {summary}'**
  String statusTestCaptureDone(String summary);

  /// No description provided for @statusTestSurveySent.
  ///
  /// In en, this message translates to:
  /// **'Test survey shown.'**
  String get statusTestSurveySent;

  /// No description provided for @statusCapabilitiesTitle.
  ///
  /// In en, this message translates to:
  /// **'What this phone can measure'**
  String get statusCapabilitiesTitle;

  /// No description provided for @statusAnonymousIdPending.
  ///
  /// In en, this message translates to:
  /// **'not assigned yet'**
  String get statusAnonymousIdPending;

  /// No description provided for @onboardingPermissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get onboardingPermissionsTitle;

  /// DRAFT iOS variant, pending the owner's approval before any iOS participant (docs/PHASE4_MAC_HANDOFF.md §3.4).
  ///
  /// In en, this message translates to:
  /// **'This app is part of an MSc research project studying mobile network quality of experience. Running quietly in the background, it records the network type and connection quality that iOS makes available, approximate location, and whether a call is in progress - only to tag *when* and *under what conditions* a measurement was taken.\n\nIt never reads message content, browsing history, or anything you type. Over the next few screens we\'ll ask for the permissions the app needs, and explain exactly why each one is needed before asking.'**
  String get welcomeBodyIos;

  /// DRAFT iOS variant, pending the owner's approval before any iOS participant (docs/PHASE4_MAC_HANDOFF.md §3.4).
  ///
  /// In en, this message translates to:
  /// **'ABOUT THIS STUDY\n\nQoESense is part of an MSc research project studying how network signal conditions affect real-world app experience, so that quality of experience can eventually be predicted directly from network data. Participation is completely voluntary: you can stop at any time by disabling collection in the app or uninstalling it, with no consequences.\n\nWHAT WE COLLECT ON AN IPHONE\n\n- Network type: whether your iPhone is on 4G (LTE), 5G or an older network, as reported by iOS.\n- Connection info: Wi-Fi vs. cellular, and an estimate of throughput and latency (the time a small test request takes).\n- Approximate location, sampled alongside each network reading, to map coverage along your usual routes.\n- Whether a phone or internet call (for example WhatsApp or FaceTime) is in progress. iOS only tells the app that some call is active - never with whom, through which app, or anything said.\n- Your device model, iOS version, and the app\'s own version number.\n- Your occasional 1-5 star ratings of network quality and, if you choose to answer, what you were doing at the time (for example \"WhatsApp call\").\n\nWHAT AN IPHONE DOES NOT LET US COLLECT\n\niOS does not give apps the signal strength and quality figures (RSRP, RSRQ, SINR), the cell tower identifier, the roaming status, or which app you are using. This app therefore does not collect them on an iPhone, and never estimates them.\n\nWHAT WE NEVER COLLECT\n\nMessage content, call content, browsing history, photos, contacts, keystrokes, or anything typed into any app - this app has no access to and does not request any of that.\n\nHOW YOUR DATA IS IDENTIFIED\n\nYou are never asked for your name, phone number, or email. Each install gets a random anonymous ID generated by the app, and all your data is tied only to that ID - not to you personally. We have no way to look up who a given ID belongs to from the data alone. Your anonymous ID is shown on the app\'s Status screen if you ever need to reference it.\n\nWHERE YOUR DATA GOES AND HOW IT\'S PROTECTED\n\nData is uploaded only over Wi-Fi (never using your mobile data, a personal hotspot or Low Data Mode), encrypted in transit, and stored on Google Firebase/Cloud infrastructure with access restricted to the research team. Raw data is queued locally on your iPhone and only deleted once a successful upload is confirmed.\n\nHOW YOUR DATA IS USED\n\nYour data will be used to build and evaluate multiple deep learning models for predicting network quality of experience, as part of an MSc research project. Aggregated or de-identified results may be published in academic work; individual raw data will not be shared publicly or with third parties.\n\nPERMISSIONS THIS APP ASKS FOR, AND WHY\n\n- Location (\"While Using the App\", then \"Always\"): used to map network coverage along your routes, and the only way iOS allows an app to keep measuring in the background. While the app collects in the background, iOS shows a location indicator in the status bar.\n- Notifications: used only for the occasional quality-rating prompts, which you can answer directly from the notification.\n\nCOLLECTION ON AN IPHONE HAS GAPS\n\niOS decides when apps may run. Collection can pause - for example if you close the app from the app switcher, turn off its location access, or when iOS stops it to save battery or memory - and resumes when you open the app again or iOS restarts it. Missing periods are kept as gaps: nothing is filled in or estimated.\n\nYOUR RIGHTS\n\nParticipation is voluntary. You can stop data collection at any time from the app\'s Status screen, or withdraw completely by deleting the app - either way, no further data will be collected from your device. To request that already-uploaded data tied to your device be deleted, contact bilalkouotou@gmail.com with your anonymous device ID from the Status screen.\n\nQUESTIONS OR CONCERNS\n\nThis study is conducted by ENGR. KOUOTOU AHMAD BILAL, from the UNIVERSITY OF BUEA, under THE VICE CHANCELORS\' approval. Contact bilalkouotou@gmail.com with any questions.\n\nBy tapping \"I agree, continue\" below, you confirm you\'ve read this and voluntarily agree to participate.'**
  String get consentBodyIos;

  /// DRAFT iOS variant, pending the owner's approval before any iOS participant (docs/PHASE4_MAC_HANDOFF.md §3.4).
  ///
  /// In en, this message translates to:
  /// **'Approximate location is recorded with each network measurement, to map network quality along your usual routes for the study.\n\niOS will first ask whether to allow location \"While Using the App\" - please choose that option.'**
  String get locationBodyIos;

  /// DRAFT iOS variant, pending the owner's approval before any iOS participant (docs/PHASE4_MAC_HANDOFF.md §3.4).
  ///
  /// In en, this message translates to:
  /// **'To keep measuring while you use other apps or the screen is off, the app needs location access \"Always\". iOS will ask whether to change to \"Always Allow\" - please accept. If the question doesn\'t appear, you can change it later in Settings > QoESense > Location.\n\nWe also ask to send notifications, used only for the occasional quality rating prompt - never for ads or unrelated alerts.'**
  String get backgroundBodyIos;

  /// No description provided for @iosFinishTitle.
  ///
  /// In en, this message translates to:
  /// **'Keeping collection running'**
  String get iosFinishTitle;

  /// DRAFT iOS variant, pending the owner's approval before any iOS participant (docs/PHASE4_MAC_HANDOFF.md §3.4).
  ///
  /// In en, this message translates to:
  /// **'iOS only lets the app measure in the background while its location access is \"Always\". To answer a rating prompt, touch and hold the notification and pick 1-5, or tap it to open the app.\n\nPlease don\'t close QoESense from the app switcher: iOS may then stop collecting until you open the app again. Gaps are kept as missing time, never filled in.'**
  String get iosFinishBody;

  /// No description provided for @iosAlwaysLocationGranted.
  ///
  /// In en, this message translates to:
  /// **'Location \"Always\": granted'**
  String get iosAlwaysLocationGranted;

  /// No description provided for @iosAlwaysLocationNotGranted.
  ///
  /// In en, this message translates to:
  /// **'Location \"Always\": not granted'**
  String get iosAlwaysLocationNotGranted;

  /// No description provided for @iosNotificationsGranted.
  ///
  /// In en, this message translates to:
  /// **'Notifications: allowed'**
  String get iosNotificationsGranted;

  /// No description provided for @iosNotificationsNotGranted.
  ///
  /// In en, this message translates to:
  /// **'Notifications: not allowed'**
  String get iosNotificationsNotGranted;

  /// No description provided for @iosOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get iosOpenSettings;

  /// No description provided for @surveyTitle.
  ///
  /// In en, this message translates to:
  /// **'How was your network experience just now?'**
  String get surveyTitle;

  /// No description provided for @surveyCaption.
  ///
  /// In en, this message translates to:
  /// **'1 = very poor, 5 = excellent'**
  String get surveyCaption;

  /// No description provided for @surveyContextQuestion.
  ///
  /// In en, this message translates to:
  /// **'What were you doing? (optional)'**
  String get surveyContextQuestion;

  /// No description provided for @surveyContextWhatsappCall.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp call'**
  String get surveyContextWhatsappCall;

  /// No description provided for @surveyContextWhatsappChat.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp messages or status'**
  String get surveyContextWhatsappChat;

  /// No description provided for @surveyContextFacebook.
  ///
  /// In en, this message translates to:
  /// **'Facebook'**
  String get surveyContextFacebook;

  /// No description provided for @surveyContextInstagram.
  ///
  /// In en, this message translates to:
  /// **'Instagram'**
  String get surveyContextInstagram;

  /// No description provided for @surveyContextZoom.
  ///
  /// In en, this message translates to:
  /// **'Zoom'**
  String get surveyContextZoom;

  /// No description provided for @surveyContextGoogleMeet.
  ///
  /// In en, this message translates to:
  /// **'Google Meet'**
  String get surveyContextGoogleMeet;

  /// No description provided for @surveyContextSomethingElse.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get surveyContextSomethingElse;

  /// No description provided for @surveySubmit.
  ///
  /// In en, this message translates to:
  /// **'Send rating'**
  String get surveySubmit;

  /// No description provided for @surveyNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get surveyNotNow;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

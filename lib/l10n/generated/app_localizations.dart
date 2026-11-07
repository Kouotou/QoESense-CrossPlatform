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
  /// **'What this phone can measure for the study. Nothing is collected yet in this build.'**
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

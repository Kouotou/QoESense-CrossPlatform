// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'QoESense';

  @override
  String get statusTitle => 'Device capabilities';

  @override
  String get statusIntro => 'What this phone can measure for the study. Nothing is collected yet in this build.';

  @override
  String statusLoadFailed(String error) {
    return 'Could not read device capabilities: $error';
  }

  @override
  String get availabilityAvailable => 'Available';

  @override
  String get availabilityPermissionMissing => 'Permission needed';

  @override
  String get availabilityUnsupported => 'Not possible on this platform';

  @override
  String get availabilityRestricted => 'Restricted by the system or carrier';

  @override
  String get groupRadioSignal => 'Signal quality (RSRP, RSRQ, SINR, timing advance, cell)';

  @override
  String get groupCqi => 'Channel quality indicator (CQI)';

  @override
  String get groupPhysicalChannel => 'Physical channel (bandwidth, channel numbers)';

  @override
  String get groupRadioAccessTechnology => 'Network type (LTE / 5G)';

  @override
  String get groupConnectivity => 'Connection type (Wi-Fi / mobile)';

  @override
  String get groupThroughput => 'Throughput';

  @override
  String get groupForegroundApp => 'App in use';

  @override
  String get groupCallDetection => 'Call detection';

  @override
  String get groupLocation => 'Location';

  @override
  String get groupBackgroundLocation => 'Location in the background';

  @override
  String get groupNotifications => 'Notifications';

  @override
  String get groupSurveyOverlay => 'Survey over other apps';
}

import '../domain/enums.dart';
import 'mos_pipeline.dart';

/// The answers to the iOS "what were you doing?" question (decision D-6). iOS can't observe
/// the foreground app, so the participant says it. Each answer maps to the **Android package
/// name** and session category the Android app would have observed for that app (the
/// MonitoredApps lists in android/.../ContextSamplers.kt), so both platforms share one set of
/// values. `contextSource = SELF_REPORTED` tells the two apart in the data.
enum SelfReportOption {
  whatsappCall('com.whatsapp', AppSessionType.videoConferencing),
  whatsappChat('com.whatsapp', AppSessionType.socialMedia),
  facebook('com.facebook.katana', AppSessionType.socialMedia),
  instagram('com.instagram.android', AppSessionType.socialMedia),
  zoom('us.zoom.videomeetings', AppSessionType.videoConferencing),
  googleMeet('com.google.android.apps.meetings', AppSessionType.videoConferencing),

  /// Something the study doesn't monitor (another app, a phone call, browsing...).
  somethingElse(null, AppSessionType.none);

  const SelfReportOption(this.androidPackage, this.sessionType);

  final String? androidPackage;
  final AppSessionType sessionType;

  SelfReportedContext get context => SelfReportedContext(appPackage: androidPackage, sessionType: sessionType);
}

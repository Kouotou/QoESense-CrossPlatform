/// Keys in the durable KeyValueStore shared by the UI and the headless engines.
abstract final class SettingsKeys {
  /// Local consent time (epoch ms). Collection never runs without it: this is the
  /// consent-before-collection guarantee, checked again by the collector entrypoint.
  static const consentGivenAtMs = 'consent.givenAtMs';

  static const onboardingComplete = 'onboarding.complete';

  /// The welcome / setup check after onboarding was seen and closed (WelcomeCheckScreen).
  static const welcomeCheckSeen = 'onboarding.welcomeCheckSeen';

  /// Prefix for the stored AppInfo fields (see appInfoToMap).
  static const appInfoPrefix = 'app.';

  /// End of the last successful upload run (epoch ms), written by drainBuffer on both
  /// platforms. Read by the 3-day upload reminder (UploadReminder).
  static const uploadLastSuccessMs = 'upload.lastSuccessMs';

  /// When the last upload reminder was shown (epoch ms).
  static const uploadLastReminderMs = 'upload.lastReminderMs';
}

/// Keys in the durable KeyValueStore shared by the UI and the headless engines.
abstract final class SettingsKeys {
  /// Local consent time (epoch ms). Collection never runs without it: this is the
  /// consent-before-collection guarantee, checked again by the collector entrypoint.
  static const consentGivenAtMs = 'consent.givenAtMs';

  static const onboardingComplete = 'onboarding.complete';

  /// Prefix for the stored AppInfo fields (see appInfoToMap).
  static const appInfoPrefix = 'app.';
}

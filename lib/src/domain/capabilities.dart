import 'enums.dart';

/// Field groups the capability report covers, in display order.
enum FieldGroup {
  radioSignal,
  cqi,
  physicalChannel,
  radioAccessTechnology,
  connectivity,
  throughput,
  foregroundApp,
  callDetection,
  location,
  backgroundLocation,
  notifications,
  surveyOverlay,
}

/// Mirrors the channel's Availability, kept separate so the domain doesn't depend on
/// generated platform code.
enum FieldAvailability { available, permissionMissing, unsupportedOnPlatform, restricted }

/// What this device can actually measure right now - reported by native code, never assumed.
class PlatformCapabilities {
  const PlatformCapabilities({
    required this.platform,
    required this.osMajorVersion,
    required this.deviceModel,
    required this.groups,
  });

  final ClientPlatform platform;
  final int osMajorVersion;
  final String deviceModel;
  final Map<FieldGroup, FieldAvailability> groups;

  FieldAvailability of(FieldGroup group) => groups[group] ?? FieldAvailability.unsupportedOnPlatform;

  bool isAvailable(FieldGroup group) => of(group) == FieldAvailability.available;
}

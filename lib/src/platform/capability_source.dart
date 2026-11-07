import '../domain/capabilities.dart';
import '../domain/enums.dart';
import 'telemetry_api.g.dart';

/// Port the UI and (later) the collector use to learn what this device can measure.
abstract interface class CapabilitySource {
  Future<PlatformCapabilities> load();
}

/// Reads the report from native code over the Pigeon channel (Kotlin on Android, Swift on
/// iOS) and maps it into the domain model.
class PlatformChannelCapabilitySource implements CapabilitySource {
  PlatformChannelCapabilitySource([TelemetryHostApi? api]) : _api = api ?? TelemetryHostApi();

  final TelemetryHostApi _api;

  @override
  Future<PlatformCapabilities> load() async => mapCapabilityReport(await _api.getCapabilityReport());
}

PlatformCapabilities mapCapabilityReport(CapabilityReportMessage m) => PlatformCapabilities(
  platform: ClientPlatform.fromWireName(m.platform),
  osMajorVersion: m.osMajorVersion,
  deviceModel: m.deviceModel,
  groups: {
    FieldGroup.radioSignal: _map(m.radioSignal),
    FieldGroup.cqi: _map(m.cqi),
    FieldGroup.physicalChannel: _map(m.physicalChannel),
    FieldGroup.radioAccessTechnology: _map(m.radioAccessTechnology),
    FieldGroup.connectivity: _map(m.connectivity),
    FieldGroup.throughput: _map(m.throughput),
    FieldGroup.foregroundApp: _map(m.foregroundApp),
    FieldGroup.callDetection: _map(m.callDetection),
    FieldGroup.location: _map(m.location),
    FieldGroup.backgroundLocation: _map(m.backgroundLocation),
    FieldGroup.notifications: _map(m.notifications),
    FieldGroup.surveyOverlay: _map(m.surveyOverlay),
  },
);

FieldAvailability _map(Availability a) => switch (a) {
  Availability.available => FieldAvailability.available,
  Availability.permissionMissing => FieldAvailability.permissionMissing,
  Availability.unsupportedOnPlatform => FieldAvailability.unsupportedOnPlatform,
  Availability.restricted => FieldAvailability.restricted,
};

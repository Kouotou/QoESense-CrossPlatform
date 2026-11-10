import '../application/captured_sample.dart';
import '../application/collector.dart';
import '../application/mos_pipeline.dart';
import '../application/survey_scheduler.dart';
import '../domain/enums.dart';
import 'telemetry_api.g.dart';

/// Dart adapters over the Pigeon-generated [AndroidCollectorApi]. All mapping between
/// channel messages and the domain lives here (and is unit-tested), so the application
/// layer never sees channel types.
class AndroidSampleSource implements SampleSource {
  AndroidSampleSource(this._api);
  final AndroidCollectorApi _api;

  @override
  Future<CapturedSample> capture({required int locationTimeoutMs, required int staleAfterMs}) async =>
      mapCapturedSample(await _api.captureSample(locationTimeoutMs, staleAfterMs));
}

class AndroidSurveyPresenter implements SurveyPresenter {
  AndroidSurveyPresenter(this._api);
  final AndroidCollectorApi _api;

  @override
  Future<void> present(MosTriggerType trigger) => _api.presentSurvey(trigger.wireName);
}

class AndroidSurveyAnswerQueue implements SurveyAnswerQueue {
  AndroidSurveyAnswerQueue(this._api);
  final AndroidCollectorApi _api;

  @override
  Future<List<SurveyAnswer>> pending() async => [for (final m in await _api.pendingSurveyAnswers()) mapSurveyAnswer(m)];

  @override
  Future<void> acknowledge(List<String> responseIds) => _api.acknowledgeSurveyAnswers(responseIds);
}

FieldStatus mapStatus(MeasurementStatus s) => switch (s) {
  MeasurementStatus.ok => FieldStatus.ok,
  MeasurementStatus.stale => FieldStatus.stale,
  MeasurementStatus.notSupported => FieldStatus.notSupported,
  MeasurementStatus.permissionDenied => FieldStatus.permissionDenied,
  MeasurementStatus.restricted => FieldStatus.restricted,
  MeasurementStatus.notAttempted => FieldStatus.notAttempted,
  MeasurementStatus.unavailable => FieldStatus.unavailable,
  MeasurementStatus.timeout => FieldStatus.timeout,
  MeasurementStatus.failed => FieldStatus.failed,
};

AppSessionType mapSession(SessionTypeMessage s) => switch (s) {
  SessionTypeMessage.none => AppSessionType.none,
  SessionTypeMessage.socialMedia => AppSessionType.socialMedia,
  SessionTypeMessage.videoConferencing => AppSessionType.videoConferencing,
};

/// Shared by both platforms: the iOS capture uses the same message (osSdkInt then holds the
/// iOS major version, D-5).
CapturedSample mapCapturedSample(CapturedSampleMessage m, {ClientPlatform platform = ClientPlatform.android}) =>
    CapturedSample(
      platform: platform,
      rsrp: m.rsrp,
      rsrq: m.rsrq,
      rssnr: m.rssnr,
      timingAdvance: m.timingAdvance,
      cellIdentityHash: m.cellIdentityHash,
      trackingAreaCode: m.trackingAreaCode,
      signalStrengthLevel: m.signalStrengthLevel,
      radioStatus: mapStatus(m.radioStatus),
      cellInfoAgeMs: m.cellInfoAgeMs,
      cqi: m.cqi,
      cqiStatus: mapStatus(m.cqiStatus),
      cellBandwidthKhz: m.cellBandwidthKhz,
      downlinkChannelNumber: m.downlinkChannelNumber,
      uplinkChannelNumber: m.uplinkChannelNumber,
      physicalChannelStatus: mapStatus(m.physicalChannelStatus),
      networkType: m.networkType,
      networkTypeStatus: mapStatus(m.networkTypeStatus),
      connectionType: m.connectionType,
      isRoaming: m.isRoaming,
      connectivityStatus: mapStatus(m.connectivityStatus),
      throughputBytesPerSecond: m.throughputBytesPerSecond,
      throughputWindowMs: m.throughputWindowMs,
      throughputStatus: mapStatus(m.throughputStatus),
      foregroundAppPackage: m.foregroundAppPackage,
      appSessionType: mapSession(m.appSessionType),
      foregroundAppStatus: mapStatus(m.foregroundAppStatus),
      latitude: m.latitude,
      longitude: m.longitude,
      locationAccuracyMeters: m.locationAccuracyMeters,
      locationAgeMs: m.locationAgeMs,
      locationStatus: mapStatus(m.locationStatus),
      capabilitySet: {
        for (final g in SampleFieldGroup.values)
          if (m.capabilitySet.contains(g.wireName)) g,
      },
      app: AppInfo(
        deviceModel: m.deviceModel,
        osMajorVersion: m.osSdkInt,
        osVersion: m.osVersion,
        appId: m.appId,
        appVersion: m.appVersion,
        appBuild: m.appBuild,
      ),
    );

SurveyAnswer mapSurveyAnswer(SurveyAnswerMessage m) => SurveyAnswer(
  responseId: m.responseId,
  score: m.score,
  triggerType: MosTriggerType.values.firstWhere(
    (t) => t.wireName == m.triggerType,
    orElse: () => throw FormatException('unknown triggerType ${m.triggerType}'),
  ),
  tapMs: m.tapMs,
  promptedAtMs: m.promptedAtMs,
  presentationMode: PresentationMode.values.firstWhere(
    (p) => p.wireName == m.presentationMode,
    orElse: () => throw FormatException('unknown presentationMode ${m.presentationMode}'),
  ),
  selfReport: switch (m.contextSessionType) {
    null => null,
    final type => SelfReportedContext(
      appPackage: m.contextAppPackage,
      sessionType: AppSessionType.values.firstWhere(
        (s) => s.wireName == type,
        orElse: () => throw FormatException('unknown contextSessionType $type'),
      ),
    ),
  },
);

/// The reverse of [mapSurveyAnswer], for answers Dart hands to the native queue (iOS sheet).
SurveyAnswerMessage surveyAnswerMessage(SurveyAnswer a) => SurveyAnswerMessage(
  responseId: a.responseId,
  score: a.score,
  triggerType: a.triggerType.wireName,
  tapMs: a.tapMs,
  promptedAtMs: a.promptedAtMs,
  presentationMode: a.presentationMode.wireName,
  contextAppPackage: a.selfReport?.appPackage,
  contextSessionType: a.selfReport?.sessionType.wireName,
);

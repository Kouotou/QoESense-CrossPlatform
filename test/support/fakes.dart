import 'dart:typed_data';

import 'package:qoesense/src/application/captured_sample.dart';
import 'package:qoesense/src/application/collector.dart';
import 'package:qoesense/src/application/mos_pipeline.dart';
import 'package:qoesense/src/application/survey_scheduler.dart';
import 'package:qoesense/src/data/backend/backend_ports.dart';
import 'package:qoesense/src/domain/enums.dart';

const testApp = AppInfo(
  deviceModel: 'SM-A155F',
  osMajorVersion: 34,
  osVersion: '14',
  appId: 'io.github.kouotou.qoesense',
  appVersion: '2.0.0',
  appBuild: 1,
);

/// A plausible Android capture. Override fields to simulate conditions.
CapturedSample captured({
  int? rsrp = -95,
  FieldStatus radioStatus = FieldStatus.ok,
  String? foregroundAppPackage = 'com.whatsapp',
  AppSessionType session = AppSessionType.socialMedia,
  FieldStatus foregroundAppStatus = FieldStatus.ok,
  int? cqi = 9,
}) => CapturedSample(
  platform: ClientPlatform.android,
  rsrp: radioStatus.carriesValue ? rsrp : null,
  rsrq: radioStatus.carriesValue ? -11 : null,
  rssnr: radioStatus.carriesValue ? 12 : null,
  timingAdvance: radioStatus.carriesValue ? 3 : null,
  cellIdentityHash: radioStatus.carriesValue ? 'a1b2c3d4e5f60718' : null,
  trackingAreaCode: radioStatus.carriesValue ? 12345 : null,
  signalStrengthLevel: radioStatus.carriesValue ? 3 : null,
  radioStatus: radioStatus,
  cellInfoAgeMs: radioStatus.carriesValue ? 500 : null,
  cqi: radioStatus.carriesValue ? cqi : null,
  cqiStatus: radioStatus.carriesValue && cqi != null ? FieldStatus.ok : FieldStatus.unavailable,
  physicalChannelStatus: FieldStatus.restricted,
  networkType: 'LTE',
  networkTypeStatus: FieldStatus.ok,
  connectionType: 'CELLULAR',
  isRoaming: false,
  connectivityStatus: FieldStatus.ok,
  throughputBytesPerSecond: 1000,
  throughputWindowMs: 60000,
  throughputStatus: FieldStatus.ok,
  foregroundAppPackage: foregroundAppStatus.carriesValue ? foregroundAppPackage : null,
  appSessionType: session,
  foregroundAppStatus: foregroundAppStatus,
  latitude: 4.05,
  longitude: 9.77,
  locationAccuracyMeters: 20,
  locationAgeMs: 1000,
  locationStatus: FieldStatus.ok,
  capabilitySet: {
    SampleFieldGroup.radio,
    SampleFieldGroup.cqi,
    SampleFieldGroup.networkType,
    SampleFieldGroup.connectivity,
    SampleFieldGroup.throughput,
    SampleFieldGroup.foregroundApp,
    SampleFieldGroup.location,
  },
  app: testApp,
);

/// Plays a script of captures; repeats the last one. Records the arguments it got.
class ScriptedSource implements SampleSource {
  ScriptedSource(this.script);
  final List<CapturedSample Function()> script;
  final timeouts = <int>[];
  final staleLimits = <int>[];
  int _i = 0;
  Object? throwOnNext;

  @override
  Future<CapturedSample> capture({required int locationTimeoutMs, required int staleAfterMs}) async {
    timeouts.add(locationTimeoutMs);
    staleLimits.add(staleAfterMs);
    final err = throwOnNext;
    if (err != null) {
      throwOnNext = null;
      throw err;
    }
    final f = script[_i < script.length ? _i : script.length - 1];
    _i++;
    return f();
  }
}

class CountingRtt implements RttProbe {
  int calls = 0;
  @override
  String get method => 'TEST';
  @override
  Future<RttResult> measure() async {
    calls++;
    return const RttResult(FieldStatus.ok, 80);
  }
}

class RecordingPresenter implements SurveyPresenter {
  final shown = <MosTriggerType>[];
  @override
  Future<void> present(MosTriggerType trigger) async => shown.add(trigger);
}

class FakeAnswerQueue implements SurveyAnswerQueue {
  final queue = <SurveyAnswer>[];
  final acknowledged = <String>[];
  @override
  Future<List<SurveyAnswer>> pending() async => List.of(queue);
  @override
  Future<void> acknowledge(List<String> ids) async {
    acknowledged.addAll(ids);
    queue.removeWhere((a) => ids.contains(a.responseId));
  }
}

class FakeIdentity implements DeviceIdentity {
  FakeIdentity([this.id = 'uid-1']);
  String? id;
  @override
  Future<String?> deviceId() async => id;
}

class FakeMosSink implements MosSink {
  bool succeed = true;
  final written = <String, Map<String, Object?>>{};
  int calls = 0;
  @override
  Future<bool> submit(String deviceId, String responseId, Map<String, Object?> body) async {
    calls++;
    if (!succeed) return false;
    written[responseId] = body; // `set` semantics: a retry overwrites, never duplicates
    return true;
  }
}

class FakeBatchDestination implements BatchDestination {
  final paths = <String>[];
  @override
  Future<bool> upload({required String objectPath, required Uint8List gzippedNdjson}) async {
    paths.add(objectPath);
    return true;
  }
}

const testIosApp = AppInfo(
  deviceModel: 'iPhone15,3',
  osMajorVersion: 26,
  osVersion: '26.4',
  appId: 'io.github.kouotou.qoesense',
  appVersion: '2.0.0',
  appBuild: 1,
);

/// A plausible iOS capture: no radio values (NOT_SUPPORTED), RAT + path + throughput +
/// location only. Override fields to simulate path and call changes.
CapturedSample iosCaptured({
  String? networkType = 'LTE',
  String? connectionType = 'CELLULAR',
  FieldStatus connectivityStatus = FieldStatus.ok,
  AppSessionType session = AppSessionType.none,
}) => CapturedSample(
  platform: ClientPlatform.ios,
  radioStatus: FieldStatus.notSupported,
  cqiStatus: FieldStatus.notSupported,
  physicalChannelStatus: FieldStatus.notSupported,
  networkType: networkType,
  networkTypeStatus: FieldStatus.ok,
  connectionType: connectivityStatus.carriesValue ? connectionType : null,
  connectivityStatus: connectivityStatus,
  throughputBytesPerSecond: 2048,
  throughputWindowMs: 60000,
  throughputStatus: FieldStatus.ok,
  appSessionType: session,
  foregroundAppStatus: FieldStatus.notSupported,
  latitude: 4.05,
  longitude: 9.77,
  locationAccuracyMeters: 65,
  locationAgeMs: 1500,
  locationStatus: FieldStatus.ok,
  capabilitySet: {
    SampleFieldGroup.networkType,
    SampleFieldGroup.connectivity,
    SampleFieldGroup.throughput,
    SampleFieldGroup.location,
  },
  app: testIosApp,
);

/// An RTT probe whose results are scripted (repeats the last one).
class ScriptedRtt implements RttProbe {
  ScriptedRtt(this.results);
  final List<RttResult> results;
  int _i = 0;
  @override
  String get method => 'TEST';
  @override
  Future<RttResult> measure() async => results[_i < results.length ? _i++ : results.length - 1];
}

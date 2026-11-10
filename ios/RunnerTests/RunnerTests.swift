import CoreLocation
import CoreTelephony
import Flutter
import UIKit
import UserNotifications
import XCTest

@testable import Runner

/// The Swift logic that can be tested without a device (docs/PHASE4_IOS.md §8). Device-only
/// behaviour (background lifetime, real fixes, CallKit, notification delivery) is in the
/// physical-device protocol instead.
final class RadioAccessMappingTests: XCTestCase {
  func testRatConstantsMapToTheContractValues() {
    XCTAssertEqual(RadioAccessMapping.networkType(CTRadioAccessTechnologyLTE), "LTE")
    XCTAssertEqual(RadioAccessMapping.networkType(CTRadioAccessTechnologyNR), "NR")
    XCTAssertEqual(RadioAccessMapping.networkType(CTRadioAccessTechnologyNRNSA), "NR")
    XCTAssertEqual(RadioAccessMapping.networkType(CTRadioAccessTechnologyWCDMA), "OTHER")
    XCTAssertEqual(RadioAccessMapping.networkType(CTRadioAccessTechnologyEdge), "OTHER")
    XCTAssertEqual(RadioAccessMapping.networkType(nil), "UNKNOWN")
  }

  func testTheSimulatorHasNoModem() {
    XCTAssertFalse(
      CellularHardware.isPresent(hardwareId: DeviceInfo.hardwareIdentifier(), telephony: CTTelephonyNetworkInfo()))
  }
}

final class PathAndCallMappingTests: XCTestCase {
  func testConnectionTypePrecedenceMatchesAndroid() {
    XCTAssertEqual(PathMapping.connectionType(satisfied: true, wifi: true, cellular: true), "WIFI")
    XCTAssertEqual(PathMapping.connectionType(satisfied: true, wifi: false, cellular: true), "CELLULAR")
    XCTAssertEqual(PathMapping.connectionType(satisfied: true, wifi: false, cellular: false), "OTHER")
    XCTAssertNil(PathMapping.connectionType(satisfied: false, wifi: true, cellular: false))
  }

  func testAnyActiveCallIsVideoConferencingD4() {
    XCTAssertEqual(CallMapping.sessionType(activeCallCount: 0), SessionTypeMessage.none)
    XCTAssertEqual(CallMapping.sessionType(activeCallCount: 1), .videoConferencing)
    XCTAssertEqual(CallMapping.sessionType(activeCallCount: 2), .videoConferencing)
  }
}

final class ThroughputMeterTests: XCTestCase {
  func testFirstSampleHasNoBaseline() {
    let m = ThroughputMeter()
    XCTAssertEqual(m.sample(counters: ["en0": (100, 100)], nowMs: 0).status, .unavailable)
  }

  func testRxPlusTxAveragedOverTheWindow() {
    let m = ThroughputMeter()
    _ = m.sample(counters: ["en0": (1_000, 500), "pdp_ip0": (0, 0)], nowMs: 10_000)
    let r = m.sample(counters: ["en0": (61_000, 30_500), "pdp_ip0": (6_000, 2_000)], nowMs: 70_000)
    XCTAssertEqual(r.status, .ok)
    XCTAssertEqual(r.windowMs, 60_000)
    XCTAssertEqual(r.bytesPerSecond, (60_000 + 30_000 + 6_000 + 2_000) / 60)
  }

  func testThe32BitCounterWrapIsHandled() {
    XCTAssertEqual(ThroughputMeter.delta(0xFFFF_FF00, 0x100), 0x200)
    XCTAssertEqual(ThroughputMeter.delta(10, 25), 15)
  }

  func testAnInterfaceResetCountsFromZero() {
    XCTAssertEqual(ThroughputMeter.delta(50_000, 1_000), 1_000)
  }

  func testANewInterfaceCountsEverythingItSaw() {
    let m = ThroughputMeter()
    _ = m.sample(counters: ["en0": (0, 0)], nowMs: 0)
    let r = m.sample(counters: ["en0": (0, 0), "pdp_ip1": (3_000, 1_000)], nowMs: 1_000)
    XCTAssertEqual(r.bytesPerSecond, 4_000)
  }

  func testUnreadableCountersFailAndAZeroWindowIsUnavailable() {
    let m = ThroughputMeter()
    XCTAssertEqual(m.sample(counters: nil, nowMs: 0).status, .failed)
    _ = m.sample(counters: ["en0": (0, 0)], nowMs: 5)
    XCTAssertEqual(m.sample(counters: ["en0": (9, 9)], nowMs: 5).status, .unavailable)
  }

  func testOnlyPhysicalInterfacesAreCounted() {
    for name in ["en0", "en2", "pdp_ip0", "pdp_ip3"] { XCTAssertTrue(ThroughputMeter.isCounted(name), name) }
    for name in ["lo0", "utun0", "ipsec0", "awdl0", "llw0", "bridge100", "anpi0"] {
      XCTAssertFalse(ThroughputMeter.isCounted(name), name)
    }
  }

  func testTheCountersAreReadable() {
    XCTAssertNotNil(ThroughputMeter.readCounters())
  }
}

final class LocationRulesTests: XCTestCase {
  func testPermissionStatuses() {
    XCTAssertNil(LocationRules.statusWithoutPermission(.authorizedAlways))
    XCTAssertNil(LocationRules.statusWithoutPermission(.authorizedWhenInUse))
    XCTAssertEqual(LocationRules.statusWithoutPermission(.denied), .permissionDenied)
    XCTAssertEqual(LocationRules.statusWithoutPermission(.notDetermined), .permissionDenied)
    XCTAssertEqual(LocationRules.statusWithoutPermission(.restricted), .restricted)
  }

  func testAFixOlderThanTheIntervalIsStaleWithItsValueKept() {
    let fresh = LocationRules.reading(
      latitude: 3.8, longitude: 11.5, horizontalAccuracy: 65, ageMs: 3_000, staleAfterMs: 60_000)
    XCTAssertEqual(fresh.status, .ok)
    XCTAssertEqual(fresh.accuracyMeters, 65)
    let stale = LocationRules.reading(
      latitude: 3.8, longitude: 11.5, horizontalAccuracy: 65, ageMs: 61_000, staleAfterMs: 60_000)
    XCTAssertEqual(stale.status, .stale)
    XCTAssertEqual(stale.latitude, 3.8)
    XCTAssertEqual(stale.ageMs, 61_000)
  }

  func testAnInvalidFixIsNeverReported() {
    let r = LocationRules.reading(latitude: 0, longitude: 0, horizontalAccuracy: -1, ageMs: 0, staleAfterMs: 60_000)
    XCTAssertEqual(r, .empty(.unavailable))
  }

  func testWhyThereIsNoFix() {
    XCTAssertEqual(LocationRules.status(forError: nil), .timeout)
    XCTAssertEqual(LocationRules.status(forError: CLError(.denied)), .permissionDenied)
    XCTAssertEqual(LocationRules.status(forError: CLError(.locationUnknown)), .unavailable)
    XCTAssertEqual(LocationRules.status(forError: CLError(.network)), .failed)
    XCTAssertEqual(LocationRules.status(forError: NSError(domain: "x", code: 1)), .failed)
  }

  func testAuthorizationReachesDartUnchanged() {
    XCTAssertEqual(IosCollectorHost.message(for: .authorizedAlways), .always)
    XCTAssertEqual(IosCollectorHost.message(for: .authorizedWhenInUse), .whenInUse)
    XCTAssertEqual(IosCollectorHost.message(for: .denied), .denied)
    XCTAssertEqual(IosCollectorHost.message(for: .restricted), .restricted)
    XCTAssertEqual(IosCollectorHost.message(for: .notDetermined), .notDetermined)
  }
}

final class SurveyTests: XCTestCase {
  private var dir: URL!

  override func setUp() {
    dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  }

  override func tearDown() {
    try? FileManager.default.removeItem(at: dir)
  }

  private func answer(_ id: String, package: String? = nil, session: String? = nil) -> SurveyAnswerMessage {
    SurveyAnswerMessage(
      responseId: id, score: 4, triggerType: "PERIODIC", tapMs: 1_762_500_300_000,
      promptedAtMs: 1_762_500_250_000, presentationMode: "NOTIFICATION",
      contextAppPackage: package, contextSessionType: session)
  }

  func testOnlyTheFiveRatingActionsCarryAScore() {
    for n in 1...5 { XCTAssertEqual(SurveyNotifications.score(forAction: "MOS_\(n)"), Int64(n)) }
    XCTAssertNil(SurveyNotifications.score(forAction: "MOS_0"))
    XCTAssertNil(SurveyNotifications.score(forAction: "MOS_6"))
    XCTAssertNil(SurveyNotifications.score(forAction: UNNotificationDefaultActionIdentifier))
    XCTAssertNil(SurveyNotifications.score(forAction: UNNotificationDismissActionIdentifier))
  }

  func testTheQueueSurvivesARelaunchAndIsClearedOnlyByAcknowledge() {
    let store = SurveyAnswerStore(directory: dir)
    store.append(answer("a", package: "com.whatsapp", session: "VIDEO_CONFERENCING"))
    store.append(answer("b"))
    store.append(answer("a"))  // a duplicate tap is stored once

    let relaunched = SurveyAnswerStore(directory: dir)
    let pending = relaunched.pending()
    XCTAssertEqual(pending.map(\.responseId), ["a", "b"])
    XCTAssertEqual(pending[0], answer("a", package: "com.whatsapp", session: "VIDEO_CONFERENCING"))
    XCTAssertNil(pending[1].contextSessionType)

    relaunched.acknowledge(["a"])
    XCTAssertEqual(SurveyAnswerStore(directory: dir).pending().map(\.responseId), ["b"])
  }

  func testAnActionTapIsQueuedAsNotificationAction() {
    let store = SurveyAnswerStore(directory: dir)
    let prompts = OpenedPromptStore(defaults: UserDefaults(suiteName: dir.lastPathComponent)!)
    let delegate = SurveyNotificationDelegate(answers: store, openedPrompts: prompts)
    delegate.clock = { 1_762_500_300_000 }
    let info: [AnyHashable: Any] = ["triggerType": "ANOMALY", "promptedAtMs": NSNumber(value: 1_762_500_250_000)]

    delegate.handle(actionIdentifier: "MOS_2", userInfo: info)

    let a = store.pending().first
    XCTAssertEqual(a?.score, 2)
    XCTAssertEqual(a?.triggerType, "ANOMALY")
    XCTAssertEqual(a?.presentationMode, "NOTIFICATION_ACTION")
    XCTAssertEqual(a?.tapMs, 1_762_500_300_000)
    XCTAssertEqual(a?.promptedAtMs, 1_762_500_250_000)
    XCTAssertNil(a?.contextSessionType)
    XCTAssertEqual(a?.responseId.count, 36)
    XCTAssertNil(prompts.take())
  }

  func testTappingThePromptOpensTheSheetInstead() {
    let store = SurveyAnswerStore(directory: dir)
    let prompts = OpenedPromptStore(defaults: UserDefaults(suiteName: dir.lastPathComponent)!)
    let delegate = SurveyNotificationDelegate(answers: store, openedPrompts: prompts)
    let info: [AnyHashable: Any] = ["triggerType": "PERIODIC", "promptedAtMs": NSNumber(value: 42)]

    delegate.handle(actionIdentifier: UNNotificationDefaultActionIdentifier, userInfo: info)
    delegate.handle(actionIdentifier: UNNotificationDismissActionIdentifier, userInfo: info)

    XCTAssertTrue(store.pending().isEmpty)
    XCTAssertEqual(prompts.take(), SurveyPromptMessage(triggerType: "PERIODIC", promptedAtMs: 42))
    XCTAssertNil(prompts.take(), "taking the prompt clears it")
  }

  func testANotificationFromSomethingElseIsIgnored() {
    let store = SurveyAnswerStore(directory: dir)
    let delegate = SurveyNotificationDelegate(
      answers: store, openedPrompts: OpenedPromptStore(defaults: UserDefaults(suiteName: dir.lastPathComponent)!))
    delegate.handle(actionIdentifier: "MOS_5", userInfo: [:])
    XCTAssertTrue(store.pending().isEmpty)
  }
}

final class CapabilityReportTests: XCTestCase {
  func testUnsupportedGroupsAreAlwaysUnsupported() {
    let r = IOSCapabilityReporter.report(
      locationStatus: .authorizedWhenInUse, notificationStatus: .authorized, hasCellular: true)
    XCTAssertEqual(r.platform, "IOS")
    for a in [r.radioSignal, r.cqi, r.physicalChannel, r.foregroundApp, r.surveyOverlay] {
      XCTAssertEqual(a, .unsupportedOnPlatform)
    }
    XCTAssertEqual(r.radioAccessTechnology, .available)
    XCTAssertEqual(r.location, .available)
    XCTAssertEqual(r.backgroundLocation, .permissionMissing, "When-In-Use is not Always")
    XCTAssertEqual(r.notifications, .available)
  }

  func testNoModemMeansNoRat() {
    let r = IOSCapabilityReporter.report(locationStatus: .denied, notificationStatus: .denied, hasCellular: false)
    XCTAssertEqual(r.radioAccessTechnology, .unsupportedOnPlatform)
    XCTAssertEqual(r.location, .permissionMissing)
    XCTAssertEqual(r.notifications, .permissionMissing)
  }
}

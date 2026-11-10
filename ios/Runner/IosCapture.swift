import CallKit
import CoreTelephony
import Darwin
import Foundation
import Network

// One full iOS capture per tick, everything except RTT (shared Dart HttpRttProbe). Field
// semantics follow docs/DATA_CONTRACT.md §3 and §5; the iOS rules are in docs/PHASE4_IOS.md.
// Radio, CQI, physical channel and foreground app have no public iOS API: they are always
// null + NOT_SUPPORTED, and isRoaming is always null. Nothing here estimates a value.

/// Monotonic milliseconds that keep counting while the device sleeps (Darwin CLOCK_MONOTONIC,
/// the counterpart of Android's elapsedRealtime). Used for durations and windows only.
func monotonicMs() -> Int64 {
  Int64(clock_gettime_nsec_np(CLOCK_MONOTONIC) / 1_000_000)
}

func wallClockMs(_ date: Date = Date()) -> Int64 {
  Int64((date.timeIntervalSince1970 * 1000).rounded(.down))
}

// MARK: - Device and app identity

enum DeviceInfo {
  /// e.g. "iPhone15,3": the stable hardware identifier, not the marketing name.
  static func hardwareIdentifier() -> String {
    #if targetEnvironment(simulator)
      if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
        return simulated
      }
    #endif
    var systemInfo = utsname()
    uname(&systemInfo)
    let identifier = withUnsafeBytes(of: &systemInfo.machine) { buffer in
      String(decoding: buffer.prefix(while: { $0 != 0 }), as: UTF8.self)
    }
    return identifier.isEmpty ? "unknown" : identifier
  }

  static var osMajorVersion: Int64 { Int64(ProcessInfo.processInfo.operatingSystemVersion.majorVersion) }

  /// "26.4" or "26.4.1", the same text as UIDevice.systemVersion, without needing UIKit.
  static var osVersion: String {
    let v = ProcessInfo.processInfo.operatingSystemVersion
    return v.patchVersion > 0
      ? "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)" : "\(v.majorVersion).\(v.minorVersion)"
  }

  static var appId: String { Bundle.main.bundleIdentifier ?? "io.github.kouotou.qoesense" }
  static var appVersion: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
  }
  static var appBuild: Int64 {
    Int64(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") ?? 0
  }
}

// MARK: - Radio access technology (networkType)

enum CellularHardware {
  /// Every iPhone has a modem; an iPad has one only in its cellular variants, which then
  /// report service subscribers. The simulator has none.
  static func isPresent(hardwareId: String, telephony: CTTelephonyNetworkInfo) -> Bool {
    #if targetEnvironment(simulator)
      return false
    #else
      if hardwareId.hasPrefix("iPhone") { return true }
      let rats = telephony.serviceCurrentRadioAccessTechnology ?? [:]
      let subscribers = telephony.serviceSubscriberCellularProviders ?? [:]
      return !rats.isEmpty || !subscribers.isEmpty
    #endif
  }
}

enum RadioAccessMapping {
  /// CTTelephonyNetworkInfo RAT → contract `networkType` (DATA_CONTRACT §3 row 6):
  /// LTE → "LTE"; NR and NR-NSA → "NR"; no RAT (no service, no SIM, airplane mode) →
  /// "UNKNOWN"; anything else (3G, 2G, CDMA) → "OTHER".
  static func networkType(_ rat: String?) -> String {
    guard let rat else { return "UNKNOWN" }
    if rat == CTRadioAccessTechnologyLTE { return "LTE" }
    if #available(iOS 14.1, *) {
      if rat == CTRadioAccessTechnologyNR || rat == CTRadioAccessTechnologyNRNSA { return "NR" }
    }
    return "OTHER"
  }

  /// The RAT of the SIM that carries data (dual-SIM), as Android's data network type.
  static func dataRat(_ telephony: CTTelephonyNetworkInfo) -> String? {
    let rats = telephony.serviceCurrentRadioAccessTechnology ?? [:]
    if let id = telephony.dataServiceIdentifier, let rat = rats[id] { return rat }
    return rats.keys.sorted().first.flatMap { rats[$0] }
  }
}

// MARK: - Connectivity (connectionType)

/// Keeps the latest NWPathMonitor path. NWPathMonitor needs no permission.
final class PathObserver {
  private let monitor = NWPathMonitor()
  private let queue = DispatchQueue(label: "io.github.kouotou.qoesense.path")
  private let lock = NSLock()
  private var latest: NWPath?
  /// Called on the main queue after each path change, with (status satisfied, connection type).
  var onChange: ((String?) -> Void)?

  init() {
    monitor.pathUpdateHandler = { [weak self] path in
      guard let self else { return }
      self.lock.lock()
      self.latest = path
      self.lock.unlock()
      let type = PathMapping.connectionType(path)
      DispatchQueue.main.async { self.onChange?(type) }
    }
    monitor.start(queue: queue)
  }

  var currentPath: NWPath {
    lock.lock()
    defer { lock.unlock() }
    return latest ?? monitor.currentPath
  }
}

enum PathMapping {
  /// Same values and precedence as the Android ConnectivitySampler: WIFI, then CELLULAR,
  /// else OTHER. nil = no usable path (Android: no active network → UNAVAILABLE).
  static func connectionType(_ path: NWPath) -> String? {
    connectionType(
      satisfied: path.status == .satisfied,
      wifi: path.usesInterfaceType(.wifi),
      cellular: path.usesInterfaceType(.cellular))
  }

  static func connectionType(satisfied: Bool, wifi: Bool, cellular: Bool) -> String? {
    guard satisfied else { return nil }
    if wifi { return "WIFI" }
    if cellular { return "CELLULAR" }
    return "OTHER"
  }

  /// Upload gate, the counterpart of WorkManager's unmetered-network constraint: a usable
  /// path that iOS doesn't flag as expensive (cellular, personal hotspot) or constrained
  /// (Low Data Mode).
  static func isUnmetered(_ path: NWPath) -> Bool {
    path.status == .satisfied && !path.isExpensive && !path.isConstrained
  }
}

// MARK: - Throughput

/// Device-wide rx+tx bytes per second from the getifaddrs interface counters, averaged since
/// the previous call: the same definition as the Android TrafficStats sampler. The first call
/// has no baseline and reports UNAVAILABLE. The counters are 32-bit (`if_data`), so each
/// interface's delta handles a wrap at 4 GiB and an interface reset.
final class ThroughputMeter {
  struct Reading: Equatable {
    let bytesPerSecond: Int64?
    let windowMs: Int64?
    let status: MeasurementStatus
  }

  /// rx+tx counters per interface name.
  typealias Counters = [String: (rx: UInt32, tx: UInt32)]

  private var last: (counters: Counters, atMs: Int64)?

  func sample(counters: Counters?, nowMs: Int64) -> Reading {
    guard let counters else { return Reading(bytesPerSecond: nil, windowMs: nil, status: .failed) }
    let previous = last
    last = (counters, nowMs)
    guard let previous else { return Reading(bytesPerSecond: nil, windowMs: nil, status: .unavailable) }
    let windowMs = nowMs - previous.atMs
    guard windowMs > 0 else { return Reading(bytesPerSecond: nil, windowMs: nil, status: .unavailable) }
    var bytes: UInt64 = 0
    for (name, now) in counters {
      if let before = previous.counters[name] {
        bytes += Self.delta(before.rx, now.rx) + Self.delta(before.tx, now.tx)
      } else {
        // A new interface (e.g. cellular data came up): everything it counted is from this window.
        bytes += UInt64(now.rx) + UInt64(now.tx)
      }
    }
    return Reading(
      bytesPerSecond: Int64(Double(bytes) * 1000.0 / Double(windowMs)), windowMs: windowMs, status: .ok)
  }

  /// A decrease is a 32-bit wrap when the previous value was in the top quarter and the new
  /// one in the bottom quarter; otherwise the interface was reset and counts from zero.
  static func delta(_ previous: UInt32, _ current: UInt32) -> UInt64 {
    if current >= previous { return UInt64(current - previous) }
    if previous > 0xC000_0000 && current < 0x4000_0000 {
      return (UInt64(current) + (1 << 32)) - UInt64(previous)
    }
    return UInt64(current)
  }

  /// Physical data interfaces only: Wi-Fi/Ethernet ("en*") and cellular ("pdp_ip*"). Loopback,
  /// VPN tunnels (utun, ipsec), AWDL and the like are excluded, so VPN traffic isn't counted twice.
  static func isCounted(_ name: String) -> Bool {
    name.hasPrefix("en") || name.hasPrefix("pdp_ip")
  }

  /// Reads the link-layer counters of every counted interface. nil if getifaddrs fails.
  static func readCounters() -> Counters? {
    var head: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&head) == 0, let first = head else { return nil }
    defer { freeifaddrs(head) }
    var result: Counters = [:]
    var cursor: UnsafeMutablePointer<ifaddrs>? = first
    while let ifa = cursor {
      defer { cursor = ifa.pointee.ifa_next }
      guard let addr = ifa.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK),
        let data = ifa.pointee.ifa_data
      else { continue }
      let name = String(cString: ifa.pointee.ifa_name)
      guard isCounted(name) else { continue }
      let stats = data.assumingMemoryBound(to: if_data.self).pointee
      let existing = result[name] ?? (0, 0)
      result[name] = (existing.rx &+ stats.ifi_ibytes, existing.tx &+ stats.ifi_obytes)
    }
    return result
  }
}

// MARK: - Call state (appSessionType)

enum CallMapping {
  /// Decision D-4: any connected, not yet ended CallKit-visible call (cellular, FaceTime,
  /// WhatsApp, any CallKit VoIP app) counts as VIDEO_CONFERENCING. CallKit can't say which
  /// app, nor whether video is on. A ringing or still-dialling call isn't counted yet.
  static func sessionType(calls: [CXCall]) -> SessionTypeMessage {
    sessionType(activeCallCount: calls.filter { $0.hasConnected && !$0.hasEnded }.count)
  }

  static func sessionType(activeCallCount: Int) -> SessionTypeMessage {
    activeCallCount > 0 ? .videoConferencing : .none
  }
}

// MARK: - The capture

/// Assembles a CapturedSampleMessage. Lives on the main thread (Core Location delegates run
/// there); Pigeon calls into it from the main thread too.
final class IosSampleCapturer {
  let telephony = CTTelephonyNetworkInfo()
  let paths = PathObserver()
  let calls = CXCallObserver()
  let throughput = ThroughputMeter()
  let location: LocationService
  private let hardwareId = DeviceInfo.hardwareIdentifier()

  init(location: LocationService) {
    self.location = location
  }

  var hasCellular: Bool { CellularHardware.isPresent(hardwareId: hardwareId, telephony: telephony) }

  func capture(
    locationTimeoutMs: Int64, staleAfterMs: Int64, completion: @escaping (CapturedSampleMessage) -> Void
  ) {
    // Location is the only wait; everything else is read when it completes, as close to
    // timestampMs (assigned by Dart on return) as possible.
    location.fix(timeoutMs: locationTimeoutMs, staleAfterMs: staleAfterMs) { [self] fix in
      completion(assemble(fix: fix))
    }
  }

  private func assemble(fix: LocationReading) -> CapturedSampleMessage {
    let cellular = hasCellular
    let networkType: String? = cellular ? RadioAccessMapping.networkType(RadioAccessMapping.dataRat(telephony)) : nil
    let networkTypeStatus: MeasurementStatus = cellular ? .ok : .notSupported

    let connectionType = PathMapping.connectionType(paths.currentPath)
    let connectivityStatus: MeasurementStatus = connectionType == nil ? .unavailable : .ok

    let tp = throughput.sample(counters: ThroughputMeter.readCounters(), nowMs: monotonicMs())

    var capabilities = ["CONNECTIVITY", "THROUGHPUT"]
    if cellular { capabilities.append("NETWORK_TYPE") }
    if location.isAuthorized { capabilities.append("LOCATION") }

    return CapturedSampleMessage(
      rsrp: nil, rsrq: nil, rssnr: nil, timingAdvance: nil, cellIdentityHash: nil,
      trackingAreaCode: nil, signalStrengthLevel: nil,
      radioStatus: .notSupported,
      cellInfoAgeMs: nil,
      cqi: nil,
      cqiStatus: .notSupported,
      cellBandwidthKhz: nil, downlinkChannelNumber: nil, uplinkChannelNumber: nil,
      physicalChannelStatus: .notSupported,
      networkType: networkType,
      networkTypeStatus: networkTypeStatus,
      connectionType: connectionType,
      isRoaming: nil,  // CTCarrier is deprecated and returns placeholders: never reported
      connectivityStatus: connectivityStatus,
      throughputBytesPerSecond: tp.bytesPerSecond,
      throughputWindowMs: tp.windowMs,
      throughputStatus: tp.status,
      foregroundAppPackage: nil,
      appSessionType: CallMapping.sessionType(calls: calls.calls),
      foregroundAppStatus: .notSupported,
      latitude: fix.latitude,
      longitude: fix.longitude,
      locationAccuracyMeters: fix.accuracyMeters,
      locationAgeMs: fix.ageMs,
      locationStatus: fix.status,
      capabilitySet: capabilities,
      deviceModel: hardwareId,
      osSdkInt: DeviceInfo.osMajorVersion,  // D-5: the iOS major version
      osVersion: DeviceInfo.osVersion,
      appId: DeviceInfo.appId,
      appVersion: DeviceInfo.appVersion,
      appBuild: DeviceInfo.appBuild
    )
  }
}

# iOS capability matrix (Phase 4, step 1)

Every field the Android app records, checked against what iOS really offers. Researched on
2026-11-09 against the **iPhoneOS 27.2 SDK** (Xcode 27.2: headers and `.swiftinterface` files) and
Apple's developer documentation (the JSON behind developer.apple.com pages). The deployment
target is iOS 15.0, so anything newer needs an `if #available` gate.

What the app actually does with each row is in [PHASE4_IOS.md](PHASE4_IOS.md) §1–2. The "Could
not verify" list at the end feeds the device protocol (PHASE4_IOS.md §8).

**Evidence tags**
- **[SDK]**: read in a header or `.swiftinterface` in the 27.2 SDK. This is authoritative for availability and deprecation.
  `[SDK/Xcode]` means it came from Xcode's capability catalog (`DVTPortalCachedPortalCapabilities.json`).
- **[DOC]**: quoted or paraphrased from Apple documentation text (developer.apple.com JSON, release notes, App Review Guidelines).
- **[INFERRED]**: my reasoning from the two sources above. Not verified. It needs a device test.
- "unverified" means I found no source and did not guess.

SDK root: `/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS27.2.sdk`

---

## 1. Cellular technology & service

| Field | Exact public API | Permission / plist / entitlement | Min iOS & deprecation (headers) | Known restrictions (docs) | Physical-device validation | Verdict |
|---|---|---|---|---|---|---|
| Current RAT (per SIM) | `CTTelephonyNetworkInfo.serviceCurrentRadioAccessTechnology` (`[String:String]`, key = service id). Change: `CTServiceRadioAccessTechnologyDidChangeNotification` (object = service id) | None | Dict: iOS 12.0 [SDK]. Notification: iOS 12.0 [SDK]. The old `currentRadioAccessTechnology` is deprecated 7.0–12.0 [SDK] | An entry is nil when the service isn't registered on a network [DOC] | Compare with Field Test (`*3001#12345#*`) and the status-bar glyph while toggling Settings > Cellular > Voice & Data (LTE/5G Auto/5G On) | **supported** |
| RAT constants | `CTRadioAccessTechnologyGPRS/Edge/WCDMA/HSDPA/HSUPA/CDMA1x/CDMAEVDORev0/A/B/eHRPD/LTE` | — | iOS 7.0 [SDK] | — | — | **supported** |
| NR constants | `CTRadioAccessTechnologyNRNSA`, `CTRadioAccessTechnologyNR` | — | **iOS 14.1** [SDK] | No mmWave/sub-6 split in CT [SDK] | 5G-capable iPhone on an NSA and an SA network | **supported** |
| Finer RAT (NSA vs SA, sub-6 vs mmWave, Wi-Fi PHY) for the app's **own** connections | `NWConnection.DataTransferReport.PathReport.radioType` → `NWInterface.RadioType.cell(.lte / .dualConnectivity5G(.sub6GHz/.mmWave) / .standalone5G(...) / .wcdma / .gsm / .cdma / .evdo)` or `.wifi(.b/.a/.g/.n/.ac/.ax)`. C API: `nw_data_transfer_report_get_path_radio_type` | — | **iOS 15.0** [SDK] | Only for connections the app opens itself and collects a report on [SDK] | Open an NWConnection to the probe server, collect the report, compare with Field Test | **supported** (own traffic only) |
| Which SIM carries data (dual SIM) | `CTTelephonyNetworkInfo.dataServiceIdentifier`. `CTTelephonyNetworkInfoDelegate.dataServiceIdentifierDidChange(_:)` | — | iOS 13.0 [SDK] | The key is opaque. "The actual value of a key isn't important" [DOC]. With CTCarrier frozen you cannot map it to an operator [INFERRED] | Dual-SIM phone: switch Settings > Cellular > Cellular Data and watch the callback | **supported** (as an opaque id; RAT via `serviceCurrentRadioAccessTechnology[dataServiceIdentifier]`) |
| Carrier name / MCC / MNC / ISO | `CTCarrier.carrierName/mobileCountryCode/mobileNetworkCode/isoCountryCode/allowsVOIP` via `serviceSubscriberCellularProviders` | — | Class `CTCarrier` deprecated 4.0–16.0 "with no replacement". `serviceSubscriberCellularProviders` deprecated 12.0–16.0 [SDK]. Header text: carrierName/isoCountryCode "returns '--'", MCC/MNC "returns '65535'", allowsVOIP "returns YES" [SDK] | iOS 16.4 release notes: "`CTCarrier`, a deprecated API, returns static values for apps that are built with the iOS 16.4 SDK or later" [DOC]. We build with the 27.2 SDK. Even when values were real, they were the **home** provider and didn't change when roaming [DOC] | On iOS ≥16.4, log the values. Expect `--`/`65535`. On an iOS 15.x–16.3 device, check whether real values come back [INFERRED: probably yes, unverified] | **not available** (null on iOS ≥16.4; maybe real on 15.0–16.3, unverified) |
| Roaming flag | No public API | — | — | CTCarrier only ever described the home network [DOC] | — | **not available** |
| Signal bars | No public API in CoreTelephony (grep of every 27.2 framework header and swiftinterface) [SDK]. Substitute: MetricKit `MXCellularConditionMetric.histogrammedCellularConditionTime` (`MXUnitSignalBars`) and the new `CellularConditionTimeMetric.histogram: Histogram<SignalBars>` (`MetricManager`) | None | MX: iOS 13.0, marked `API_TO_BE_DEPRECATED` with "Use MetricResult instead" [SDK]. Docs show deprecated at 27.3 [DOC]. `MetricManager` / `CellularConditionTimeMetric`: **iOS 27.0** [SDK] | "Percentage of time an application spent running in different cellular conditions" [SDK]. Reports cover the previous 24 h and arrive "at most once per day" [DOC] | Xcode > Debug > Simulate MetricKit Payloads, then a real 24 h payload on device | **substitute** (daily aggregate of app run time per bar bucket, not a per-sample value) |
| App's cellular-data permission | `CTCellularData.restrictedState` / `cellularDataRestrictionDidUpdateNotifier` | — | iOS 9.0 [SDK] | Per-app setting in Settings > Cellular [INFERRED] | Toggle the app's cellular switch | **supported** (useful for classifying connection failures) |

**New CoreTelephony surface in iOS 26–27 [SDK]:** `CTCellularPlanStatus` (token / phone-number authorization and status hint, iOS 26/27),
`CTQuickSwitchManager` (iOS 27), `CTCellularPlanProperties.lifecycleProperties` (26.4) and `CTSubscriber.isSIMInserted` (iOS 18, only for
a SIM that matches the carrier info in the app's own Info.plist, which means carrier apps). **None of them exposes radio measurements.**

## 2. Serving-cell identity & radio measurements

| Field | Exact public API | Permission / entitlement | Min iOS | Restrictions | Validation | Verdict |
|---|---|---|---|---|---|---|
| RSRP, RSRQ, SINR/RSSNR | **None.** A case-insensitive grep for `rsrp|rsrq|sinr|timingAdvance|earfcn|trackingAreaCode|cellIdentifier|signalStrength|signalBars` across every framework header and swiftinterface in the 27.2 SDK finds only MetricKit signal bars, Wi-Fi `signalStrength` (WiFiInfrastructure, NEHotspotHelper) and NearbyInteraction DL-TDOA [SDK] | No entitlement found that exposes them. `CTSubscriber.carrierToken` is "only available to carrier apps with suitable entitlements" and is an auth blob, not radio data [SDK] | — | Private CoreTelephony calls are barred: "Apps may only use public APIs" (Guideline 2.5.1) [DOC] | Field Test mode (`*3001#12345#*`) shows the reference values to a person, not to an app | **not available** → null |
| Timing advance, cell ID (ECI/NCI), TAC, PCI, CQI, bandwidth, EARFCN/NR-ARFCN | **None** (same grep) [SDK] | — | — | — | Field Test mode for manual ground truth only | **not available** → null |
| Coarse link quality of the current path | `NWPath.linkQuality` (`.unknown/.minimal/.moderate/.good`). C: `nw_path_get_link_quality` | — | **iOS 26.0** [SDK] | "Use this value to tune initial values … Do not use this value to gate connection attempts" [SDK/DOC]. Applies to the link-layer attachment, not a cell measurement [SDK] | Walk from good to poor coverage and log it next to Field Test RSRP | **substitute** (4-level ordinal, iOS 26+). It is not RSRP, so store it in its own field |
| Wi-Fi SSID/BSSID (if the contract has them) | `NEHotspotNetwork.fetchCurrent(completionHandler:)` | `com.apple.developer.networking.wifi-info` **plus** precise location (or one of three other conditions) [SDK] | iOS 14.0 [SDK] | Returns "only valid SSID, BSSID and security type". `signalStrength` is HotspotHelper-only [SDK]. `NEHotspotHelper` is deprecated 9.0–26.0 [SDK] | Compare with Settings > Wi-Fi | **supported** (SSID/BSSID). Wi-Fi RSSI is **not available** |

## 3. Location & mobility

| Field / capability | Exact public API | Permission / plist / background mode | Min iOS & deprecation | Known restrictions | Validation | Verdict |
|---|---|---|---|---|---|---|
| Standard updates | `CLLocationManager.startUpdatingLocation()`, `desiredAccuracy`, `distanceFilter`, `activityType` | `NSLocationWhenInUseUsageDescription` (always needed). For background: `UIBackgroundModes` += `location` and `allowsBackgroundLocationUpdates = true` | iOS 2.0. `allowsBackgroundLocationUpdates` 9.0 [SDK] | Setting `allowsBackgroundLocationUpdates = YES` without the `location` mode "is a fatal error" [SDK/DOC]. If the app is suspended, delivery stops. If it is terminated, delivery "stops altogether" [DOC] | Start in the foreground, lock the phone, walk or drive, export the log | **supported** |
| Background continuation with **When-In-Use** | same + `allowsBackgroundLocationUpdates = true`, started **in the foreground** | as above | iOS 9+ [SDK] | "an app with When in Use authorization continues to run in the background when location services are active". The system doesn't launch a terminated When-In-Use app [DOC]. Header: CL "will maintain visibility for your app as it enters the background … until location updates are stopped or your app is killed by the user" [SDK]. The blue bar/pill always shows for When-In-Use [SDK/DOC] | Start in the foreground, background the app, and confirm callbacks continue and the blue pill shows | **supported** (only while the session runs; it doesn't survive termination) |
| `pausesLocationUpdatesAutomatically` | property | — | iOS 6.0. Default YES [SDK] | "For apps that have in-use authorization, a pause to location updates ends access to location changes until the app launches again". Apple suggests turning it off and using `kCLLocationAccuracyThreeKilometers` in the background [DOC] | Leave the phone still for 20+ minutes with pause on, then with pause off | **supported**. **Must be `false`** for a When-In-Use keep-alive |
| `showsBackgroundLocationIndicator` | property | — | iOS 11.0 [SDK] | Only affects Always apps. When-In-Use apps always show the indicator [SDK/DOC] | Visual check | **supported** |
| Significant-location-change | `startMonitoringSignificantLocationChanges()` | **Always** to relaunch | iOS 4.0 [SDK] | Relaunches a terminated app with launch-options key `location` [DOC]. "a notification as soon as the device moves 500 meters or more … not … more frequently than once every five minutes" [DOC]. Uses cell and Wi-Fi, not GPS [DOC] | Always auth, force-quit, drive more than 1 km, check the relaunch log | **supported** (Always only, for relaunch) |
| Visits | `startMonitoringVisits()` → `locationManager(_:didVisit:)` | **Always** to relaunch | iOS 8.0 [SDK] | Enabling it on one manager enables it for all of them, and it persists across relaunch [SDK/DOC]. The system relaunches the app when visits are ready [DOC]. Reduced accuracy without precise location [DOC] | Visit 2–3 places over a day | **supported** (coarse and delayed) |
| Relaunch after a user **force-quit** | SLC / visits / region monitoring under Always | Always | — | `requestAlwaysAuthorization` header: "monitoring APIs may launch your app into the background … **Even if killed by the user**, launch events triggered by monitoring APIs will cause a relaunch" [SDK]. A When-In-Use session ends when the user kills the app [SDK]. Table in "Requesting authorization": When-In-Use relaunch = "No"; Always = "Yes for significant location change, visits, and region monitoring services; no for others" [DOC] | Swipe the app away, move more than 500 m, confirm the relaunch | **supported with Always only** |
| `CLLocationUpdate.liveUpdates(_:)` | Swift `AsyncSequence`. Configs `.default/.automotiveNavigation/.otherNavigation/.fitness/.airborne`, plus `.maritime` (iOS 27) | as standard | **iOS 17.0**. `stationary`, `insufficientlyInUse`, `locationUnavailable`, `accuracyLimited`, `serviceSessionRequired`, `authorizationRequestInProgress` diagnostics are **iOS 18.0** [SDK] | Iterating it requests authorization implicitly [DOC] | — | **supported** on iOS 17+. Needs a CLLocationManager fallback for 15–16 |
| `CLBackgroundActivitySession` | `CLBackgroundActivitySession()` / ObjC `+backgroundActivitySession`. The diagnostics handler variant is iOS 18 | `UIBackgroundModes` `location` required [SDK] | **iOS 17.0**. Diagnostics 18.0 [SDK] | Must be created "while the app is foregrounded and in direct use". "An active session may continue when the app enters the background even if the app stops running", and must be re-created "immediately upon background launch" [SDK] | Start the session, background the app, kill it via Xcode (not the user), and see whether the system relaunches it [INFERRED, unverified] | **supported** on 17+ |
| `CLServiceSession` | `CLServiceSession(authorization: .none/.whenInUse/.always [, fullAccuracyPurposeKey:])` + `diagnostics` | Optional `NSLocationRequireExplicitServiceSession` plist key [DOC] | **iOS 18.0** [SDK] | An Always app that doesn't hold an `.always` session "will not be able to receive `CLLocationUpdate.liveUpdates()` or `CLMonitor.events()` when it is not in-use". It must be retaken promptly after a background launch [SDK] | — | **supported** on 18+ (needed for Always with the new APIs) |
| Reduced / approximate location | `accuracyAuthorization` (`.fullAccuracy/.reducedAccuracy`), `requestTemporaryFullAccuracyAuthorization(withPurposeKey:)` | `NSLocationTemporaryUsageDescriptionDictionary`. Optional `NSLocationDefaultAccuracyReduced` | iOS 14.0 [SDK] | Reduced accuracy is about 5 km, snapped to a region, at a lower rate, with fixes "up to 20 minutes old". Region monitoring is unavailable [SDK]. Temporary full accuracy lasts while a background session with the indicator runs [SDK] | Turn off Precise Location in Settings for the app | **supported**. Record `accuracyAuthorization` with each sample |
| Info.plist keys | `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription` (Always), `UIBackgroundModes: location` | — | — | "Authorization requests fail immediately if the required keys aren't present" [DOC]. An app with When-In-Use can ask for Always "one time only" [SDK/DOC] | — | — |

### 3a. `requestLocation()` while a keep-alive session is running

- **Same instance.** The header says `requestLocation` "can not be used concurrently with `startUpdatingLocation` or
  `allowDeferredLocationUpdates`. Calling either of those methods will immediately cancel the location request" [SDK]. The doc page
  says "Calling this method while location services are already running **does nothing**" [DOC]. So on the instance that is already
  running standard updates, `requestLocation()` is a no-op. You get no extra fix and no error callback.
- **Second instance.** Apple says to "Create one or more location-manager objects in your app" [DOC], so several instances are
  supported. The "does nothing" sentence doesn't say whether it means *this manager* or *the app*. I read it as per manager
  [INFERRED] because the cancellation rules above are written per instance. **Unverified.** If it is app-wide, a second-instance
  `requestLocation()` returns no callback at all. Either way, keep your own watchdog timer.
- **Timeout.** No number is documented. The doc says the fix "may take several seconds", and if it "cannot be determined in a timely
  manner" the delegate gets `didFailWithError` with `kCLErrorLocationUnknown` [DOC]. The header says a lower-accuracy "best available
  location … will be delivered … after timeout" rather than an error [SDK]. The exact duration is **unverified**, so measure it on
  device. The delegate must implement both `didUpdateLocations` and `didFailWithError`, or it is "a programmer error" [DOC].
- **Background + When-In-Use, with a foreground-started session still active.** The header for `allowsBackgroundLocationUpdates` says
  "Access to location is still permitted whenever the application is running (ie not suspended), and has sufficient authorization (ie
  it has WhenInUse authorization **and is in use**…)" [SDK]. The `requestWhenInUseAuthorization` header says a Continuous Background
  Location session keeps the app "visible" (in use) in the background [SDK]. So I expect `requestLocation()` on a second manager to
  **succeed** while instance 1's session is live and not paused [INFERRED]. It should fail or no-op once the session pauses or stops,
  because the app is then no longer "in use" [INFERRED]. On iOS 18+, `CLServiceSession` / `CLBackgroundActivitySession` diagnostics
  (`insufficientlyInUse`) can confirm the state at run time [SDK]. The second manager doesn't need `allowsBackgroundLocationUpdates`
  just to read a fix while the app is running [INFERRED from the same header sentence].
- **Practical alternative.** Instance 1 is already producing fixes, so read `instance1.location` (with its timestamp; it is "the most
  recently retrieved user location" [DOC]) or the last `didUpdateLocations` value instead of calling `requestLocation()`. If you need a
  fresh high-accuracy fix, raise `desiredAccuracy` on instance 1 for a moment [INFERRED].
- **Device test.** Instance 1 runs `startUpdatingLocation` with background enabled and pause disabled, started in the foreground
  under When-In-Use. Background the app, then call `requestLocation()` on instance 2 from a timer. Log the callback type, the latency,
  and `horizontalAccuracy`. Repeat after instance 1 has paused, and again with instance 1 stopped.

## 4. Connectivity & path changes

| Field | Exact public API | Permission | Min iOS | Restrictions | Validation | Verdict |
|---|---|---|---|---|---|---|
| Path status | `NWPathMonitor` (`pathUpdateHandler`, `currentPath`, `start(queue:)`). `NWPath.status` = `.satisfied/.unsatisfied/.requiresConnection` | None | iOS 12.0 [SDK]. The `currentPath` setter is deprecated in 17.0 [SDK] | Delivered only while the process runs (not while suspended) [INFERRED] | Toggle airplane mode, Wi-Fi and cellular | **supported** |
| Interface type | `NWPath.usesInterfaceType(.wifi/.cellular/.wiredEthernet/.loopback/.other)`, `availableInterfaces`, `NWPathMonitor(requiredInterfaceType:)`, `init(prohibitedInterfaceTypes:)` (14.0) | — | 12.0 / 14.0 [SDK] | — | as above | **supported** |
| Expensive / constrained / ultra-constrained | `isExpensive` (12.0), `isConstrained` (13.0, Low Data Mode), `isUltraConstrained` (**26.0**) | — | [SDK] | — | Toggle Low Data Mode and Personal Hotspot | **supported** |
| Unsatisfied reason | `unsatisfiedReason` = `.notAvailable/.cellularDenied/.wifiDenied/.localNetworkDenied`, `.vpnInactive` (17.0) | — | **14.2** [SDK] | — | Disable cellular data for the app | **supported** |
| Gateways, DNS, IPv4/IPv6 | `gateways` (13.0), `supportsDNS/IPv4/IPv6` | — | [SDK] | — | — | **supported** |

## 5. App-level latency / throughput / connection failures

| Field | Exact public API | Permission | Min iOS | Restrictions | Validation | Verdict |
|---|---|---|---|---|---|---|
| HTTP timing (DNS, TCP, TLS, TTFB, total) | `URLSessionTaskMetrics.transactionMetrics[]` → `fetchStartDate`, `domainLookupStart/EndDate`, `connectStart/EndDate`, `secureConnectionStart/EndDate`, `requestStart/EndDate`, `responseStart/EndDate`. `taskInterval`, `redirectCount` | None | Class iOS 10.0 [SDK] | Dates are nil for reused connections or local resources [SDK]. iCloud Private Relay sets `isProxyConnection`, `remoteAddress` becomes the proxy, and TLS dates may be missing [SDK] | Probe a known endpoint and compare with a server-side log | **supported** (own requests) |
| Bytes, addresses, transport facts | `countOfRequestHeaderBytesSent`, `countOfRequestBodyBytesSent`, `countOfResponseHeaderBytesReceived`, `countOfResponseBodyBytesReceived` (+ before/after encoding), `localAddress/Port`, `remoteAddress/Port`, `negotiatedTLSProtocolVersion/CipherSuite`, `isCellular`, `isExpensive`, `isConstrained`, `isMultipath`, `isReusedConnection`, `isProxyConnection`, `networkProtocolName` | — | Most fields **iOS 13.0**. `domainResolutionProtocol` **14.0** [SDK] | — | — | **supported** |
| RTT / retransmissions | `NWConnection.requestEstablishmentReport` (handshake RTT/duration, DNS resolutions; 13.0) and `startDataTransferReport().collect` → `transportSmoothedRTT`, `transportMinimumRTT`, `transportRTTVariance`, `retransmittedTransportByteCount`, duplicate/out-of-order bytes, packet counts | — | 13.0. `radioType` 15.0 [SDK] | Own NWConnection only [SDK] | Compare with `ping`/server stats | **supported** (own probes) |
| Device-wide byte counters | `getifaddrs()` → `AF_LINK` entries → `ifa_data` as `struct if_data` → `ifi_ibytes/ifi_obytes` | None | POSIX. Not marked deprecated [SDK] | **`ifi_ibytes`/`ifi_obytes` are `u_int32_t`, so they wrap at 4 GiB** [SDK `net/if_var.h`]. A 64-bit `struct if_data64` (`u_int64_t` counters) exists and is returned by `sysctl` `NET_RT_IFLIST2` in `struct if_msghdr2` [SDK `net/if.h`, `sys/socket.h`]. No Apple doc covers either. Interface naming (`en0` = Wi-Fi, `pdp_ip0…` = cellular) is convention, not documented [INFERRED]. Whether the iOS sandbox still returns non-zero counters is **unverified** | Download a known 50 MB file and compare deltas. Push more than 4 GiB to see the 32-bit wrap. Compare with the sysctl 64-bit path | **substitute** (device-wide totals, if counters are non-zero on device). Handle the wrap, or use `NET_RT_IFLIST2` |
| Per-app daily transfer | MetricKit `TotalCellularDownload/UploadMetric`, `TotalWiFiDownload/UploadMetric` (27.0), MX equivalents (13.0) | — | [SDK] | Daily, this app only [DOC] | — | **substitute** (not real time) |
| Connection failures | `URLError` codes, `NWConnection.State.failed(NWError)`, `NWPath.unsatisfiedReason`, `CTCellularData.restrictedState` | — | [SDK] | — | Airplane mode mid-probe | **supported** (own probes) |

**Privacy manifest (required-reason APIs) [DOC: `NSPrivacyAccessedAPIType` possible values].** There are exactly five categories:
`NSPrivacyAccessedAPICategoryFileTimestamp` (`creationDate`, `modificationDate`, `stat/fstat/fstatat/lstat`, `getattrlist*`…; reason
`C617.1` for app-container files), `…SystemBootTime` (`systemUptime`, `mach_absolute_time()`; `35F9.1` for elapsed time between in-app
events), `…DiskSpace` (`statfs/statvfs`, volume capacity keys…), `…ActiveKeyboards`, and `…UserDefaults` (`UserDefaults`; `CA92.1` for
app-only data). **`getifaddrs`, `sysctl`, CoreTelephony, NWPathMonitor and URLSessionTaskMetrics are not on the list** [DOC, by
absence]. SQLite calls `fstat`, so any SQLite/Drift layer needs FileTimestamp unless a dependency's own manifest already covers it
[INFERRED]. The manifest lives in the app bundle and in each SDK bundle that uses these APIs [DOC].

## 6. Foreground-app context

| Field | Exact public API | Permission / entitlement | Min iOS | Restrictions | Validation | Verdict |
|---|---|---|---|---|---|---|
| Which app is in the foreground (real time) | **No public API** [SDK, no such symbol found]. UIKit only reports the app's own state | — | — | Guideline 2.5.1: public APIs only [DOC] | — | **not available** → null |
| Screen Time aggregates (in-app UI only) | `FamilyControls.AuthorizationCenter.requestAuthorization(for: .individual)`, `DeviceActivityReport` + `DeviceActivityReportExtension`, `DeviceActivityCenter`/`DeviceActivityMonitor` (schedules, threshold events on user-picked tokens) | `com.apple.developer.family-controls`. Distribution needs an Apple request: "Before submitting your app to the App Store, you must [request] to use the entitlement" [DOC] | FamilyControls 15.0, `.individual` 16.0, DeviceActivityReport 16.0 [SDK] | The report extension "runs in a sandbox. This sandbox prevents your extension from making network requests or moving sensitive content outside the extension's address space" [DOC]. Apps are opaque `ApplicationToken`s [SDK] | — | **not available** for export. Threshold events on user-selected apps are at most a coarse, delayed signal [INFERRED, unverified] |
| Exportable per-app usage (**new**) | `DeviceActivityData.activityData(filteredBy:using:)` (policy `.cached/.live`), `FamilyActivityData.shared` (`installedApplications`, `visitedWebDomains`, `activityCategories`). `ManagedSettings.Application.bundleIdentifier` | `com.apple.developer.family-controls.app-and-website-usage` + auth status `.approvedWithDataAccess` | **iOS 26.4** [SDK/DOC] | "Customer installations … can only use the method on devices located in the **EU** that are signed in with an Apple Account with an EU country or region". "Only one app at a time can hold this authorization status on a given device" [DOC]. Granularity is `SegmentInterval.hourly/daily/weekly` [SDK] | EU device + EU Apple Account. Check that hourly segments show WhatsApp minutes | **substitute** (EU only, hourly aggregates, not "the foreground app now") |
| Call state | `CXCallObserver` + `CXCallObserverDelegate.callObserver(_:callChanged:)`. `CXCall.uuid`, `isOutgoing`, `isOnHold`, `hasConnected`, `hasEnded` (`callNotesStatus` iOS 27, feature-gated) | None | iOS 10.0 [SDK] | "any app can create a new CXCallObserver object to be notified of any calls activity on the system" [DOC]. **`CXCall` has no app/provider identity and no audio/video flag** [SDK]. Third-party VoIP calls show up only if that app uses CallKit [INFERRED]. Callbacks arrive only while our process runs (e.g., under the location keep-alive) [INFERRED] | Place a cellular call, a FaceTime call and a WhatsApp call while the app is backgrounded under keep-alive, and log the events | **supported** for "a call is active / connected / ended". **not available** for which app or video vs audio |
| China CallKit restriction | — | — | — | **unverified**: nothing in the docs or App Review Guidelines I fetched mentions China. Guideline 2.5.12 covers CallKit call blocking only [DOC] | — | unverified |

## 7. Background execution & continuity

| Capability | Exact public API | Plist / mode / entitlement | Min iOS & deprecation | Known restrictions | Validation | Verdict |
|---|---|---|---|---|---|---|
| App refresh | `BGAppRefreshTaskRequest(identifier:)`, `earliestBeginDate`, `BGTaskScheduler.shared.register(forTaskWithIdentifier:using:launchHandler:)` | `UIBackgroundModes: fetch` + `BGTaskSchedulerPermittedIdentifiers` | iOS 13.0 [SDK] | "provides your app up to 30 seconds" [DOC]. `earliestBeginDate` means "won't begin sooner", not a guarantee [DOC]. Adding `BGTaskSchedulerPermittedIdentifiers` disables the legacy `performFetch`/`setMinimumBackgroundFetchInterval` [DOC]. Disabled in Low Power Mode, together with Background App Refresh [DOC] | Xcode debugger `e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"id"]` (a debug-only technique; I did not re-check it in this pass), then observe real scheduling over several days | **supported** (opportunistic, not periodic) |
| Processing | `BGProcessingTaskRequest`: `requiresNetworkConnectivity` (default NO; if NO, "your app may not have network access"), `requiresExternalPower` | `UIBackgroundModes: processing` | iOS 13.0 [SDK] | "within the next two days as long as the user has used your app within the past week" [SDK]. "Processing tasks run only when the device is idle. The system terminates any background processing tasks running when the user starts using the device" [DOC] | Charge overnight and check the log | **supported** (good for overnight sync) |
| Registration rule | `register(...)` | — | — | "Registration of all launch handlers must be complete before the end of `application(_:didFinishLaunchingWithOptions:)`" (BGContinuedProcessingTask exempt). Registering the same id twice makes the system kill the app [SDK]. Flutter: register in `AppDelegate.didFinishLaunching` before `super` returns [INFERRED] | — | — |
| Submit API change | `submitTaskRequest:error:` **deprecated 13.0–27.0**. New `submit(_:) async throws` / completion-handler variant **iOS 27.0** [SDK] | — | — | Error codes: `.unavailable`, `.tooManyPendingTaskRequests`, `.notPermitted` (includes "user has explicitly denied background launches"), `.immediateRunIneligible` [SDK] | — | **supported** |
| Continued processing | `BGContinuedProcessingTask` / `BGContinuedProcessingTaskRequest(identifier:title:subtitle:)`, `.strategy` `.fail/.queue`, `.requiredResources` `.gpu` | GPU: `com.apple.developer.background-tasks.continued-processing.gpu` | **iOS 26.0** [SDK] | Must start in the foreground in response to a user action. Shown as a system Live Activity the user can cancel. The system kills tasks that show little progress [DOC]. Queued requests are "cancelled when the user removes your app from the app switcher" [SDK] | — | **not suited** to passive sampling (user-initiated, finite jobs) [INFERRED] |
| Health-research task | `BGHealthResearchTask(Request)` | — | iOS 17.0 [SDK] | Meant for health-research studies [DOC] | — | **not applicable** [INFERRED] |
| Short extension | `UIApplication.beginBackgroundTask(withName:expirationHandler:)` | — | — | `applicationDidEnterBackground` has 5 s, then the app is suspended. Extra time is limited (`backgroundTimeRemaining`). Not ending it means termination [DOC] | — | **supported** (seconds) |
| Silent push | `content-available: 1`, `apns-priority 5`, `apns-push-type background` | `UIBackgroundModes: remote-notification` | — | 30 s of run time. More than 3 per hour gets rate-limited. After a force-quit, the held notification is discarded [DOC] | — | **supported** (needs a server; FCM exists in the `qoesense` project [INFERRED]) |
| Continuous sampling at 60 s / 15 s | Only through the **location** keep-alive (§3) | `UIBackgroundModes: location` | — | Guideline 2.5.4: "apps may only use background services for their intended purposes: VoIP, audio playback, location…" [DOC]. Using location as a keep-alive for network sampling is an **App Review risk** unless location is a real research input [INFERRED] | 24 h soak test with the screen off | **substitute** (works, policy risk) |
| What suspends or kills | — | — | — | Suspension soon after backgrounding. The system "can terminate apps at any time to free up memory" [DOC]. Overrunning BG task time ends in termination [DOC]. Low Power Mode is "Pausing discretionary and background activities" and turns off Background App Refresh [DOC] | — | — |
| Low Power Mode detection | `ProcessInfo.isLowPowerModeEnabled`, `NSProcessInfoPowerStateDidChange` | — | iOS 9.0 [DOC] | Whether continuous location keeps running in Low Power Mode: **unverified** | Enable Low Power Mode during a soak test | **supported** (detection) |
| Force-quit effects (summary) | — | — | — | Ends a When-In-Use location session [SDK]. Always monitoring APIs still relaunch [SDK]. Drops held silent pushes [DOC]. Cancels queued continued-processing requests [SDK]. **BGAppRefresh/BGProcessing after a force-quit: unverified** (no Apple text found) | Swipe the app away, wait 24 h, check for BG launches | — |

## 8. MOS feedback presentation

| Capability | Exact public API | Permission / entitlement | Min iOS | Known restrictions | Validation | Verdict |
|---|---|---|---|---|---|---|
| Action buttons answered **without opening the app** | `UNNotificationCategory(identifier:actions:intentIdentifiers:options:)` + `UNNotificationAction(identifier:title:options:)` with **no** `.foreground` option → `userNotificationCenter(_:didReceive:withCompletionHandler:)` | `requestAuthorization(options: [.alert,.sound])` | iOS 10.0 [SDK] | "Tapping a button sends the selected action to the app, which then processes the action in the background" / "the system launches your app in the background" [DOC]. `.foreground` brings the app forward, `.authenticationRequired` requires an unlock, `.destructive` is styling only [SDK/DOC]. Always call the completion handler [DOC] | Lock the phone, long-press the notification, tap "3", check that the DB row was written | **supported** |
| Number of actions | `UNNotificationCategory.actions` | — | — | "When the system has unlimited space, the system displays up to 10 actions. When the system has limited space, the system displays at most two actions". "When displaying banner notifications, the system displays only the first two actions" [DOC] | Check the banner vs the expanded view | **supported** (5 MOS buttons show only in the expanded view) |
| Action icons | `UNNotificationActionIcon(systemImageName:)` / `(templateImageName:)`, `UNNotificationAction(identifier:title:options:icon:)` | — | **iOS 15.0** [SDK] | — | — | **supported** |
| Text input | `UNTextInputNotificationAction` | — | 10.0 [SDK] | — | — | **supported** |
| Interruption level | `UNMutableNotificationContent.interruptionLevel` = `.passive/.active/.timeSensitive/.critical`, `relevanceScore` | `.timeSensitive`: entitlement `com.apple.developer.usernotifications.time-sensitive`, a self-serve capability ("Time Sensitive Notifications", `distributionApprovalRequired: false`) [SDK/Xcode]. `UNAuthorizationOptionTimeSensitive` deprecated 15.0–15.0 "Use time-sensitive entitlement" [SDK]. `.critical`: `com.apple.developer.usernotifications.critical-alerts`, which Apple must grant ("To request this entitlement…") [DOC] | 15.0 [SDK] | Time Sensitive "can break through system controls such as Notification Summary and Focus. The user can turn off" this [DOC]. Check `UNNotificationSettings.timeSensitiveSetting` (15.0) [SDK] | Enable a Focus mode and confirm delivery | **supported** (time-sensitive). Critical is **not appropriate** |
| Remove a stale prompt | `removeDeliveredNotifications(withIdentifiers:)`, `removeAllDeliveredNotifications()`, `removePendingNotificationRequests(withIdentifiers:)`, `getDeliveredNotifications` | — | iOS 10.0 [SDK/DOC] | Asynchronous [DOC] | — | **supported** |
| Draw over other apps | **None** (no overlay-window API) [SDK, none found] | — | — | — | — | **not available**. The closest thing is AVKit Picture in Picture, which needs real video content (video-call PiP, iOS 15) [DOC]; not suitable [INFERRED] |
| Live Activity as a MOS surface | `ActivityKit.Activity.request(attributes:content:pushType:)` (16.2), `request(... style:)` (18.0, `.transient`), scheduled `request(... alertConfiguration:start:)` (26.0). `pushToStartTokenUpdates` (**17.2**). Buttons via App Intents `LiveActivityIntent` (**17.0**) | `NSSupportsLiveActivities = YES` + a widget extension | ActivityKit **16.1** [SDK] | Active for up to 8 h, then up to 4 more hours on the Lock Screen (12 h max). 4 KB data limit. "In general, your app needs to be in the foreground to start a Live Activity", except through `LiveActivityIntent` or push [DOC] | Start it during a video call, tap a rating button, check the write | **substitute** (iOS 17+ for buttons. Must start in the foreground or by push) |

## 9. Local persistence & sync

| Capability | API | Entitlement | Min iOS | Known restrictions | Validation | Verdict |
|---|---|---|---|---|---|---|
| Default file protection class | `FileProtectionType` / `URLFileProtection` via `Data.write(options:)`, `setResourceValue(_:forKey: .fileProtectionKey)` | Optional `com.apple.developer.default-data-protection` (Data Protection capability) to change the app-wide default [DOC] | iOS 4/5 [DOC] | "Complete until first user authentication. **(Default)** The file is inaccessible until the first time the user unlocks the device" [DOC]. Other classes: None, CompleteUnlessOpen, Complete [DOC]. For files used in the background, Apple suggests a weaker class than Complete (e.g., CompleteUnlessOpen for a background location log) [DOC] | `FileManager.attributesOfItem(...)[.protectionKey]` on the DB, WAL and SHM files | **supported** |
| Open SQLite **before first unlock** after a reboot | — | — | — | Default-class files can't be read until the first unlock [DOC]. A background relaunch (SLC/visit) before first unlock would fail to open the DB unless the files are `FileProtectionType.none` [INFERRED]. Whether iOS relaunches apps before first unlock at all: **unverified**. `UIApplication.isProtectedDataAvailable` and `protectedDataDidBecomeAvailableNotification` (4.0) [DOC] tell you when it's safe | Reboot, don't unlock, move more than 1 km (Always + SLC), unlock, check `os_log` in Console.app | **substitute**: detect this case and buffer in memory or wait for `protectedDataDidBecomeAvailable`, or move the DB to class None (privacy trade-off) |
| UserDefaults before first unlock | `UserDefaults` | Privacy manifest `CA92.1` [DOC] | — | **unverified**: no Apple doc text found. I expect it to read as empty or default before first unlock, because the plist sits in the container under the default class [INFERRED] | Same reboot test. Log a known key | unverified, so don't rely on it before unlock |
| Prewarming | — | — | — | "The system can prewarm your app after a device reboot". It "suspends your process without allowing any application code to run" [DOC] | — | Note: don't do I/O in static initializers [INFERRED] |

---

## Surprises: things that contradict common assumptions

1. **CTCarrier is frozen for us, on every iOS version we'll ever run (≥16.4).** Static values apply to "apps that are built with the iOS
   16.4 SDK or later" [DOC]. The header gives the values: `--` (name/ISO), `65535` (MCC/MNC), `YES` (allowsVOIP) [SDK]. iOS 15.0–16.3
   devices may still return real values [INFERRED, unverified]. Treat both as null.
2. **NR constants exist since iOS 14.1** [SDK]. Network.framework can **tell 5G NSA from SA and sub-6 from mmWave** for the app's own
   connections (`PathReport.radioType`, iOS 15) [SDK]. That is more detail than CoreTelephony gives.
3. **New in iOS 26: `NWPath.linkQuality`** (unknown/minimal/moderate/good) and `isUltraConstrained` [SDK]. They are the only public
   "radio quality" signals, and they are not RSRP.
4. **New in iOS 26.4: exportable Screen Time data**: `DeviceActivityData.activityData` and `FamilyActivityData`, with real bundle IDs.
   Customer installs get it only in the **EU**, one app per device, with a special entitlement, at hourly granularity [DOC/SDK]. It
   still can't say what is in the foreground now.
5. **MetricKit was redesigned in iOS 27** (`MetricManager`, `MetricResult`, `CellularConditionTimeMetric` with `SignalBars`) [SDK].
   `MXCellularConditionMetric` is marked to-be-deprecated in the SDK and "dep 27.3" in the docs [SDK/DOC]. This is the only
   signal-bar data available, and it is a daily aggregate.
6. **`BGTaskScheduler.submit(_:) throws` is deprecated in iOS 27.0** in favor of an async/completion variant [SDK].
7. **Always + monitoring APIs relaunch the app even after the user force-quits it** (header text) [SDK]. Many developers assume a
   force-quit blocks every relaunch. A When-In-Use continuous session does end when the user kills the app [SDK].
8. **`pausesLocationUpdatesAutomatically` defaults to YES.** For When-In-Use apps, a pause "ends access to location changes until the
   app launches again" [DOC/SDK]. A keep-alive must set it to NO.
9. **`getifaddrs` byte counters are 32-bit** (`u_int32_t ifi_ibytes/ifi_obytes`). 64-bit counters exist only through `sysctl`
   `NET_RT_IFLIST2` / `if_msghdr2` [SDK]. `getifaddrs` is **not** a required-reason API [DOC]. `UserDefaults`, `systemUptime` /
   `mach_absolute_time` and `stat`-family file timestamps are [DOC].
10. **`CXCallObserver` sees every CallKit call on the system** [DOC] but can't say which app or audio vs video [SDK].
11. **Notification actions run in the background without opening the app** [DOC]. A banner shows only the first **two** actions; the
    expanded view shows up to 10 [DOC]. A 5-point MOS scale needs a long-press, or a 2–3 step design.
12. **`requestLocation()` while services already run on the same manager "does nothing"** [DOC]. It doesn't even report an error.
13. **CLServiceSession (iOS 18):** an Always app that doesn't hold an `.always` session gets no `liveUpdates()`/`CLMonitor` events
    when it isn't in use [SDK].
14. **Live Activities**: 8 h active / 12 h max, 4 KB. Interactive buttons need iOS 17 (`LiveActivityIntent`). Push-to-start needs
    17.2 [SDK/DOC].

## Could not verify (needs a device or a source I didn't find)

- The exact `requestLocation()` timeout. Whether the "does nothing" rule is per manager or app-wide.
- Whether `getifaddrs`/`sysctl` interface counters are non-zero for third-party apps on current iOS.
- Whether iOS relaunches an app (SLC/visits) before first unlock after a reboot. UserDefaults readability before first unlock.
- Whether BG refresh/processing tasks run after a user force-quit.
- Whether continuous background location keeps running in Low Power Mode.
- Whether CLBackgroundActivitySession relaunches a system-terminated When-In-Use app in practice.
- Any China-specific CallKit / CXCallObserver restriction.
- What CTCarrier returns on iOS 15.0–16.3 devices for an app built with the 27.2 SDK.

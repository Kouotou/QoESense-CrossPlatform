# Phase 4: iOS

**Status (2026-11-09):** code complete on branch `phase4/ios`. It compiles with Xcode 27.2,
and the Dart and XCTest suites pass. **Not yet validated on an iPhone.** The device protocol
(§8) still has to run, and three items wait for the owner (§9).

This document covers how iOS collects, what it can't collect, and how it differs from
Android. The capability research, one row per field, with the API, permission, iOS version,
restrictions and device test, is in [IOS_CAPABILITY_MATRIX.md](IOS_CAPABILITY_MATRIX.md).

## 1. What an iPhone can measure

| Contract group | iOS source | On the wire | Status on iOS |
|---|---|---|---|
| `radio` (RSRP, RSRQ, RSSNR, TA, cell hash, TAC, bars) | No public API in the iOS 27.2 SDK; no entitlement unlocks it | always null | always `NOT_SUPPORTED` |
| `cqi` | none | null, `cqiSupported = false` | always `NOT_SUPPORTED` |
| `physicalChannel` | none | null | always `NOT_SUPPORTED` |
| `networkType` | `CTTelephonyNetworkInfo.serviceCurrentRadioAccessTechnology[dataServiceIdentifier]` | `LTE`; `NR` (NR or NR-NSA); `OTHER` (3G/2G/CDMA); `UNKNOWN` (no service, no SIM, airplane mode) | `OK`; `NOT_SUPPORTED` without a modem (simulator, Wi-Fi iPad) |
| `connectivity` | `NWPathMonitor`: Wi-Fi first, then cellular, else other | `WIFI` / `CELLULAR` / `OTHER`; `isRoaming` always null (CTCarrier returns static values since the 16.4 SDK) | `OK`; `UNAVAILABLE` with no usable path |
| `throughput` | `getifaddrs` link counters of `en*` + `pdp_ip*`, rx+tx, averaged since the previous capture | bytes/s + `throughputWindowMs` | `OK`; `UNAVAILABLE` on the first capture after a (re)start; `FAILED` if the counters can't be read |
| `rtt` | shared Dart `HttpRttProbe`, unchanged | ms + `rttMethod` | as on Android |
| `foregroundApp` | none (iOS 26.4's exportable Screen Time data is EU-only, hourly and one app per device) | null | always `NOT_SUPPORTED` |
| `appSessionType` | `CXCallObserver`: a connected, not ended call | `VIDEO_CONFERENCING` during any CallKit call (D-4), else `NONE` | — |
| `location` | Core Location, one `requestLocation()` per tick at 100 m, keep-alive fix as fallback | lat/lon, `horizontalAccuracy`, `locationAgeMs` from `CLLocation.timestamp` | `OK` / `STALE` / `PERMISSION_DENIED` / `RESTRICTED` / `TIMEOUT` / `UNAVAILABLE` / `FAILED` |
| `deviceModel`, `androidVersion`, `osVersion` | `utsname.machine` (e.g. `iPhone15,3`), the iOS major version (D-5), the full version | | |
| tier | `CapabilityTierResolver` | always `IOS_RAT` (D-3) | |

Every iOS sample passes `contractViolations` (`test/platform/ios_mapping_test.dart`). A
capture identical to the I1 golden record serializes byte for byte the same as the fixture.
Uploads stay on **contract v1**: `BatchSerializer.defaultVersion` is unchanged.

**Not used, though available (each would need a contract change, DATA_CONTRACT §7):**
- `NWPath.linkQuality` (iOS 26, 4 levels);
- the per-connection 5G NSA/SA radio type (iOS 15);
- `accuracyAuthorization` (whether the participant chose approximate location);
- MetricKit's daily signal-bar histogram.

These are candidates for a future v3 proposal. They are not estimates of RSRP.

## 2. How it runs

```
AppDelegate.didFinishLaunching ── IosCollectorHost.launch()        (every launch: user, location, BGTask, notification)
   │                                   ├─ BGTaskScheduler.register("…upload")
   │                                   ├─ notification category + delegate
   │                                   └─ if collection enabled + consent: start
   │                                          ├─ LocationService.startKeepAlive()   keeps the process alive
   │                                          └─ headless FlutterEngine "collectorMain" → shared Dart Collector
   └─ UI engine (FlutterImplicitEngineDelegate): screens only, never collects
```

- **The same Dart loop as Android.** A headless `FlutterEngine` runs `collectorMain`. This is
  the same `Collector`, `SamplingPolicy` (60 s / 15 s), `SurveyScheduler` and `MosPipeline`.
  `IosCollectorHost` plays the role of the Android `CollectorService`. The UI engine never
  collects, so a launch by the participant, a location relaunch, a BGTask or a notification
  all start collection the same way, with no double sampling.
- **Staying alive.** `startUpdatingLocation` at 3 km accuracy, with background updates allowed,
  automatic pausing off, and the blue background-location indicator shown. While it runs,
  iOS doesn't suspend the process, so Dart timers fire. The indicator is the iOS counterpart
  of Android's "collection active" notification.
- **Relaunch.** With Always, `startMonitoringSignificantLocationChanges` relaunches the
  terminated app after a move of about 500 m. Per the SDK header, this happens even after a
  force-quit (to confirm on a device).
- **Wake-ups.** Keep-alive location updates are forwarded to Dart as `wakeTick`, at most every
  30 s. `Collector.wake` ignores a wake-up that comes before the interval is up (same as the
  Android `WakeAlarm`).
- **Location per tick.** A second `CLLocationManager` calls `requestLocation()` at 100 m,
  bounded by the `SamplingPolicy` timeout (15 s, or 8 s in a call). If it gives nothing, a
  keep-alive fix younger than the sampling interval is used, with its own (coarse) accuracy.
  Otherwise the status says why there is no fix.
- **Uploads.** iOS has no WorkManager for a running app. The collector engine drains the buffer
  itself, after a tick, through `UploadGate`:
  - at most once an hour;
  - only when `uploadConstraintsMet()`: a usable path that isn't expensive (cellular, hotspot)
    or constrained (Low Data Mode), and Low Power Mode off;
  - never two runs at once.

  A `BGProcessingTask` (`requiresNetworkConnectivity`, earliest 1 h) is a fallback for a
  suspended or terminated app: it relaunches the app, and the collector reports back through
  `uploadRunFinished`. Drain-then-retain and the 45-day retention are the shared `UploadDrain`.
- **Before first unlock after a reboot**, UserDefaults and the database can't be read.
  Collection starts on `protectedDataDidBecomeAvailable` instead.

## 3. Files

| File | What |
|---|---|
| `ios/Runner/IosCollectorHost.swift` | `IosCollectorApi`, engine lifecycle, BGTask, prefs |
| `ios/Runner/IosCapture.swift` | RAT, path, throughput, CallKit, device info → `CapturedSampleMessage` |
| `ios/Runner/IosLocation.swift` | keep-alive, relaunch, per-tick fix, authorization prompts |
| `ios/Runner/IosSurvey.swift` | notification category, delegate, durable answer queue |
| `ios/Runner/IOSCapabilityReporter.swift` | the capability report (shared helpers) |
| `ios/Runner/Info.plist`, `*.lproj/InfoPlist.strings` | location purpose strings (EN/FR), `UIBackgroundModes` `location` + `processing`, `BGTaskSchedulerPermittedIdentifiers`, `CFBundleLocalizations` |
| `ios/Runner/PrivacyInfo.xcprivacy` | required-reason APIs: UserDefaults `CA92.1`, file timestamps `C617.1` (SQLite) |
| `ios/RunnerTests/RunnerTests.swift` | XCTest for the pure Swift logic |
| `pigeons/telemetry_api.dart` | `IosCollectorApi`, `SurveyUiEvents`, `CollectorEvents.uploadRequested`, self-report fields on `SurveyAnswerMessage` |
| `lib/src/platform/ios_collector.dart` | Dart adapters |
| `lib/src/application/path_anomaly_detector.dart`, `upload_gate.dart`, `self_report.dart` | shared rules (pure Dart) |
| `lib/src/presentation/survey_sheet.dart` | the in-app survey |

The pigeon file also generates Kotlin. Android doesn't implement the new iOS interface; the
only other Kotlin change is two nullable fields at the end of `SurveyAnswerMessage`, which the
named-argument constructors in `MosSurvey.kt` and `CollectorPrefs.kt` don't need. **The Android
build still has to be confirmed on Windows** (`tool\verify.ps1`). This Mac's Android SDK only has
`android-37.0`, which the Gradle build doesn't resolve.

## 4. The survey on iOS

iOS can't draw over other apps, so the prompt is a local notification
(`SurveyNotifications.present`). Its EN/FR text comes from the Android `strings.xml`, adapted
for the iOS gestures.

| How the participant answers | Result |
|---|---|
| Touch and hold, then tap one of the 5 actions (`1 ★` … `5 ★★★★★`). They work from the lock screen, without opening the app. | queued natively, `presentationMode = NOTIFICATION_ACTION`, context `UNKNOWN` |
| Tap the notification → the app opens the sheet: 1–5, plus the optional "what were you doing?" | `presentationMode = NOTIFICATION`. With an answer: `SELF_REPORTED` with the Android package name (D-6). If skipped: `UNKNOWN` |
| Status screen → "Send test survey" | posts the same notification |

- A banner shows only the first two actions, so the body text says "touch and hold".
- A new prompt replaces an unanswered older one; there is one notification identifier.
- Taps go to `survey_answers.json` (Application Support, written atomically, protection "until
  first unlock"). Dart reads them, stores them durably, and only then acknowledges them, as on
  Android.
- The tap time is `submittedAtMs`, and the window is `[tap − 10 min, tap]`, unchanged.
- **Self-report answers (`SelfReportOption`):**

  | Answer | `contextAppPackage` | `contextSessionType` |
  |---|---|---|
  | WhatsApp call | `com.whatsapp` | `VIDEO_CONFERENCING` |
  | WhatsApp messages or status | `com.whatsapp` | `SOCIAL_MEDIA` |
  | Facebook | `com.facebook.katana` | `SOCIAL_MEDIA` |
  | Instagram | `com.instagram.android` | `SOCIAL_MEDIA` |
  | Zoom | `us.zoom.videomeetings` | `VIDEO_CONFERENCING` |
  | Google Meet | `com.google.android.apps.meetings` | `VIDEO_CONFERENCING` |
  | Something else | null | `NONE` |

  A test pins every package to the Android `MonitoredApps` lists.
- The M2 fixture (`NOTIFICATION_ACTION` + `SELF_REPORTED`) stays a valid contract record. This
  implementation doesn't produce it, because an action tap can't ask a second question.

## 5. Permissions and onboarding

The same five screens as Android, with iOS texts:

1. welcome;
2. consent;
3. location **When In Use**;
4. location **Always**, then notifications;
5. a last step that replaces Android's usage access / battery / overlay screen. It shows
   whether Always and notifications were granted (with **Open Settings** if not), and tells
   the participant not to force-quit the app.

The prompts are native (`IosCollectorApi.requestLocation*`, `requestNotifications`), not
permission_handler. That avoids permission_handler's Podfile macros. It also handles the
Always upgrade, which iOS shows at most once and which doesn't report back when the answer
is "Keep Only While Using".

The iOS consent, welcome and permission texts (EN + FR) are **drafts**. They are marked as
drafts in `app_en.arb` and need the owner's approval before any iOS participant (§9).

## 6. Proposed iOS rules (owner to confirm)

**ANOMALY trigger** (`PathAnomalyDetector`, iOS only; Android keeps the RSRP detector
unchanged). Each of these flags an anomaly:

- the path is lost;
- Wi-Fi ↔ cellular switch;
- on cellular, LTE/NR → older RAT or none (NR ↔ LTE flips don't count);
- an RTT at least twice the median of the last 10 and at least 200 ms above it, once 5 exist;
- 2 failed RTT probes in a row on a usable path.

Throughput is deliberately not a trigger: device-wide traffic measures the participant's use,
not the network. Rate limits are the shared ones: 10 min cooldown, 6 a day.

**Other choices:**
- **Call detection:** a call counts once it is *connected*. A ringing or dialling call doesn't.
- **Location:** 3 km keep-alive, 100 m one-shot per tick. A battery test is in §8.

## 7. Differences from Android (no feature parity claimed)

| Topic | Android | iOS |
|---|---|---|
| Radio (RSRP…), CQI, physical channel | measured | **not available**: null, `NOT_SUPPORTED`, tier `IOS_RAT` |
| Roaming | `NET_CAPABILITY_NOT_ROAMING` | **not available** (null) |
| Foreground app | UsageStats | **not available**. Self-report in the survey sheet instead (D-6) |
| Video call detection | Zoom/Meet/Classroom in the foreground, or WhatsApp + audio mode | any connected CallKit call (D-4): which app, and whether it is video, is unknown |
| ANOMALY trigger | RSRP drop/spike/stability | path / RAT / RTT rules (§6, proposed) |
| Keeping alive | foreground service + notification | background location + blue indicator. Needs "Always" for relaunches |
| Cadence | 60 s / 15 s, plus Doze wake-ups every ~10 min | 60 s / 15 s **while iOS keeps the app alive**. Gaps are real and never back-filled |
| After a force-quit | the service survives the app being swiped away | collection stops; with Always, iOS relaunches it on the next significant move (unverified) |
| After a reboot | `BootReceiver` | a significant location change relaunches the app, after the first unlock |
| Survey | overlay over any app, auto-dismissed after 8 s | notification: actions without opening the app, or tap → in-app sheet |
| Uploads | WorkManager hourly, unmetered, battery not low | in-loop hourly on a non-expensive, non-constrained path with Low Power Mode off, plus BGProcessingTask |
| Throughput window | `elapsedRealtime` | `CLOCK_MONOTONIC` (also counts sleep); 32-bit counters with wrap handling |
| Location age | `elapsedRealtimeNanos` (monotonic) | `CLLocation.timestamp` (**wall clock**: a clock change skews the age) |
| `androidVersion` | SDK_INT | iOS major version (D-5) |

**Gaps.** The contract has no gap record, and adding one would change the schema. Gaps show in
the data in two ways:
- as missing time between `timestampMs` values;
- the first row after every collector (re)start has `throughputStatus = UNAVAILABLE` with a
  null `throughputWindowMs`.

An explicit `collectorStartReason` / gap field would be a v3 proposal.

## 8. Testing

**Automated (green on 2026-11-09):**
- `flutter test`: the existing suites plus
  - iOS mapping and contract tests;
  - iOS anomaly rules;
  - upload gate;
  - MOS self-report;
  - iOS collector ticks;
  - iOS onboarding;
  - the survey sheet.
- XCTest (`ios/RunnerTests`), on the iOS simulator:
  - RAT mapping;
  - path and call mapping;
  - throughput (window, 32-bit wrap, reset, new interface);
  - location status rules;
  - survey actions;
  - the durable queue across relaunches;
  - capability report mapping.

Run them all with `./tool/verify.sh`.

**Physical iPhone protocol.** Every check also compares with the Android protocol in
PHASE3_ANDROID.md §5.

| # | Check | How | Pass |
|---|---|---|---|
| 1 | Onboarding | Fresh install, all five steps; answer "While Using", then "Change to Always Allow", then allow notifications | Nothing runs before "I agree". After "Finish", status shows collection on, and the blue indicator shows when the app is in the background |
| 2 | Capability screen | Status screen | Radio, CQI, physical channel, foreground app and overlay show "Not supported"; network type, connectivity, throughput, call detection and location are available; background location only with Always |
| 3 | Capture | "Run telemetry test" on Wi-Fi, then on cellular | `networkType` matches the status bar (LTE / 5G); `connectionType` is right; RTT has a value; location accuracy is plausible; throughput is non-null from the second capture on (confirms getifaddrs counters are non-zero) |
| 4 | Background, 1 h | Lock the phone for 1 h in a pocket, with some movement | ~60 samples/h (Download Container → `Documents/qoesense.sqlite` + WAL). Note gaps |
| 5 | Call cadence | A 10 min FaceTime or WhatsApp call with the app in the background | ~15 s spacing during the call; a POST_SESSION prompt after it (15 min cooldown) |
| 6 | Network transitions | Wi-Fi → cellular → airplane mode → Wi-Fi | `connectionType` / `connectivityStatus` follow; at most one ANOMALY prompt per 10 min |
| 7 | Survey from the notification | Long-press a prompt and tap "3"; another time tap it and answer the sheet | One `pending_mos_responses` row each, with `NOTIFICATION_ACTION` / `NOTIFICATION` and SELF_REPORTED for the sheet; the native queue is empty afterwards |
| 8 | Lock-screen answer | Answer an action while the phone is locked | Stored (the app was launched in the background) |
| 9 | Force-quit and relaunch | Swipe the app away, move more than 1 km | With Always: samples resume after the move. Record whether they did |
| 10 | Reboot | Reboot, unlock, move | Collection resumes after the first unlock |
| 11 | Permission revoked | Settings → Location → Never, mid-run | `locationStatus = PERMISSION_DENIED`; collection otherwise continues while the app runs |
| 12 | Storage + sync | Airplane mode 1 h, then Wi-Fi; check `Upload now` | The buffer grows, then drains only after a confirmed upload. Until Firebase iOS is registered, the backend is unconfigured, so it must **not** drain |
| 13 | Battery | 24 h with normal use | Record the Settings → Battery share for QoESense |

**Results:** see PHASE4_MAC_HANDOFF.md §7.

## 9. Waiting for the owner

1. **Approve or correct the iOS consent, welcome and permission texts** (EN + FR), §5. They are
   needed before any iOS participant.
2. **Confirm or change the proposed rules** in §6: the anomaly rules, call counting and the
   location accuracy.
3. ~~Register the iOS app in Firebase~~: done on 2026-11-10. `QoESenseFirebaseOptions.ios`
   holds the values. Uploads still depend on the Firebase billing fix; until it lands, a failed
   upload leaves the data buffered on the phone.

Also open:
- **App Store review risk.** Guideline 2.5.4 limits background location to its intended use.
  Here location is a real research input, recorded with every sample, but the case must be
  made at review. TestFlight or ad-hoc distribution avoids it for the pilot.
- **iCloud backups.** The buffer lives in Documents, which iCloud backups include. Excluding it
  needs a drift path change; it is not done.

# Phase 3: Android integration

**Status (2026-11-09): validated on a physical phone** (Infinix X669, Android 12, 2 days of
collection, 1,103 samples). See §7 for the results. Still open: the battery comparison, and
uploads to BigQuery (Firebase billing is blocked).

The reference app `../QoESense` wasn't modified.

## 1. Where each reference component went

Every class in the handbook's list exists in the reference under that name. That was checked
before porting (`app/src/main/java/com/example/qoesense/...`).

| Reference (Kotlin) | New location | Kind |
|---|---|---|
| `telemetry/CellularTelemetrySource` | `android/.../capture/CellularTelemetrySource.kt` | Kotlin port: same serving-cell choice, sentinels, hash and PhysicalChannelConfig listener. Adds per-group status, the CellInfo age, and the stale check. |
| `telemetry/AppUsageMonitor` + `MonitoredApps` | `capture/ContextSamplers.kt` | Kotlin port: same package lists, classification and WhatsApp-call heuristic. One fix, see §3 D. |
| `telemetry/LocationSampler` | `capture/ContextSamplers.kt` | Kotlin port: same balanced-power one-shot with a double timeout. Adds the fix age, and separates TIMEOUT / FAILED / UNAVAILABLE. |
| `telemetry/ThroughputSampler` | `capture/ContextSamplers.kt` | Kotlin port: the same TrafficStats rx+tx delta. Adds the window. |
| `telemetry/ConnectivitySampler` | `capture/ContextSamplers.kt` | Kotlin port, unchanged |
| `telemetry/LatencySampler` | `lib/src/data/network/http_rtt_probe.dart` | **Shared Dart:** the same URL and the same 4 s + 4 s timeouts, with a new connection per probe |
| `telemetry/TelemetrySampler` | `collector/AndroidCollectorHost.captureSample` + `lib/src/application/captured_sample.dart` (`assembleSample`) | One native call per tick returns the whole capture (RTT excepted). Dart assembles the v2 sample. |
| `telemetry/TelemetryCapabilityResolver` | `lib/src/application/capability_tier_resolver.dart` | Shared Dart, same rule (Phase 1) |
| `telemetry/TelemetryAnomalyDetector` | `lib/src/application/rsrp_anomaly_detector.dart` | Shared Dart, same thresholds (Phase 1) |
| `service/SamplingScheduler` | `lib/src/application/sampling_policy.dart` | Shared Dart: 60 s / 15 s, location 15 s / 8 s, RTT every 5th tick / every tick |
| `service/survey/SurveyTriggerPolicy` | `lib/src/application/survey_trigger_policy.dart` | Shared Dart, same rules and local-day cap |
| `service/survey/MosSurveyScheduler` + `data/MosSurveyPreferences` | `lib/src/application/survey_scheduler.dart` (state in SQLite) + `android/.../survey/MosSurvey.kt` (presentation) | Decision logic in Dart; overlay or notification fallback native |
| `ui/survey/MosSurveyActivity` + `MosSurveyScreen` | `survey/MosSurvey.kt` | Native: same text, 1–5 buttons, 8 s auto-dismiss, dismiss on an outside tap, same manifest attributes. Built with plain Views instead of Compose. |
| `service/survey/MosSubmitWorker` + `data/MosSurveyRepository` | `lib/src/application/mos_pipeline.dart` + `data/backend/firebase_backend.dart` | Shared Dart: the same 10-minute context window and the same idempotent `set` on a tap-time UUID |
| `service/TelemetryForegroundService` | `collector/CollectorService.kt` (lifetime) + `lib/src/application/collector.dart` (loop body) | Native service: dataSync\|location, low-priority notification, START_STICKY. It hosts a headless Flutter engine running the loop; the steps are in the reference order. |
| `service/BootReceiver` | `collector/BootReceiver.kt` | Native, the same rule |
| `service/upload/TelemetryUploadWorker` + `UploadScheduler` | `upload/Upload.kt` (WorkManager) + `lib/src/application/upload_drain.dart` | Native scheduling with the same constraints. The drain is shared Dart: the same 20 × 2,000 rows, drain-then-retain, and delete only after a confirmed upload. |
| `data/upload/BatchSerializer` | `lib/src/data/upload/batch_serializer.dart` | Shared Dart, pinned byte for byte (Phase 2) |
| `data/upload/DeviceIdentityProvider` + `FirebaseAuthDeviceIdentityProvider` | `data/backend/backend_ports.dart` + `firebase_backend.dart` | Shared Dart: anonymous Auth UID |
| `data/upload/FirebaseStorageUploadDestination` | `firebase_backend.dart` | The same path, `telemetry/{uid}/{date}/{uuid}.json.gz` |
| `data/ConsentRepository` + `OnboardingPreferences` | `presentation/qoesense_app.dart` + `SettingsKeys` | The local flag gates collection; the server record is best effort |
| `data/CollectionStatePreferences` | `collector/CollectorPrefs.kt` | Native, because BootReceiver reads it before any engine exists |
| Room `TelemetrySampleEntity` / `TelemetryDao` / `QoESenseDatabase` / `TelemetrySampleMapper` | `lib/src/data/local/database.dart`, `drift_stores.dart`, `sample_codec.dart` | SQLite (drift). Each row stores the contract-v2 JSON, so new fields need no migration. The same DAO operations. |
| `util/PermissionUtils` | `capture/PermissionUtils.kt` | Kotlin port, unchanged |
| `ui/onboarding/*` (5 screens) | `presentation/onboarding_screen.dart` | The same five steps, in order, with the same English and French text (consent included) |
| `ui/status/*` | `presentation/status_screen.dart` | The same controls, plus the capability report |
| `RootedTelemetrySource` | not ported | It's disabled in the reference (MIGRATION_MATRIX) |

## 2. How the pieces connect

```
CollectorService (Kotlin, foreground)                UploadWorker (Kotlin, WorkManager 1 h, Wi-Fi, battery OK)
  └─ headless FlutterEngine "collectorMain"           └─ headless FlutterEngine "uploadMain"
       Collector.tick() every 60 s / 15 s                 UploadDrain → Firebase Storage
         ├─ AndroidCollectorApi.captureSample ──► Kotlin samplers (1 call/tick)
         ├─ HttpRttProbe (Dart, concurrent with the location wait)
         ├─ drift buffer.append  (before anything else)
         ├─ SurveyScheduler → AndroidCollectorApi.presentSurvey ──► MosSurveyActivity / notification
         └─ MosPipeline: native tap queue → drift pending queue → Firestore set
MainActivity: UI engine (onboarding, status). All three engines open the same SQLite file (WAL).
```

## 3. Differences from the reference

Each one is deliberate and visible in the data.

| # | Behaviour | Reference | New app | Why |
|---|---|---|---|---|
| A | Sampling interval | 60 s / 15 s on `main` (the Phase 3 prompt says 20 s / 5 s) | **60 s / 15 s** | Agreed on 2026-11-07. The 20 s / 5 s values are superseded. |
| B | Local retention | 45 days (the prompt says 14) | **45 days**, a single constant `UploadDrain.retention` | It's the reference's current value, and uploads are still blocked by billing. Going back to 14 days needs your approval and should wait until uploads flow. |
| C | `networkType` availability | Null whenever no LTE cell was visible | Read independently, with `networkTypeStatus` | Same values and meaning, more often present. It's distinguishable by `schemaVersion`. |
| D | Foreground app detection ✅ **confirmed by owner** | Only events from the **last 10 s** were examined, so an app used for longer than 10 s came back as "no app" | The foreground app is **tracked across calls** (every event since the previous capture) | A bug fix: at a 60 s cadence the reference misses most of the time someone spends in an app. Expect many more non-null `foregroundAppPackage` / `SOCIAL_MEDIA` rows. ⚠ **Needs your confirmation.** |
| E | MOS rating that keeps failing | Dropped after 10 WorkManager attempts | **Never dropped.** Kept in SQLite, retried with backoff capped at 1 h | Offline guarantee |
| F | RTT implementation | `HttpURLConnection` | Dart `HttpClient`, with a new connection per probe | Same probe definition. `rttMethod` labels new rows, because the two implementations' timings aren't comparable. |
| G | Throughput clock | Wall clock | Monotonic clock | A change to the wall clock can no longer distort the rate. `throughputWindowMs` is recorded. |
| H | Foreground-service type | Always `dataSync\|location` | `location` is added only while location permission is held | On Android 14+, starting a location-type service without the permission crashes |
| I | Survey UI toolkit | Compose | Plain Android Views | No Compose dependency, and no Flutter engine needed to draw over other apps. The text and behaviour are the same. |
| J | Upload format | v1 | Stored as v2. **Uploaded as v1** until the v2 functions are deployed. | Rows uploaded before the switch-over lose their v2 metadata, so keep v1 only until the deploy. |
| K | Anomaly input | RSRP fed in, stale or not | **Only fresh (`OK`) readings** | Owner decision 2026-11-07: repeated cached values faked "prolonged stability". The detector's thresholds are unchanged. |
| M | Freshness of the radio reading | `getAllCellInfo()`, which returns the modem's cache | `requestCellInfoUpdate()` on each capture (API 29+, ≤5 s, concurrent with location). It falls back to the cache, marked STALE. | **Found on device:** on the Infinix X669 (Android 12), every cached reading was 7–10 min old with an identical RSRP. This is the root cause of the reference's duplicate rows. |
| N | Restart after an app update | Collection stayed off until a reboot or until the app was opened | BootReceiver also handles `MY_PACKAGE_REPLACED` (exempt from Android's background-start limits) | Updates during the study no longer silently stop collection |
| L | Process cost | One process, one Kotlin loop | One process, with the Flutter engine kept running in the background | **Must be measured on the device** (§5, battery). |

**Not preserved exactly:** the reference recorded the Status test-button sample with the
same pipeline. The new app does too, but its own throughput sampler means the button's first
capture reports throughput `UNAVAILABLE`, exactly as the reference's separate sampler did on
first use.

## 4. What still blocks the end-to-end path

1. **Firebase registration of `io.github.kouotou.qoesense`** (Android). Until then
   `lib/firebase_options.dart` is null and the app runs fail-closed: it collects and buffers,
   uploads nothing and deletes nothing. The step-by-step instructions are in the Phase 3 report.
2. **Billing and the functions deploy**, for BigQuery ingestion (and v2 columns).
3. **A physical phone** for §5.

## 5. Device validation protocol (same phone, both apps side by side)

Prerequisites:
- the reference app 1.1 (signed release) installed;
- this app installed with `flutter run` or by installing the debug APK;
- both apps given the same permissions.

They have different application IDs, so they coexist.

| # | Check | How | Pass |
|---|---|---|---|
| 1 | Onboarding and consent | A fresh install: go through all five steps | Nothing starts before "I agree". Collection starts after "Finish". The silent notification appears. |
| 2 | Capability report | Status screen | It matches the granted permissions. Physical channel shows **Restricted**. |
| 3 | Telemetry availability | "Run telemetry test" in both apps, within a few seconds of each other | Same RSRP/RSRQ/RSSNR/TA (±2 dB), same `cellIdentityHash` and `networkType` |
| 4 | Cadence | 2 h of collection, including a 20 min Zoom or WhatsApp call; then compare `timestampMs` gaps (adb export, §6) | Median ≈60 s at rest and ≈15 s in a call, in both apps |
| 5 | Background continuity | Swipe the app away; leave the screen off for 1 h; reboot | Samples continue; collection restarts after reboot |
| 6 | Permission behaviour | Revoke location mid-run | The service keeps running; `locationStatus` / `radioStatus` = PERMISSION_DENIED; no crash |
| 7 | MOS triggers | Wait 2 h (PERIODIC); end a WhatsApp session (POST_SESSION after a 15 min cooldown); walk into poor coverage (ANOMALY) | Same triggers in both apps, and at most 6 per local day |
| 8 | Local buffering | Airplane mode for 1 h, then Wi-Fi | The buffered count grows, then falls only after the upload is confirmed |
| 9 | MOS offline | Tap a rating in airplane mode, then reconnect | The rating arrives once, with a UUID document ID |
| 10 | Upload + BigQuery | After Firebase registration and the deploy | Rows with `appVersion = '2.0.0'` appear in `samples`; the reference's rows are unaffected |
| 11 | Battery | 24 h each app alone, same phone, similar use | The new app's drain is no more than 1.5× the reference's. If it's worse, consider the native-loop fallback (ARCHITECTURE §4). |

## 6. Commands

```powershell
cd C:\Users\Ahmad\AndroidStudioProjects\QoESense-CrossPlatform
powershell -ExecutionPolicy Bypass -File tool\verify.ps1          # format, codegen, analyze, 114 tests, APK
$env:JAVA_HOME="C:\Program Files\Android\Android Studio\jbr"
C:\Users\Ahmad\flutter\bin\flutter run                               # install + run on the USB-connected phone
# Live log of the collector and upload engines:
C:\Users\Ahmad\AppData\Local\Android\sdk\platform-tools\adb.exe logcat -s QoESense flutter QoESenseCollector QoESenseUploadWorker
# Copy the on-device buffer out for the cadence check (debug builds only). drift keeps it in
# the app documents directory (app_flutter/). Copy the WAL file too, or recent rows are missing.
# Use cmd's redirection: PowerShell 5.1's ">" re-encodes binary output and corrupts the file.
cmd /c "C:\Users\Ahmad\AppData\Local\Android\sdk\platform-tools\adb.exe exec-out run-as io.github.kouotou.qoesense cat app_flutter/qoesense.sqlite > qoesense.sqlite"
cmd /c "C:\Users\Ahmad\AppData\Local\Android\sdk\platform-tools\adb.exe exec-out run-as io.github.kouotou.qoesense cat app_flutter/qoesense.sqlite-wal > qoesense.sqlite-wal"
```

## 7. Device validation results (Infinix X669, Android 12, 2026-11-07 → 11-09)

| Check | Result |
|---|---|
| Fresh radio readings | ✅ after fix M: 1,087/1,089 `OK`, median age 10 ms; RSRP −112…−70 across 13 cells. Identical back-to-back rows fell from 100% to 10%. |
| Cadence while awake | ✅ exactly 60 samples/h (e.g. 11-07 20:00 → 11-08 04:00) |
| Restart after reboot | ✅ once Auto-start was enabled. The Infinix "AutoStart Limit" blocks it otherwise; the participant instructions must say so. |
| Restart after an app update | ✅ with Auto-start enabled, plus the open-app safety net |
| Gaps while asleep (Doze) | ❌ → fixed by **decision C**: a `WakeAlarm` about every 10 min. Before the fix: ~1 sample/45 min, and one 5 h gap. |
| Location/connectivity null for 36 h | ✅ explained: the owner had Wi-Fi and mobile data off. The statuses correctly said UNAVAILABLE / TIMEOUT. |
| Survey daily cap | ✅ 6 prompts on 11-08, then none |
| No stuck data | ✅ both the native and SQLite MOS queues were empty |
| 15 s in-call cadence | ❌ for a **WhatsApp Business** call: `com.whatsapp.w4b` wasn't in the reference package list → fixed (difference O). See the re-test below. |
| Battery | ⏳ not measured yet (statistics were reset by a charge) |
| Uploads / BigQuery | ⏳ blocked by Firebase billing. The worker ran and correctly asked to retry. |

| # | Behaviour | Reference | New app | Why |
|---|---|---|---|---|
| O | WhatsApp Business | Not monitored | `com.whatsapp.w4b` is treated exactly like `com.whatsapp` (social media, plus the call heuristic) | Found on the test phone. Very common in Cameroon. |
| C | Gaps while asleep | Same coroutine timer, so presumably the same Doze gaps | `WakeAlarm` (`setAndAllowWhileIdle`, ~10 min) + a 30 s wake lock. The Dart loop takes the overdue sample. | Owner decision C, 2026-11-09 |

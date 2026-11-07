# QoESense cross-platform architecture

**Status:** Phase 1 (architecture and workspace). Nothing in this project collects real data yet.

**Reference implementation:** `../QoESense`, the native Android app. It stays unchanged and
keeps running for participants throughout the migration.

## 1. Goals and non-goals

**Goals**
- One Flutter/Dart codebase for UI, research rules and the upload pipeline, on Android and iOS.
- Native Kotlin and Swift only where the OS demands it: radio telemetry, foreground-app and
  call detection, background lifetime, and survey presentation outside the app.
- Bit-for-bit compatibility with the existing backend (see [DATA_CONTRACT.md](DATA_CONTRACT.md)).
- Explicit capability reporting. Every sample says what its platform could actually measure.

**Non-goals**
- No new backend, database, cloud provider or warehouse. No FastAPI or PostgreSQL. Firebase
  and GCP stay as they are.
- No BigQuery schema or cloud-resource changes in this phase.
- No claim of iOS parity for fields that iOS doesn't expose (see [MIGRATION_MATRIX.md](MIGRATION_MATRIX.md)).
- This project doesn't replace the reference Android app for existing participants. See D-1.

## 2. Layers

```
┌──────────────────────────────────────────────────────────────────────────┐
│ presentation/   Flutter widgets: onboarding+consent, status, in-app MOS  │  shared Dart
├──────────────────────────────────────────────────────────────────────────┤
│ application/    SamplingPolicy, SurveyTriggerPolicy, RsrpAnomalyDetector,│  shared Dart
│                 CapabilityTierResolver, collector tick, upload drain     │  (pure, unit-tested)
├──────────────────────────────────────────────────────────────────────────┤
│ domain/         TelemetrySample, MosResponse, enums, CapabilityReport    │  shared Dart
├───────────────────────────────┬──────────────────────────────────────────┤
│ data/local/   TelemetryBuffer │ data/backend/  DeviceIdentity,           │  shared Dart
│ (port + SQLite impl, Phase 2) │ BatchDestination, MosSink, ConsentSink   │  (FlutterFire, Phase 2)
├───────────────────────────────┴──────────────────────────────────────────┤
│ platform/       Pigeon-generated typed channel: TelemetryHostApi         │  generated
╞═══════════════════════════════╤══════════════════════════════════════════╡
│ android/ (Kotlin)             │ ios/ (Swift)                             │  native
│  cellular, usage-stats,       │  RAT, NWPathMonitor, CallKit observer,   │
│  fused location, throughput   │  Core Location, getifaddrs throughput    │
│  foreground service, boot,    │  background location host, BGTask,      │
│  WorkManager, overlay survey  │  actionable notification survey         │
└───────────────────────────────┴──────────────────────────────────────────┘
```

**Dependency rule:** arrows point down only.
- `domain/` imports nothing from Flutter. It's pure Dart and runs in `dart test`.
- `application/` depends on `domain/` and on *ports* (abstract classes) for storage, backend and
  platform, never on concrete plugins.

That is what makes the research rules testable on Windows without a device.

## 3. How Flutter talks to Kotlin and Swift

**Mechanism:** [Pigeon](https://pub.dev/packages/pigeon).
- `pigeons/telemetry_api.dart` declares the API once.
- `dart run pigeon --input pigeons/telemetry_api.dart` generates type-safe code:
  `lib/src/platform/telemetry_api.g.dart`, `android/.../TelemetryApi.g.kt` and
  `ios/Runner/TelemetryApi.g.swift`.
- Underneath, it's a standard `BasicMessageChannel` with the binary codec. Pigeon removes
  string-keyed `MethodChannel` maps, so a renamed field is a compile error on all three sides
  instead of a silent null in the data.

| Direction | API | Phase 1 contents |
|---|---|---|
| Dart → native | `TelemetryHostApi` (`@HostApi`) | `getCapabilityReport()`, implemented on both platforms |
| Dart → native | (Phase 2) `captureRadio()`, `captureLocation(timeoutMs)`, `captureThroughput()`, `currentSession()` | not yet |
| native → Dart | (Phase 2) `CollectorFlutterApi` (`@FlutterApi`): `onTick()`, `onSurveyAnswered(...)` | not yet |

**Capability reporting is explicit.** `CapabilityReport` lists the following, per field group:
- `available`: the OS and hardware can provide it, and permission is granted;
- `permissionMissing`;
- `unsupportedOnPlatform`: no API exists, as for RSRP on iOS;
- `restricted`: an API exists but the app can't get it, e.g. carrier-privileged PhysicalChannelConfig.

It drives the status screen, and later the `telemetryCapabilityTier` written into every sample.
Nothing is silently faked. A field that is `unsupportedOnPlatform` is always `null` on the wire.

## 4. Android: the background service stays native

The reference app's lifetime machinery is proven on devices, and Flutter doesn't replace it.

| Concern | Implementation (Kotlin, in `android/`) |
|---|---|
| Staying alive | Foreground service, type `dataSync\|location`, with a low-priority silent notification. Same as the reference. |
| Clock | The service owns the fixed-rate loop (a coroutine on a dedicated thread). The interval comes from the shared Dart `SamplingPolicy`, returned to the service on each tick (`nextDelayMs`), so the rule exists exactly once. |
| Running Dart in the background | The service starts a **headless `FlutterEngine`** with a dedicated Dart entrypoint (`@pragma('vm:entry-point') collectorMain`). That engine has no UI. It runs the collector tick (capture via the host API, then buffer, then trigger evaluation). This is the pattern that `workmanager` and `flutter_background_service` use. |
| Reboot | `BootReceiver` restarts the service if collection was enabled. Same as the reference. |
| Upload | A native `WorkManager` periodic job (1 h, unmetered network, battery not low) starts a headless engine at `uploadMain`, which runs the shared drain-then-retain logic. |
| Survey | `SYSTEM_ALERT_WINDOW` overlay activity, or a notification fallback, both native. The rating comes back to Dart over the channel and is written by the shared code. |
| Cellular, usage and location | Ported from the reference's `telemetry/` classes, nearly verbatim, behind `TelemetryHostApi`. |

**Fallback if the headless engine misbehaves on a device:** the Kotlin capture classes can
write directly to the same SQLite file using the contract in §6. Because the buffer schema is
defined independently of the language, either side can be the writer.

## 5. iOS: collection within Apple's constraints

iOS gives an app **no general background execution**. Collection only happens while iOS keeps
the app alive or wakes it.

| Mechanism | What it gives us | Constraint |
|---|---|---|
| Continuous Core Location updates with `allowsBackgroundLocationUpdates`, "Always" authorization, coarse accuracy, `pausesLocationUpdatesAutomatically = false` | The process keeps running in the background, so the 60 s / 15 s Dart timer actually fires | Needs "Always" location (the user must accept twice) and an honest location purpose string for App Store review. Costs battery; coarse accuracy keeps it modest. If the user kills the app or revokes "Always", collection stops. |
| Significant-location-change monitoring | iOS **relaunches** the app after a ~500 m move, even after it was terminated | Coarse and opportunistic: a gap-filler, not a cadence |
| `BGAppRefreshTask` / `BGProcessingTask` | Upload windows; requires-network processing tasks | iOS decides when they run, from minutes to many hours. Wi-Fi-only is enforced by our own `NWPathMonitor` check. |
| `CXCallObserver` (CallKit) | Whether *a* call is active: cellular, WhatsApp, Zoom, or any CallKit VoIP app | It can't tell *which* app, or whether it's video. See D-4. |
| `UNNotificationCategory` with 5 actions | 1–5 MOS rating from the lock screen or banner, without opening the app | Replaces the Android overlay, since iOS has no overlays. The "what were you doing?" question is answered in-app (D-6). |

**Consequences that the data and analysis must respect:**
- The iOS cadence is "60 s while alive", not guaranteed. Gaps are real and timestamped, never
  back-filled.
- iOS rows carry RAT, connectivity, RTT, throughput and location only. The tier is `IOS_RAT`
  (D-3).
- iOS anomaly triggers use RTT, throughput and path-change signals, because RSRP isn't
  available. They write the same `ANOMALY` trigger type.

## 6. Local persistence (offline guarantees)

- **Port:** `TelemetryBuffer` (`lib/src/data/local/telemetry_buffer.dart`), with `append`,
  `oldest(limit)`, `deleteByIds`, `deleteOlderThan`, `count` and `watchCount`. Phase 1 ships the
  port, an in-memory implementation, and the upload-drain logic tested against it.
- **Phase 2 implementation:** SQLite via `drift`, chosen over `sqflite` because it:
  - generates and tests schema migrations (the reference's Room DB is version 1 with no
    migrations, a known risk);
  - supports several isolates over one database file (the UI engine and the headless
    collector engine);
  - runs on the host VM for tests.
- **Invariants carried over from the reference:**
  1. A sample is persisted before anything else is done with it.
  2. Rows are deleted only after `BatchDestination.upload` confirms durable storage.
  3. Each run drains (up to 20 batches × 2,000 rows) and *then* applies retention, so a
     backlog that became uploadable is never purged first.
  4. Retention is 45 days.
- **MOS ratings** are queued, not fire-and-forget. A pending rating is stored locally with its
  tap-time UUID and retried. Android uses WorkManager, as in the reference. iOS uses a
  `BGProcessingTask` and retries again on the next app launch.

## 7. Backend integration (unchanged backend)

| Backend piece | Client side | Notes |
|---|---|---|
| Firebase Auth, anonymous | `DeviceIdentity` port → `firebase_auth` | UID = device ID |
| Cloud Storage `telemetry/{uid}/{date}/{batch}.json.gz` | `BatchDestination` → `firebase_storage` `putData` | bytes from the shared `BatchSerializer` |
| Firestore `devices/{uid}/mosResponses/{id}` | `MosSink` → `cloud_firestore` `set` | idempotent on the tap-time UUID |
| Firestore `devices/{uid}.consentGivenAtMs` | `ConsentSink` | merge, best effort |
| Cloud Functions, BigQuery | nothing on the client | `loadTelemetryBatch` and `exportMosResponse` are untouched |
| Security rules | nothing on the client | they already scope everything to `request.auth.uid`, so they work for any platform |

**Firebase app registration (later, not Phase 1):** this project needs its own Android app and
iOS app registered in the `qoesense` Firebase project, configured with `flutterfire configure`.
The reference app's `google-services.json` belongs to the `com.example.qoesense` package and is
deliberately **not** copied here. Before registering anything, the user gets step-by-step
console instructions.

**Billing (2026-11-07):** Firebase billing isn't completed, so the `platform` column isn't
deployed. Phase 1 needs no backend. Phase 2 can work against unconfigured or fake ports. Real
uploads from this project must wait for billing and the functions deployment.

## 8. Platform strategies

| Strategy | Android | iOS |
|---|---|---|
| Permissions | phone state, fine/background location, notifications, usage access, battery-optimization exemption, overlay | location When-In-Use → Always, notifications; no usage, overlay or phone-state equivalents |
| Background execution | foreground service, boot receiver, WorkManager | background location, significant-change relaunch, BGTaskScheduler |
| Survey presentation | overlay activity, or notification fallback | actionable notification, plus an in-app sheet when opened |

Each row is a Dart interface (`PermissionStrategy`, `BackgroundStrategy`,
`SurveyPresenter`) with one implementation per platform, selected at startup. The shared UI
asks *what* is needed; the strategy knows *how*.

## 9. Decisions

Answered by the project owner on 2026-11-07, except where marked otherwise.

| ID | Decision | Status |
|---|---|---|
| D-1 | **This app will replace the reference Android app on participants' phones.** The handover plan is in §9.1. | **Decided** |
| D-2 | Application ID and iOS bundle ID **`io.github.kouotou.qoesense`**, the namespace of the owner's GitHub account. It is the same on both platforms and must never change after release. | **Decided** |
| D-3 | iOS rows use the new `telemetryCapabilityTier` value **`IOS_RAT`**. It's a STRING value, not a schema change. | **Decided** |
| D-4 | On iOS, any CallKit-detected call counts as `VIDEO_CONFERENCING`, so the 15 s cadence applies to every call. On iOS rows this value means "some call was active". | **Decided** |
| D-5 | On iOS rows, `androidVersion` holds the iOS **major** version. Rows are told apart by tier and platform. | **Decided** |
| D-6 | The iOS self-report sets `contextSessionType` from the answer, and `contextAppPackage` to the **Android package name** of the chosen app (e.g. `com.whatsapp`). Self-reported vs. observed is told apart by `platform`. | **Decided** |
| D-7 | New **private** GitHub repo `Kouotou/QoESense-CrossPlatform`, whose CI includes the macOS Swift build. | **Decided.** The owner creates the repo. |

### 9.1 Replacing the reference Android app (D-1)

The new app uses a new application ID (D-2). `com.example.qoesense` can't go on the Play
Store, and an Android ID can't be changed in place. So Android sees the new app as a
**separate app**, not an update. The handover is:

1. Participants install the new app next to the old one.
2. The old app keeps running until its buffer has uploaded. Its status screen shows the
   buffered count, which must reach 0.
3. Then the participant uninstalls the old app.

The old app's buffer is drained by the old app itself, so no data migration (Room → drift)
is needed.

**Research consequence:** the new install has a new anonymous UID, so each Android
participant appears under two device IDs, an old one and a new one. If analyses need one
continuous participant timeline, Phase 4 can add an optional, consented "link my previous
device ID" step: the old app shows its UID, and the new app records it in
`devices/{uid}.previousDeviceId`. That is a new Firestore field, not a BigQuery change, and
it must be added to the consent text.

**The alternative, if there will be no Play Store release:** keep `com.example.qoesense` and
the reference signing key, so the new app installs as an update over the old one. That
avoids the second UID, but it needs a Room → drift migration of the unsent buffer. It also
locks out the Play Store, and the iOS bundle ID would still differ.

## 10. Phases

| Phase | Scope | Exit criteria |
|---|---|---|
| **1 (this)** | Workspace, docs, contracts, pure shared rules, ports, one channel (`getCapabilityReport`) on both platforms, CI | `flutter analyze` clean, `flutter test` green, `flutter build apk --debug` succeeds; Swift compiles in CI or on the Mac |
| 2 | drift buffer, FlutterFire against the real project, onboarding + consent (EN/FR), status screen | consent and identity work on an Android phone, nothing uploads yet |
| 3 | Android native adapters + foreground service + headless collector; iOS adapters + background location host (**Mac needed**) | samples land in the local buffer on both phones at the agreed cadence |
| 4 | Upload + MOS end to end, after functions are deployed and billing is fixed | rows in BigQuery from both platforms; reference-app rows unaffected |
| 5 | Pilot on a few devices; D-1 decision; store preparation | the device verification checklist passes |

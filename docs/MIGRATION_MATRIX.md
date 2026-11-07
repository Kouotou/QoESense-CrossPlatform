# Migration matrix

Each row is a requirement of the reference Android app (`../QoESense`). The columns say where
it lives in this project, and whether iOS can meet it **equivalently**, **with a substitute**,
or **not at all**.

**Legend:**
- **Shared**: Dart, in `lib/`. **Kt**: native Kotlin. **Sw**: native Swift.
- ✅ equivalent. 🟡 approved substitute. ❌ impossible on iOS; the field is null.
- **P1** means done in Phase 1; anything else is the phase that will do it.

## Telemetry capture

| Requirement (reference) | Android here | iOS here | iOS parity | Phase |
|---|---|---|---|---|
| RSRP / RSRQ / RSSNR / TA | Kt (port of `CellularTelemetrySource`) | none | ❌ no public API | 3 |
| CQI (API 29+) | Kt | none | ❌ | 3 |
| PhysicalChannelConfig | Kt (reported as `restricted`, as in the reference) | none | ❌ | 3 |
| Cell ID / TAC hash | Kt | none | ❌ | 3 |
| Signal bars (0–4) | Kt | none | ❌ | 3 |
| Network type (LTE/NR/…) | Kt | Sw `CTTelephonyNetworkInfo` | ✅ (NSA nuance, see DATA_CONTRACT §5) | 3 |
| Connection type (WIFI/CELLULAR/OTHER) | Kt `ConnectivityManager` | Sw `NWPathMonitor` | ✅ | 3 |
| Roaming flag | Kt | none | ❌ (CTCarrier deprecated) | 3 |
| Throughput (device-wide bytes/s) | Kt `TrafficStats` | Sw `getifaddrs` | ✅ | 3 |
| RTT (generate_204 GET, 4 s) | **Shared** Dart `HttpClient` | **Shared** | ✅ same code | 3 |
| Foreground app package | Kt `UsageStatsManager` | none | ❌ (self-report substitute, D-6) | 3 |
| Video-call detection | Kt (usage stats + WhatsApp call heuristic) | Sw `CXCallObserver` | 🟡 "a call is active" (D-4) | 3 |
| Location (lat/lon/accuracy, bounded wait) | Kt fused location | Sw Core Location | ✅ | 3 |
| Capability tier per sample | **Shared** resolver, from the native report | **Shared** → `IOS_RAT` | 🟡 new value (D-3) | **P1** (resolver) |
| Explicit capability report | Kt `getCapabilityReport` | Sw `getCapabilityReport` | ✅ | **P1** |

## Collection lifetime and scheduling

| Requirement | Android | iOS | Parity | Phase |
|---|---|---|---|---|
| 60 s at rest / 15 s in a call, fixed-rate | **Shared** `SamplingPolicy`; Kt service owns the clock | **Shared** policy; Dart timer while background location keeps the app alive | 🟡 the cadence holds only while iOS keeps the app alive | **P1** (policy) / 3 |
| Location wait 15 s / 8 s | **Shared** policy | **Shared** | ✅ | **P1** |
| RTT every 5th tick / every tick in a call | **Shared** policy | **Shared** | ✅ | **P1** |
| Survives the app being swiped away | Kt foreground service | Sw significant-change relaunch | 🟡 gaps possible | 3 |
| Restart after reboot | Kt `BootReceiver` | Sw significant-change relaunch after the first unlock | 🟡 | 3 |
| Never shapes traffic (observe only) | by design | by design | ✅ | n/a |

## Buffering and upload

| Requirement | Android | iOS | Parity | Phase |
|---|---|---|---|---|
| Local buffer, row = pending upload | **Shared** `TelemetryBuffer` port (in-memory in P1, drift in P2) | **Shared** | ✅ | **P1** (port) / 2 |
| Delete only after a confirmed upload | **Shared** `UploadDrain` | **Shared** | ✅ | **P1** |
| Drain 20 × 2,000, then retention (45 d) | **Shared** `UploadDrain` | **Shared** | ✅ | **P1** |
| Gzipped NDJSON, exact field set and order | **Shared** `BatchSerializer` | **Shared** | ✅ | **P1** |
| Wi-Fi only, battery not low, hourly | Kt WorkManager constraints | Sw BGTask + Dart `NWPathMonitor`-backed check | 🟡 iOS decides when tasks run | 4 |
| Storage path `telemetry/{uid}/{local date}/{uuid}.json.gz` | **Shared** | **Shared** | ✅ | **P1** (path builder) |

## Identity, consent, MOS

| Requirement | Android | iOS | Parity | Phase |
|---|---|---|---|---|
| Anonymous Firebase UID as the device ID | **Shared** `firebase_auth` | **Shared** | ✅ | 2 |
| Consent before any collection; EN + FR text | **Shared** UI, l10n | **Shared** | ✅ | 2 (strings scaffolded in P1) |
| `consentGivenAtMs` server record | **Shared** `ConsentSink` | **Shared** | ✅ | 2 |
| MOS 1–5 scale | **Shared** model validation | **Shared** | ✅ | **P1** (model) |
| Triggers: PERIODIC 2 h / POST_SESSION 15 min / ANOMALY 10 min, shared cooldown | **Shared** `SurveyTriggerPolicy` | **Shared** | ✅ | **P1** |
| 6 per local day; baseline on first run | **Shared** | **Shared** | ✅ | **P1** |
| RSRP anomaly detector | **Shared** `RsrpAnomalyDetector` | not used (no RSRP) | ❌ → 🟡 RTT/throughput/path detector | **P1** (RSRP) / 3 (iOS detector) |
| Survey shown over other apps | Kt overlay activity | none | ❌ → 🟡 actionable 1–5 notification | 3 |
| Notification fallback | Kt | Sw `UNNotificationCategory` | ✅ | 3 |
| Auto-dismiss after 8 s | Kt overlay | n/a (notifications persist) | 🟡 | 3 |
| Context window = 10 min before the tap | **Shared** `MosResponse.forTap` | **Shared** | ✅ | **P1** |
| Idempotent submit (tap-time UUID), retried | **Shared** + Kt WorkManager | **Shared** + Sw BGTask / next launch | ✅ | 4 |
| "What were you doing?" self-report | not needed (observed) | **Shared** UI | 🟡 (D-6) | 3 |

## Deliberately not migrated

| Reference item | Why |
|---|---|
| `RootedTelemetrySource` (DIAG tier seam) | It's disabled in the reference, and no participant device is rooted. It can be re-added as a Kt adapter if ever needed. |
| Room database file | This is a new app with its own install. Data migration is only relevant if D-1 chooses replacement. |
| `google-services.json`, keystore, `keystore.properties` | They're bound to the reference package or secret. This project gets its own Firebase app registration (D-2) and signing. |

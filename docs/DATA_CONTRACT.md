# QoESense data contract

This is the wire contract between the apps (the Android reference app, and this project's Android
and iOS builds) and the existing backend. It is **frozen by the backend**:
`functions/index.js` in the reference repo (`../QoESense`) defines the BigQuery schemas,
and the load job runs with `ignoreUnknownValues: false`. Any key the function's deployed
schema doesn't know **fails the whole batch**.

Machine-readable copies of both schemas live in [`../contracts/`](../contracts/).
`test/contract/` checks the Dart serializers against them on every `flutter test`.

## 1. Identity

| Item | Rule |
|---|---|
| Device identifier | Firebase **anonymous Auth UID**, one per install. No IMEI, phone number, account, advertising ID or name, ever. |
| Reinstall | A new UID. This matches the reference app; it is a research limitation, not a bug. |
| Where it appears | The Storage path, every NDJSON line (`deviceId`), and the Firestore path. |

## 2. Telemetry batches: Cloud Storage → `qoesense_telemetry.samples`

**Path:** `telemetry/{uid}/{yyyy-MM-dd}/{batchId}.json.gz`
- `yyyy-MM-dd` is the device's **local** date at upload time, as in the reference app.
- `batchId` is a random UUID v4.

**Body:** gzip of UTF-8 NDJSON. That is one JSON object per sample, joined by `\n`, with no
trailing newline. Each object holds every field below, in this order. `null` is written
explicitly, never omitted. Kotlin's `Json { encodeDefaults = true }` does the same.

| # | Key | JSON type | Required | Android source | iOS value |
|---|---|---|---|---|---|
| 1 | `timestampMs` | int | yes | capture wall clock (epoch ms) | same |
| 2 | `rsrp` | int\|null | | CellSignalStrengthLte | **null** (no public API) |
| 3 | `rsrq` | int\|null | | 〃 | **null** |
| 4 | `rssnr` | int\|null | | 〃 | **null** |
| 5 | `timingAdvance` | int\|null | | 〃 | **null** |
| 6 | `networkType` | string\|null | | `"LTE"`, `"NR"`, `"UNKNOWN"`, `"OTHER"` | from `CTTelephonyNetworkInfo.serviceCurrentRadioAccessTechnology`, using the same four values (see §5) |
| 7 | `cellIdentityHash` | string\|null | | first 16 hex characters of SHA-256 of `"{ci}:{tac}"` | **null** |
| 8 | `trackingAreaCode` | int\|null | | CellIdentityLte.tac | **null** |
| 9 | `signalStrengthLevel` | int\|null | | 0–4 bars | **null** |
| 10 | `cqi` | int\|null | | API 29+ when reported | **null** |
| 11 | `cqiSupported` | bool | **yes** | | `false` |
| 12 | `cellBandwidthKhz` | int\|null | | PhysicalChannelConfig | **null** |
| 13 | `downlinkChannelNumber` | int\|null | | 〃 | **null** |
| 14 | `uplinkChannelNumber` | int\|null | | 〃 | **null** |
| 15 | `connectionType` | string\|null | | `"WIFI"`, `"CELLULAR"`, `"OTHER"` | `NWPathMonitor`, same values |
| 16 | `isRoaming` | bool\|null | | TelephonyManager | **null** (CTCarrier is deprecated and returns placeholders) |
| 17 | `throughputBytesPerSecond` | int\|null | | TrafficStats, device-wide | `getifaddrs` byte counters, device-wide |
| 18 | `rttMs` | int\|null | | HTTPS GET `https://www.gstatic.com/generate_204`, 4 s timeout | same probe (shared Dart code) |
| 19 | `foregroundAppPackage` | string\|null | | UsageStatsManager | **null** (no API) |
| 20 | `appSessionType` | string | **yes** | `NONE`, `SOCIAL_MEDIA`, `VIDEO_CONFERENCING` | `NONE`, or a call value from CallKit; see D-4 |
| 21 | `latitude` | float\|null | | fused location | Core Location |
| 22 | `longitude` | float\|null | | 〃 | 〃 |
| 23 | `locationAccuracyMeters` | float\|null | | 〃 | 〃 |
| 24 | `deviceModel` | string | **yes** | `Build.MODEL` | hardware identifier, e.g. `"iPhone14,5"` |
| 25 | `androidVersion` | int | **yes** | `SDK_INT` | iOS **major** version, e.g. `18`; see D-5 |
| 26 | `appVersion` | string | **yes** | versionName | `CFBundleShortVersionString` |
| 27 | `telemetryCapabilityTier` | string | **yes** | `BASE_26`, `CQI_29`, `PHYSCHAN_30` | `IOS_RAT` (proposed); see D-3 |
| 28 | `deviceId` | string | **yes** | added at serialization | same |
| 29 | `platform` | string\|null | | **only after functions are deployed** | 〃 |

### Float precision (Phase 3 rule for native adapters)

Android's `Location.getAccuracy()` is a 32-bit `Float`. The reference serializes it with
Kotlin's shortest representation, so `7.3f` is written as `7.3`. Widening it with
`toDouble()` before sending it over the channel would write `7.300000190734863` instead.
The Kotlin adapter must therefore convert with `accuracy.toString().toDouble()`, which
preserves the reference's values. Swift's `CLLocation.horizontalAccuracy` is already a
`Double`.

### The `platform` field is gated

`platform` (`"ANDROID"` / `"IOS"`) is in the reference repo's `functions/index.js` on `main`
but **is not deployed yet**: as of 2026-11-07, Firebase billing is not completed.

Until the deployment is confirmed, the serializer must not emit the key. Today the old function
would reject the whole batch because of it. `BatchSerializer.emitPlatformField` defaults to
`false`, and a contract test fails if that default changes without the docs being updated.

When the field is absent, the row stores `platform = NULL`. Analyses then tell platforms apart
by `telemetryCapabilityTier = 'IOS_RAT'` (see D-3) or by `deviceModel LIKE 'iPhone%'`.

## 3. MOS ratings: Firestore → `qoesense_telemetry.mos_responses`

**Document:** `devices/{uid}/mosResponses/{responseId}`
- `responseId` is a UUID v4 generated **at the moment of the tap**.
- Every retry reuses it, so a retry never creates a duplicate. `exportMosResponse` is an
  `onDocumentCreated` trigger, so it fires once per rating.

| Key | Type | Rule |
|---|---|---|
| `score` | int | **1–5**. This is the unchanged MOS scale: 1 = bad, 5 = excellent. |
| `submittedAtMs` | int | Tap time. |
| `triggerType` | string | `PERIODIC`, `POST_SESSION` or `ANOMALY`. iOS anomalies (RTT, throughput or path change) also use `ANOMALY`. |
| `contextAppPackage` | string\|null | Android: the observed foreground package. iOS: see D-6. |
| `contextSessionType` | string | Same values as `appSessionType`. |
| `windowStartMs` / `windowEndMs` | int | `[tap − 10 min, tap]`. |
| `platform` | string | Written to Firestore always. The old function ignores keys it doesn't map, so this is safe before deployment. |

**Consent:** `devices/{uid}` is merged with `{consentGivenAtMs}`. This is best effort. The
local consent flag is authoritative and gates collection.

## 4. Research semantics that must not drift

These rules are ported to Dart in `lib/src/application/` and pinned by unit tests that
mirror the Android test suites.

| Rule | Value |
|---|---|
| Sampling interval | **60 s** at rest, **15 s** during a video-conferencing session. This supersedes the handbook's 20 s / 5 s. |
| Scheduling | Fixed-rate. Capture time is subtracted from the wait, and an overrun starts the next tick at once. |
| Location wait | Up to 15 s at rest, 8 s in a call. If it times out, the location fields are null. |
| RTT | Every 5th tick at rest (about every 5 min); every tick during a call. |
| Survey cooldowns | PERIODIC every 2 h; POST_SESSION after 15 min; ANOMALY after 10 min. All three share one last-prompt clock. |
| Daily cap | 6 prompts per **local** calendar day. |
| First prompt | The baseline (`lastPromptMs`) is set on first run, so no prompt fires right after install. |
| Anomaly (RSRP) | Recent 3 vs. baseline 10 readings, a swing of ±10 dB or more; or the std dev of 15 readings is ≤ 2 dB. Android only. |
| Upload | Wi-Fi only, battery not low. A row is deleted from the local buffer only **after a confirmed upload**. Drain first, then apply retention. |
| Retention | 45 days, as in the reference. |
| Missing data | A field the device can't provide is null. A partial sample is still written, never dropped. |

## 5. iOS radio-access-technology mapping

| `CTRadioAccessTechnology…` | `networkType` |
|---|---|
| `LTE` | `"LTE"` |
| `NRNSA`, `NR` | `"NR"` |
| nil (no service, or no SIM) | `"UNKNOWN"` |
| everything else (WCDMA, HSPA, GPRS, Edge, eHRPD, …) | `"OTHER"` |

Android's `NETWORK_TYPE_NR` covers standalone 5G only. NSA 5G reports `LTE` on Android, so iOS
`NRNSA` → `"NR"` is a small asymmetry. Analyses that need exact parity should treat `NR` on
iOS as "NSA or SA" and check `telemetryCapabilityTier`.

## 6. Changing this contract

1. All changes are additive and nullable. Never rename, retype or remove a field.
2. Change `functions/index.js` in the reference repo first. **Deploy it, and confirm the
   column exists**, before any client build sends the new key.
3. Then update `contracts/*.json`, this document, and the Dart model, in that order. The
   contract tests enforce the order.

# QoESense data contract (v1 deployed, v2 proposed)

**Approved by the owner on 2026-11-07 (v2 and §8.1–8.2). Not deployed yet.**

**Status (2026-11-07):**
- **v1** is the contract the reference Android app sends today. It is frozen.
- **v2** is the proposed cross-platform contract. It is implemented in the Dart domain model
  and pinned by tests, but **no backend change has been applied or deployed**.
- v2 needs owner approval, then a functions deployment (blocked by billing as of this date),
  before any client sends it.

**Sources inspected for this document:**
- In `../QoESense`: `TelemetrySample.kt`, `MosResponse.kt`, `TelemetryCapabilityResolver.kt`,
  `BatchSerializer.kt`, `TelemetrySampleMapper.kt`, `TelemetrySampleEntity.kt`,
  `TelemetryDao.kt`, `QoESenseDatabase.kt`, the capture classes under `telemetry/`, and
  `functions/index.js`.
- Machine-readable schemas:
  - [`../contracts/bigquery_*_schema.json`](../contracts/): v1, exported from `functions/index.js` on `main`;
  - [`../contracts/proposed/`](../contracts/proposed/): v2.
- Golden records: [`../contracts/fixtures/`](../contracts/fixtures/).

## 1. Principles

1. **Raw observations only, on the device.** A sample carries what the OS reported, plus the
   minimum transformation needed for privacy or for a rate (§6). Features and predictions
   are computed in BigQuery, never on the device.
2. **Null is never a reason.** In v1 a `null` can mean unsupported, not permitted, not
   attempted, timed out or failed. v2 keeps every v1 field as it is, and states the reason in
   a status column per measurement group (§5).
3. **Never fabricate.** A field the platform can't measure is `null` with status
   `NOT_SUPPORTED`. On iOS this applies to every radio field, permanently.
4. **Additive evolution only.** New columns are `NULLABLE` (or `REPEATED`). No v1 column is
   ever renamed, retyped, removed or given a new meaning (§7).
5. **Deploy before send.** The deployed load job runs with `ignoreUnknownValues: false`, so
   one unknown key fails the whole batch. A client sends v2 keys only after the v2 functions
   are confirmed live.

## 2. Identity and the telemetry ↔ MOS join

| Topic | Contract |
|---|---|
| Participant / device ID | The Firebase **anonymous** Auth UID of *one installation* (`deviceId`). No IMEI, phone number, account, advertising ID or name, ever. |
| Separate installations | **Different UIDs.** Two apps on one phone get two UIDs: the reference app `com.example.qoesense` and the new app `io.github.kouotou.qoesense` during the D-1 handover. A reinstall gets a new UID on Android. On iOS, Firebase Auth keeps its session in the Keychain, which can survive a reinstall, so the UID *may* be reused there. **Neither behaviour is relied on.** |
| Linking two UIDs | Only by explicit, consented participant action (proposed, §8.3): the new app records the old app's UID, which the old app's status screen already shows. Without a link, analyses treat the two UIDs as two devices. |
| The join | `mos_responses.deviceId = samples.deviceId` **and** `samples.timestampMs BETWEEN windowStartMs AND windowEndMs`. The window is `[tap − 10 min, tap]`, and both sides use the same device's wall clock, so they stay consistent even if that clock is off. |
| Clock caveat | `timestampMs` and all `*Ms` instants are device wall-clock time. A device whose clock is wrong produces wrong absolute times but consistent joins. v2 adds `utcOffsetMinutes` for local-time analysis. Durations and ages (`*DurationMs`, `*AgeMs`) come from monotonic clocks, so changing the wall clock doesn't affect them. |

## 3. Telemetry sample: v1 fields (unchanged semantics)

**Units and conventions:**
- `*Ms` instants are Unix epoch milliseconds (UTC), JSON integers.
- Durations and ages are milliseconds.
- Enums are UPPER_SNAKE strings.
- Floats use the shortest round-trip decimal. `NaN` and `Infinity` are never written; such a
  value is written as `null` with status `FAILED`.

| # | Field | Type | Unit / values | Meaning (as the reference app captures it) | Android, new app | iOS | Raw / derived |
|---|---|---|---|---|---|---|---|
| 1 | `timestampMs` | INT, REQ | epoch ms | Wall clock when the capture **completed**, after the location/RTT waits | same | same | raw |
| 2 | `rsrp` | INT | dBm | Serving LTE cell (registered cell, or the first LTE cell) from `getAllCellInfo()`. The `UNAVAILABLE` sentinel becomes null. | same | **null**, NOT_SUPPORTED | raw |
| 3 | `rsrq` | INT | dB | 〃 | same | **null** | raw |
| 4 | `rssnr` | INT | dB | 〃 | same | **null** | raw |
| 5 | `timingAdvance` | INT | LTE TA units (0–1282) | 〃 | same | **null** | raw |
| 6 | `networkType` | STRING | `LTE`, `NR`, `UNKNOWN`, `OTHER` | Data RAT from `TelephonyManager`. ⚠ The reference sets it **only when an LTE cell is visible** (it lives inside the radio reading). | Read independently, with its own status | `CTTelephonyNetworkInfo` RAT: `LTE`; `NR`/`NRNSA` → `NR`; nil → `UNKNOWN`; others → `OTHER` | raw |
| 7 | `cellIdentityHash` | STRING | 16 hex | First 16 hex characters of SHA-256 of `"{ci}:{tac}"`, so the raw cell ID never leaves the device | same algorithm | **null** | privacy transform of raw |
| 8 | `trackingAreaCode` | INT | TAC | Serving cell TAC | same | **null** | raw |
| 9 | `signalStrengthLevel` | INT | 0–4 | OS signal bars for the cell | same | **null** | OS-derived (kept as raw) |
| 10 | `cqi` | INT | 0–15 | API 29+, only when the modem reports it | same | **null** | raw |
| 11 | `cqiSupported` | BOOL, REQ | | ⚠ **"CQI was reported in this sample"**, *not* "the device supports CQI" | same meaning; device support is in `capabilitySet` | `false` | derived flag |
| 12 | `cellBandwidthKhz` | INT | kHz | PhysicalChannelConfig, which needs carrier privileges | same (in practice `RESTRICTED`) | **null** | raw |
| 13 | `downlinkChannelNumber` | INT | EARFCN | 〃 | same | **null** | raw |
| 14 | `uplinkChannelNumber` | INT | EARFCN | 〃 | same | **null** | raw |
| 15 | `connectionType` | STRING | `WIFI`, `CELLULAR`, `OTHER` | Active network transport | same | `NWPathMonitor`, same values | raw |
| 16 | `isRoaming` | BOOL | | `NetworkCapabilities` NOT_ROAMING (API 28+) | same | **null** (CTCarrier is deprecated) | raw |
| 17 | `throughputBytesPerSecond` | INT | bytes/s | **Device-wide** rx+tx (Wi-Fi included), averaged since the previous capture. The first capture after a restart is null. | same; window in `throughputWindowMs` | `getifaddrs` counters, same definition | derived from raw counters |
| 18 | `rttMs` | INT | ms | ⚠ Wall time of one **HTTPS GET** of `generate_204` on a new connection (DNS + TCP + TLS + request), 4 s timeout. Not an ICMP RTT. | same probe, in shared Dart; method in `rttMethod` | same | raw timing |
| 19 | `foregroundAppPackage` | STRING | package | `UsageStatsManager`, 10 s window | same | **null**, NOT_SUPPORTED | raw |
| 20 | `appSessionType` | STRING, REQ | `NONE`, `SOCIAL_MEDIA`, `VIDEO_CONFERENCING` | A classification of the package, plus a WhatsApp-call heuristic | same | `NONE`, or `VIDEO_CONFERENCING` during any CallKit call (D-4) | derived label |
| 21 | `latitude` | FLOAT | WGS84 ° | Fused location, balanced power, bounded wait | same | Core Location | raw |
| 22 | `longitude` | FLOAT | WGS84 ° | 〃 | same | 〃 | raw |
| 23 | `locationAccuracyMeters` | FLOAT | m (68%) | 〃. An Android `Float`: serialize it as `accuracy.toString().toDouble()` so `7.3f` stays `7.3`. | same | `horizontalAccuracy` | raw |
| 24 | `deviceModel` | STRING, REQ | | `Build.MODEL` | same | hardware ID, e.g. `iPhone14,5` | raw |
| 25 | `androidVersion` | INT, REQ | | `SDK_INT` | same | iOS **major** version (D-5) | raw |
| 26 | `appVersion` | STRING, REQ | | versionName: reference `1.x`, new app `2.x` | same | `CFBundleShortVersionString` | metadata |
| 27 | `telemetryCapabilityTier` | STRING, REQ | `BASE_26`, `CQI_29`, `PHYSCHAN_30`, `IOS_RAT` | Derived from what the reading contained. ⚠ `BASE_26` is also written when there was no radio reading at all. | same resolver | `IOS_RAT` (D-3) | derived label |
| 28 | `deviceId` | STRING, REQ | UID | Added at serialization | same | same | identity |
| 29 | `platform` | STRING | `ANDROID`, `IOS` | Committed in `functions/index.js` but **not deployed**. In this contract it's sent as part of v2. | v2 | v2 | metadata |

⚠ marks reference behaviour that is easy to misread. It is preserved exactly; v2 adds the
columns that make it explicit instead of changing it.

## 4. Telemetry sample: v2 additions (proposed)

Each v2 key is appended after `deviceId`. A v2 line is a v1 line plus this block.

| Field | Type | Values / unit | Purpose |
|---|---|---|---|
| `schemaVersion` | INT | `2` | NULL = v1 (the reference app, and the new app before the v2 deploy) |
| `platform` | STRING | `ANDROID`, `IOS` | Source platform. For v1 rows, NULL is resolved by tier (§8.2). |
| `radioStatus` | STRING | §5 | Rows 2–5, 7–9 |
| `cqiStatus` | STRING | §5 | Row 10 |
| `physicalChannelStatus` | STRING | §5 | Rows 12–14 |
| `networkTypeStatus` | STRING | §5 | Row 6 |
| `connectivityStatus` | STRING | §5 | Rows 15–16 |
| `throughputStatus` | STRING | §5 | Row 17 |
| `rttStatus` | STRING | §5 | Row 18 |
| `foregroundAppStatus` | STRING | §5 | Row 19. Row 20 is always present. |
| `locationStatus` | STRING | §5 | Rows 21–23 |
| `capabilitySet` | STRING **REPEATED** | `RADIO`, `CQI`, `PHYSICAL_CHANNEL`, `NETWORK_TYPE`, `CONNECTIVITY`, `THROUGHPUT`, `RTT`, `FOREGROUND_APP`, `LOCATION` | Groups this device could provide at capture time (supported, permitted, not restricted), whether or not this tick measured them |
| `appId` | STRING | e.g. `io.github.kouotou.qoesense` | Separates the new app from the reference app during the handover |
| `appBuild` | INT | versionCode / CFBundleVersion | Exact build, beyond `appVersion` |
| `osVersion` | STRING | `"14"`, `"18.1"` | Full OS version (`androidVersion` stays the integer) |
| `utcOffsetMinutes` | INT | e.g. `60` | Local offset at capture |
| `captureDurationMs` | INT | ms, monotonic | Tick start until `timestampMs`. Bounds how long the readings in one row took to collect. |
| `cellInfoAgeMs` | INT | ms | Age of the radio reading from CellInfo's own timestamp. **Detects the modem-cached values** that are the suspected source of duplicate rows. |
| `locationAgeMs` | INT | ms | Age of the location fix (a fused or Core Location cached fix) |
| `throughputWindowMs` | INT | ms | The interval the throughput average covers |
| `rttMethod` | STRING | `DART_HTTPS_GET_GENERATE_204` | RTT implementation. Null rows from the reference app mean Android `HttpURLConnection`, the same URL and the same timeout. |

## 5. Field status: telling missing data apart

| Status | Value present? | Meaning | Android can establish it when… | iOS can establish it when… |
|---|---|---|---|---|
| `OK` | yes | Measured during this capture | the OS returned a valid value | same |
| `STALE` | **yes** (kept) | The reading is older than the current sampling interval (60 s at rest, 15 s in a call), so it can't be from this tick and is likely a repeat of a cached reading | CellInfo `getTimestampMillis()` (API 30+) or `getTimeStamp()`; `Location.elapsedRealtimeNanos` | `CLLocation.timestamp` (location only) |
| `NOT_SUPPORTED` | no | No API on this platform, OS version or hardware | API level < 29 for CQI; no telephony | **always** for radio, CQI, physical channel and foreground app |
| `PERMISSION_DENIED` | no | Supported but not granted | `checkSelfPermission`, usage-access app-op | location authorization status |
| `RESTRICTED` | no | An API exists, but the system, carrier or a policy refuses it | PhysicalChannelConfig without carrier privileges | location `.restricted` (MDM / parental controls) |
| `NOT_ATTEMPTED` | no | Deliberately skipped this tick | RTT on non-RTT ticks | same |
| `UNAVAILABLE` | no | Attempted; the OS had nothing usable | no LTE cell, an `UNAVAILABLE` sentinel, or no throughput baseline yet | no throughput baseline yet |
| `TIMEOUT` | no | Attempted; out of time | location wait, RTT 4 s | same |
| `FAILED` | no | Attempted; an error occurred | an exception or a failed probe | same |

**Consistency rules.** These are executable: `lib/src/domain/contract_rules.dart`, tested in
`test/contract/contract_rules_test.dart`.
- Every group has a status.
- Values are non-null **only** for `OK` or `STALE`.
- `OK` or `STALE` means at least one value is present. Within an `OK` group, an individual
  null means the modem didn't report that one field, e.g. TA while idle.
- `STALE` requires the matching age.
- `capabilitySet` never contains a group whose status is `NOT_SUPPORTED`,
  `PERMISSION_DENIED` or `RESTRICTED`.
- `cqiSupported` equals `cqi != null`.
- A throughput value needs `throughputWindowMs`; an RTT value needs `rttMethod`.
- iOS: radio, CQI, physical channel and foreground app are `NOT_SUPPORTED`; `isRoaming` is
  null; the tier is `IOS_RAT`.
- Android: the tier equals the reference resolver's result.

**Where a distinction can't be established, the contract doesn't pretend it can.** For
example, an Android `UNAVAILABLE` radio reading can't say *why* no LTE cell was visible (no
coverage, NR-only, or airplane mode). Rules can only flag sample defects. **They never cause
a sample to be dropped.**

## 6. Raw observations, derived features, predictions

| Layer | Where | What | Rule |
|---|---|---|---|
| Raw observations | `qoesense_telemetry.samples` (this contract) | §3–4 | Device-side transformations are limited to: hashing (cell ID, for privacy), counter → rate (throughput), OS bars, and the session-category / tier labels, which are classifications of observed facts. No smoothing, windowing or imputation. |
| Labels | `qoesense_telemetry.mos_responses` | MOS 1–5 + context | Ratings are raw participant input. The context fields say where they came from (`contextSource`). |
| Derived features | **proposed** dataset `qoesense_features` (BigQuery views/tables) | per-MOS-window aggregates, e.g. mean/std/min/max RSRP, % stale, RTT percentiles, handovers (changes of `cellIdentityHash`) | Rebuildable from raw data at any time. Versioned by view name. Never written back into `samples`. |
| Model predictions | **proposed** dataset `qoesense_predictions` | predicted MOS + `modelVersion` + `featureSetVersion` + `predictedAtMs` | Never mixed with labels or raw data |
| On-device rules | none uploaded | the anomaly detector's reason and the survey bookkeeping | Only their *effect* is recorded: `triggerType = ANOMALY` |

## 7. Versioning, serialization and backward compatibility

- **Format:** gzip of UTF-8 NDJSON.
  - One JSON object per sample, with `\n` between lines and no trailing newline.
  - Keys are camelCase. Every key of the line's version is always present, with explicit
    `null` where there's no value.
  - `capabilitySet` is a JSON array in enum order.
- **Path:** `telemetry/{uid}/{yyyy-MM-dd local}/{uuidv4}.json.gz`. This is **unchanged for
  every version**. The same `loadTelemetryBatch` loads v1 and v2 lines into the same table.
  A v1 line under the v2 schema simply leaves the v2 columns NULL; a test pins this.
- **Version marker:** `schemaVersion` (NULL = v1). The serializer is constructed with a
  `ContractVersion`, and **`BatchSerializer.defaultVersion` stays `v1`** until the v2 deploy
  is confirmed (a test pins it). Each batch is one version.
- **Old clients:** the reference app keeps sending v1 forever, and nothing about it needs to
  change. v1 rows stay valid; their NULL v2 columns are interpreted as described in §8.2.
- **Enum growth:** new enum values may appear (as `IOS_RAT` did). A value is never reused or
  renamed, and analyses must handle unknown values.
- **Evolution procedure:**
  1. Propose the columns in `contracts/proposed/`.
  2. Get owner approval.
  3. Change `functions/index.js` in the reference repo, deploy it, and confirm the columns exist.
  4. Bump the default `ContractVersion`.
  5. Release clients.

  Tests enforce that v2 ⊇ v1 with unchanged types and modes, and that every added column is
  non-REQUIRED.
- **MOS documents:** Firestore accepts extra fields, and the deployed `exportMosResponse` maps
  fields explicitly. The new app can therefore write the v2 MOS fields **from its first
  release**. They are kept in Firestore and reach BigQuery once the v2 function is deployed,
  with a one-off backfill for documents written earlier.

## 8. Proposed backend changes (NOT applied, NOT deployed)

### 8.1 BigQuery columns: all additive

- **`samples`:** the 20 columns in §4, of which `platform` is already committed on `main`.
  - `capabilitySet` is `REPEATED`. Every other new column is `NULLABLE`.
  - Full schema: `contracts/proposed/bigquery_samples_schema_v2.json` (49 columns).
- **`mos_responses`:** 8 columns, listed in §10.
  - Full schema: `contracts/proposed/bigquery_mos_responses_schema_v2.json` (18 columns).

### 8.2 `functions/` changes needed later (in the reference repo, after approval)

1. Append the v2 fields to `SAMPLES_SCHEMA` and `MOS_SCHEMA`.
2. `schema.js`: let `missingNullableFields` also add `REPEATED` fields. Today it treats any
   mode other than NULLABLE as REQUIRED, and would throw on `capabilitySet`.
3. `exportMosResponse`: pass each v2 field through only when the document has it, the same
   pattern as `platform` today.
4. A view `qoesense_telemetry.samples_v`, which adds
   `COALESCE(platform, IF(telemetryCapabilityTier = 'IOS_RAT', 'IOS', 'ANDROID'))` and
   `COALESCE(schemaVersion, 1)`.
5. No Storage path, rules or trigger changes.

### 8.3 Proposed, separate approval needed

- ~~`devices/{uid}.previousDeviceId` ID linking~~: **declined** (D-8). The new app will be the
  primary app, and reference-app data won't be linked.
- The datasets `qoesense_features` and `qoesense_predictions` (§6).

## 9. Example records

These are the exact golden lines from `contracts/fixtures/`. They are reformatted here for
reading; the real lines are single-line JSON.

**A1: Android, all measured** (v2; the v1 part of this line is byte-identical to
`batch_v1.ndjson` line 1):
```json
{"timestampMs":1762500000000,"rsrp":-95,"rsrq":-11,"rssnr":12,"timingAdvance":3,"networkType":"LTE",
 "cellIdentityHash":"a1b2c3d4e5f60718","trackingAreaCode":12345,"signalStrengthLevel":3,"cqi":9,
 "cqiSupported":true,"cellBandwidthKhz":null,"downlinkChannelNumber":null,"uplinkChannelNumber":null,
 "connectionType":"CELLULAR","isRoaming":false,"throughputBytesPerSecond":20480,"rttMs":84,
 "foregroundAppPackage":"com.whatsapp","appSessionType":"SOCIAL_MEDIA","latitude":4.0511,
 "longitude":9.7679,"locationAccuracyMeters":12.5,"deviceModel":"SM-A155F","androidVersion":34,
 "appVersion":"2.0.0","telemetryCapabilityTier":"CQI_29","deviceId":"uid-123",
 "schemaVersion":2,"platform":"ANDROID","radioStatus":"OK","cqiStatus":"OK",
 "physicalChannelStatus":"RESTRICTED","networkTypeStatus":"OK","connectivityStatus":"OK",
 "throughputStatus":"OK","rttStatus":"OK","foregroundAppStatus":"OK","locationStatus":"OK",
 "capabilitySet":["RADIO","CQI","NETWORK_TYPE","CONNECTIVITY","THROUGHPUT","RTT","FOREGROUND_APP","LOCATION"],
 "appId":"io.github.kouotou.qoesense","appBuild":1,"osVersion":"14","utcOffsetMinutes":60,
 "captureDurationMs":2310,"cellInfoAgeMs":850,"locationAgeMs":1200,"throughputWindowMs":60000,
 "rttMethod":"DART_HTTPS_GET_GENERATE_204"}
```

**A2: Android, degraded.** A cached CellInfo 95 s old, location revoked, no usage access, the
first tick after a restart, and not an RTT tick. In v1 the RTT, location, foreground-app and
throughput nulls all looked identical; here each one carries its reason:
```json
{..."rsrp":-112,"rsrq":-15,"rssnr":-2,"timingAdvance":null,...,"rttMs":null,"foregroundAppPackage":null,
 "appSessionType":"NONE","latitude":null,...,"telemetryCapabilityTier":"BASE_26",...,
 "radioStatus":"STALE","cqiStatus":"UNAVAILABLE","physicalChannelStatus":"RESTRICTED",
 "throughputStatus":"UNAVAILABLE","rttStatus":"NOT_ATTEMPTED","foregroundAppStatus":"PERMISSION_DENIED",
 "locationStatus":"PERMISSION_DENIED","capabilitySet":["RADIO","CQI","NETWORK_TYPE","CONNECTIVITY","THROUGHPUT","RTT"],
 "cellInfoAgeMs":95000,"locationAgeMs":null,"throughputWindowMs":null,"rttMethod":null}
```

**I1: iOS, during a call.** No radio values exist, and none are invented:
```json
{"timestampMs":1762500075000,"rsrp":null,"rsrq":null,"rssnr":null,"timingAdvance":null,"networkType":"LTE",
 "cellIdentityHash":null,"trackingAreaCode":null,"signalStrengthLevel":null,"cqi":null,"cqiSupported":false,
 "cellBandwidthKhz":null,"downlinkChannelNumber":null,"uplinkChannelNumber":null,"connectionType":"CELLULAR",
 "isRoaming":null,"throughputBytesPerSecond":98304,"rttMs":131,"foregroundAppPackage":null,
 "appSessionType":"VIDEO_CONFERENCING","latitude":3.848,"longitude":11.5021,"locationAccuracyMeters":65.0,
 "deviceModel":"iPhone14,5","androidVersion":18,"appVersion":"2.0.0","telemetryCapabilityTier":"IOS_RAT",
 "deviceId":"uid-123","schemaVersion":2,"platform":"IOS","radioStatus":"NOT_SUPPORTED",
 "cqiStatus":"NOT_SUPPORTED","physicalChannelStatus":"NOT_SUPPORTED","networkTypeStatus":"OK",
 "connectivityStatus":"OK","throughputStatus":"OK","rttStatus":"OK","foregroundAppStatus":"NOT_SUPPORTED",
 "locationStatus":"OK","capabilitySet":["NETWORK_TYPE","CONNECTIVITY","THROUGHPUT","RTT","LOCATION"],
 "appId":"io.github.kouotou.qoesense","appBuild":1,"osVersion":"18.1","utcOffsetMinutes":60,
 "captureDurationMs":4020,"cellInfoAgeMs":null,"locationAgeMs":3100,"throughputWindowMs":15000,
 "rttMethod":"DART_HTTPS_GET_GENERATE_204"}
```

**I2: iOS on Wi-Fi.** Location is When-In-Use only, so it's denied in the background, and
the RTT probe failed: `"rttStatus":"FAILED"`, `"locationStatus":"PERMISSION_DENIED"`, with
all radio fields null and `NOT_SUPPORTED`. See `samples_v2.ndjson` line 4.

**MOS, M2: iOS, rated from the notification, self-reported context** (Firestore body plus
its document ID):
```json
{"responseId":"8c7b6a59-4d3e-4f2a-b1c0-9d8e7f6a5b4c","score":4,"submittedAtMs":1762500300000,
 "triggerType":"POST_SESSION","contextAppPackage":"com.whatsapp","contextSessionType":"VIDEO_CONFERENCING",
 "windowStartMs":1762499700000,"windowEndMs":1762500300000,"schemaVersion":2,"platform":"IOS",
 "contextSource":"SELF_REPORTED","presentationMode":"NOTIFICATION_ACTION",
 "appId":"io.github.kouotou.qoesense","appVersion":"2.0.0","appBuild":1,"utcOffsetMinutes":60,
 "promptedAtMs":1762500250000}
```

## 10. MOS response: field migration

| Field | v1 | v2 | Notes |
|---|---|---|---|
| `deviceId`, `responseId` | from the document path | unchanged | `responseId` is a tap-time UUID v4; retries reuse it |
| `score` | INT, REQ, 1–5 | unchanged | The scale is unchanged |
| `submittedAtMs` | INT, REQ | unchanged | Tap time |
| `triggerType` | `PERIODIC`, `POST_SESSION`, `ANOMALY` | unchanged | iOS anomalies come from RTT/throughput/path signals |
| `contextAppPackage` | observed package | + iOS self-report mapped to the Android package (D-6) | Read it together with `contextSource` |
| `contextSessionType` | REQ | unchanged values | `NONE` when the context is `UNKNOWN` |
| `windowStartMs` / `windowEndMs` | tap − 10 min / tap | unchanged | The join key range |
| `platform` | committed, not deployed | `ANDROID`, `IOS` | |
| `schemaVersion` | none | `2` | |
| `contextSource` | none | `OBSERVED`, `SELF_REPORTED`, `UNKNOWN` | Makes D-6 explicit instead of inferring it from the platform |
| `presentationMode` | none | `OVERLAY`, `NOTIFICATION`, `NOTIFICATION_ACTION`, `IN_APP` | Label quality: how the prompt was answered |
| `promptedAtMs` | none | epoch ms or null | `submittedAtMs − promptedAtMs` is the response latency |
| `appId`, `appVersion`, `appBuild` | none | | MOS rows currently have no app version at all |
| `utcOffsetMinutes` | none | | Local time of the rating |

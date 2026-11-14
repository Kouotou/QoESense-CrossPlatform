# Phase 6: acceptance and regression testing

**Status (2026-11-14):**
- the PC/Android/backend part is complete;
- the iOS part is pending at the Mac (`PHASE6_MAC_HANDOFF.md`, results to come in
  `PHASE6_IOS_RESULTS.md`).

**No store release has been made.**

**Legend:**
- **PASS / FAIL / NOT RUN.**
- Kind: **U** = unit/widget/contract (host), **E** = Firebase emulator, **D** = physical
  device, **P** = production pipeline (live Firebase).
- Physical device: Infinix X669, Android 12, the owner's phone. Unless stated otherwise,
  device results are from **2026-11-14**.

## 1. Automated test results

| Suite | Kind | Result |
|---|---|---|
| App: `tool\verify.ps1` (format, codegen in sync, analyze, tests, APK build) | U | **157/157 PASS**; analyze clean; APK builds |
| Backend: the real trigger code of 3 versions (deployed, main, proposed) and the exporter, against synthetic Android + iOS v1/v2 payloads (`functions`, `npm test`) | U | **16/16 PASS** |
| Security rules: current and proposed, Firestore + Storage (`rules-tests`) | E | **18/18 PASS** |
| iOS XCTest (24) | U | NOT RUN on the PC (needs a Mac; it passed at the 2026-11-10 Mac session) |

## 2. Android physical-device test matrix

| # | Requirement | Kind | Result | Evidence |
|---|---|---|---|---|
| A1 | Real RSRP | D | **PASS** | 3 checks a minute apart, app vs `dumpsys telephony.registry`: −82/−84, −82/−83, −84/−84 dBm; signal level 4 = 4 |
| A2 | Other cellular values | D | **PASS** | RSRQ present. RSSNR and TA are reported **unavailable** by this modem (`2147483647`) and stored as null, never invented. CQI unavailable → `cqiSupported=false`, tier `BASE_26` (correct). |
| A3 | Cell-info freshness | D | **PASS** | Median reading age 10 ms. Identical consecutive radio rows: **7%** (original app: **74%**). |
| A4 | Capability-tier resolution | U + D | **PASS** | Resolver tests. Every device row is `BASE_26`, matching the absence of CQI and PhysicalChannelConfig. |
| A5 | 60 s cadence at rest | D | **PASS** | Median gap 60.0 s over 3,508 rows (7–14 Nov) |
| A6 | 15 s in a video call | D | **PASS** | WhatsApp Business call on 11-09 13:51–13:56: 21 samples, median gap **15.0 s**, RTT on 20/21 |
| A7 | Background, screen locked (Doze) | D | **PASS (bounded)** | After decision C: max gap **20 min** over 125 h (before C: 303 min). The target was ~10 min; Android limits `setAndAllowWhileIdle` to about once per 9–15 min. |
| A8 | Process interruption | D | **PASS** | `am crash` at 20:02:16. The system logged "Scheduling restart of crashed service … CollectorService in 20921ms"; the next sample was at 20:02:40, then 60 s again. |
| A9 | Reboot recovery | D | **PASS (11-07 build)** | Restarted on its own after the 11-07 reboot, with Auto-start enabled. The boot code hasn't changed since. **Re-test on the current build: NOT RUN.** |
| A10 | Restart after an app update | D | **PASS** | Collection resumed by itself after each install today |
| A11 | Permission revoked mid-run | D | **PASS** | Location revoked at 20:05:06. The 20:05:10 sample had radio + location **PERMISSION_DENIED with null values**; the capability set dropped RADIO, CQI and LOCATION; network type was still OK; no crash. Re-granted: OK again at 20:08:10. |
| A12 | Anomaly detection | U + D | **PASS** | Detector + collector tests (fresh-only input). An ANOMALY prompt and rating occurred on the device (11-07 18:54). |
| A13 | Survey cooldown / daily cap | U + D | **PASS** | Policy tests. The device showed 6 prompts on 11-08, then none. |
| A14 | MOS ↔ telemetry window join | D + P | **PASS** | Each of the 4 ratings from the new Android app has **9–10 samples** in its 10-minute window (export join) |
| A15 | Persistence and retry guarantee | D + P | **PASS** | 3,493 rows were kept on the phone through 7 days of failed uploads, then uploaded. The buffer went to 0 only after confirmed writes. |
| A16 | Consent before collection | U + D | **PASS** | Widget test. On the device, consent was at 18:03:46 and the first sample at 18:05:28. |
| A17 | Firebase identity | D + P | **PASS** | Anonymous UID `0y5ZtaFl…` across all uploads and ratings |
| A18 | **Free-tier upload** (Firestore) | D + P | **PASS** | "Upload now" → 2 batches (65,637 B) → buffer 0 → 3,508 rows exported; later hourly runs added 7 more batches (14 rows) |
| A19 | Cloud Storage upload, Cloud Functions, BigQuery ingestion | P | **NOT RUN** | Billing disabled. They're replaced by the approved free path. The code is covered by U tests only (§1). |
| A20 | Battery, 24 h vs the original app | D | **NOT RUN** | Needs a planned 24 h unplugged comparison |

## 3. Android comparison against the original app

Original: the BigQuery backup, 6,798 rows, 5 devices, v1.0, Aug–Sep 2026.
New: the export, 3,508 rows, the test phone, v2.0.0, 7–14 Nov 2026.

| Metric | Original | New | Comment |
|---|---|---|---|
| Median sampling gap | 22 s | **60 s** | The agreed change (60 s / 15 s) |
| **Identical consecutive radio rows** | **74%** | **7%** | `requestCellInfoUpdate` fix: the root cause of the duplicate rows |
| Distinct RSRP values | 51 | 53 | Similar range, with far fewer rows |
| Foreground app identified | 6% | **50%** | Stateful tracking (fix D) |
| VIDEO_CONFERENCING rows | 0 | 21 | WhatsApp Business added; the call heuristic works |
| Location present | 97% | 62% (84% outside the owner's 36 h with data off) | Lower partly because of the data-off period. When there's no fix, the status now says why (TIMEOUT / UNAVAILABLE). |
| Max gap | 77.6 h | 5.0 h (20 min after decision C) | Doze wake-ups |
| Missing-value reasons | none (null only) | per-group status (v2, kept on the device) | Uploaded once contract v2 is deployed |

**Behaviour that deliberately differs:** see `PHASE3_ANDROID.md` §3, items A–O (cadence,
retention, network type, foreground tracking, MOS never dropped, RTT method, fresh radio,
WhatsApp Business, Doze alarm, and so on).

## 4. iOS capability and limitation report

Pending the Mac session. It will be compiled from `PHASE6_IOS_RESULTS.md`. What's already
established:
- see `IOS_CAPABILITY_MATRIX.md`;
- the iPhone 14 Pro Max run on 11-09/10: 922 samples, all `IOS_RAT`, no radio values,
  60 s / 15 s cadence, 12.6 h of background without gaps;
- 3 iOS ratings are in Firestore.

## 5. Backend integration report

| Path | State | Evidence |
|---|---|---|
| Anonymous Auth | **Working** (P) | Both test devices |
| Firestore ratings + consent | **Working** (P) | 72 ratings and 7 consent docs; backed up |
| Firestore telemetry batches (free path) | **Working** (D + P) | A18 |
| PC exporter → CSV/NDJSON (BigQuery layout) | **Working** (P) | 3,522 rows, 0 duplicates |
| BigQuery sandbox load | **Working** (P) | 72 ratings loaded into `qoesense_free_export` |
| Cloud Storage → loadTelemetryBatch → BigQuery | **NOT RUN** | Billing disabled. The last row is from 2026-09-03. |
| Firestore → exportMosResponse → BigQuery | **NOT RUN** | 58 ratings unexported; backfill tool ready (dry run done) |
| Contract v2 functions, proposed rules, views | Ready, **not deployed** | PHASE5_BACKEND §6 (needs approval) |

## 6. Security and privacy review

| # | Finding | Severity | State |
|---|---|---|---|
| S1 | **Android backup:** app data (location buffer, Firebase session) was eligible for cloud backup and device-to-device transfer. A restore would also **give two phones the same anonymous UID**. The original app has the same issue (`allowBackup="true"`, template rules). | High | **FIXED in the new app** (`allowBackup=false`, `fullBackupContent=false`, `dataExtractionRules` exclude everything); the device flags were checked. iOS check added to the Mac brief (#14). The original app is unchanged. |
| S2 | The deployed functions log raw UIDs | Medium | Fixed in the proposed functions (hashed). Not deployed. |
| S3 | Production rules allow deleting ratings, out-of-range scores, and overwriting or deleting batches | Medium | Proposed rules fix this (18/18 on the emulator). Deploying them is **free** but needs approval (P4). |
| S4 | Firebase Auth SDK debug log prints the UID (3 lines today). Other apps can't read logs since Android 4.1, but they're visible over USB. | Low | Recommendation: strip `Log.d/v` in release builds (R8 rule) |
| S5 | No coordinates, tokens or API keys in logs | — | **Verified** (D): a logcat scan of 14,154 lines |
| S6 | Uploads contain only contract fields: anonymous UID, no names, phone numbers, IMEI or account | — | **Verified** (U contract tests + export) |
| S7 | `cellIdentityHash` is 16 hex characters of SHA-256 over "ci:tac". The input space (~2^44) could be brute-forced by a determined party. | Low | Pseudonymous, not anonymous. Document it in the privacy policy, or add a secret salt later. |
| S8 | Full-precision coordinates are stored | Decision | The consent says "approximate location". Option: round to ~100 m before upload. Owner's decision. |
| S9 | Firebase API keys are in the repo | Low | They're public client identifiers by design. Recommendation: restrict the keys to the app IDs in Google Cloud Console (free). |
| S10 | Local backups and exports (`QoESense-backups`, `QoESense-exports`) contain participant data | Info | Outside both repos, never committed. Keep the PC encrypted. |

## 7. Defects found and fixed during Phase 6

| Defect | Fix | Re-test |
|---|---|---|
| "Upload now" did nothing: the KEEP policy kept a job stuck in backoff | REPLACE | D: an upload ran right after the tap |
| Two upload runs could overlap (hourly + one-off, seen in the same second) | One drain per process (an `AtomicBoolean` guard) | U build + D install. **Re-observation: pending** (the next hourly run) |
| S1: backup/transfer of the app's data and Firebase session | Manifest + `data_extraction_rules.xml` | D: the `ALLOW_BACKUP` flag is gone |

## 8. Release blockers

| # | Blocker | Store | Owner action |
|---|---|---|---|
| R1 | Android release signing still uses the **debug key** (template) | Play | Create an upload keystore for `io.github.kouotou.qoesense` (never commit it) |
| R2 | Restricted permissions: `PACKAGE_USAGE_STATS`, `SYSTEM_ALERT_WINDOW` and background location need the Play **Permissions Declaration** form + a demo video; foreground-service types (dataSync, location) need the Android 14 FGS declaration | Play | Forms + video |
| R3 | **Privacy policy URL** + Data safety form (Play) / App Privacy (Apple) | both | Publish the policy (the consent text exists) |
| R4 | **Paid Apple Developer Program** ($99/yr) for TestFlight/App Store, plus a Mac for the first upload. The free-team builds expire every 7 days. | App Store | Enrol |
| R5 | iOS acceptance (Mac session) | App Store | Pending |
| R6 | 24 h battery comparison (A20, plus iOS) | both | Plan the runs |
| R7 | The backend paid path is NOT RUN. The free path is in use: fine for research, but the automatic BigQuery pipeline needs billing. | research | Fix billing, or stay on the free path |
| R8 | Proposed rules not deployed (S3) | both | Approve P4 (free) |
| R9 | Participants still on the **original app** can't upload (Storage), and that app has S1 | research | Move them to the new app |
| R10 | Reboot re-test on the current build (A9) | Play | 2 minutes on the test phone |

## 9. Final acceptance checklist

- [x] Automated suites green (U 157 + 16, E 18)
- [x] Android: real measurements, freshness, tiers, cadence 60/15, crash/update/permission recovery
- [x] No invented radio values; missing data explained per group
- [x] MOS ↔ window joins; consent before collection; persistence until a confirmed write
- [x] Free-tier pipeline end to end (device → Firestore → export → sandbox)
- [x] No duplicates in the export; a concurrency guard added
- [x] Privacy: logs scanned, backup leak fixed
- [ ] Reboot re-test on the current build (R10)
- [ ] 24 h battery (R6)
- [ ] iOS acceptance (R5)
- [ ] Owner decisions: P4 rules (R8), location precision (S8), billing (R7)
- [ ] Store prerequisites R1–R4

## 10. Report alignment changes (2026-11-14, after the matrix above)

The owner compared the app with the MSc report and approved: v2 uploads, Option A (3-hour
uploads + `--delete-exported`), a 3-day upload reminder, brand-specific auto-start onboarding,
an Android cell-change counter, Facebook Lite / Instagram Lite / TikTok Lite / Messenger
(with Messenger calls on the in-call cadence), and the survey question "How was your
experience in the last few minutes?". No 3G/2G detail: the study stays LTE.

**Automated:**
- `tool\verify.ps1`, full: format, regeneration, analyze, **169 Dart tests**, APK and the new
  **Kotlin unit tests (10)**. The script now runs those with the JBR.
- `QoESense/functions` `npm test`: **19/19**, including the `--delete-exported` and CSV rebuild
  tests.

**Infinix X669, physical device (debug build installed over the running app):**

| Check | Result | Evidence |
|---|---|---|
| Upload job switches to 3 h on update | PASS | WorkManager DB: `telemetry_upload` interval 3.0 h, generation 1 (UPDATE kept its history) |
| Auto-start screen for the brand | PASS | Brand detected as Transsion (INFINIX); `com.transsion.phonemaster/…AutoStartActivity` opens "Gestion de démarrage automatique", QoESense listed. The French text now uses that exact label. The onboarding card itself was tested by a widget test, not on the phone (onboarding is complete there). |
| Upload reminder | **Defect found and fixed** | The first build showed the reminder right after the update (FR text, own channel), wrongly: the phone had uploaded at 20:50, but the new `upload.lastSuccessMs` key didn't exist yet, so the policy fell back to the consent date. Fix: the reminder also uses the native last-upload time (both platforms keep one). After the fix (stale reminder record removed): no reminder, none recorded. |
| Cell-change counter | PASS, **fixed on the way** | Null after each restart, then 0/1/2. Every 1 matches a change of the serving-cell hash (sectors 114945 ↔ 114946 of one site, the phone is at their edge). The phone's own log showed the same cell sometimes reported with its cell ID unavailable, which would have faked a change: the key is now PCI + channel, over the set of registered cells (dual-SIM). |
| v2 upload end to end | PASS | "Upload now" → `Worker result SUCCESS`. The exporter, run read-only on a **copy** of the export folder, found 4 new batches: the post-update rows are `schemaVersion` 2 / `ANDROID`, with `cellChangesSinceLastSample` present. `samples.csv` was rebuilt to 50 columns, and all 3,626 rows have the same width. |
| Survey wording | Not seen on the phone | Changed in the strings (EN/FR) and covered by widget tests. Check at the next real prompt. |
| Messenger / Lite apps | Not run on the phone | They aren't installed on the test phone. Kotlin unit tests cover the package lists and the call-capable set. |

**Not run (no approval to delete production data):** `--delete-exported` against Firestore.
It's covered by unit tests with a fake Firestore (chunking, checkpoint boundary, exclusions,
idempotency, read counts).

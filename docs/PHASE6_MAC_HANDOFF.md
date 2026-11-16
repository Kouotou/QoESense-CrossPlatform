# Phase 6 Mac session: brief (read this first)

**For the Claude Code session on the borrowed Mac.** Written 2026-11-14 on the Windows PC. You
have no memory of earlier sessions; this file, `CLAUDE.md` and the docs it links are the
source of truth. **Decisions recorded here override older prompts and docs.**

## 1. What changed since the Phase 4 Mac session (2026-11-10)

| Change | Where | iOS impact |
|---|---|---|
| **Firebase billing is disabled, and the project moved to the FREE path.** Telemetry batches now go to **Firestore** `devices/{uid}/telemetryBatches/{batchId}` (the same gzipped NDJSON bytes), no longer to Cloud Storage. Cloud Functions and the automatic BigQuery load don't run. Data is exported on the PC with `QoESense/functions/tools/export_firestore.js`. | `lib/src/data/backend/batch_document.dart` (`activeUploadTarget = firestore`), `firebase_backend.dart`; `docs/FREE_TIER_MIGRATION.md` | **Dart only, no Swift change.** The iPhone needs a rebuild so its uploads start working. |
| In-call RAT changes are ignored by the iOS anomaly detector (CSFB fix), during a call and for 60 s after it | `lib/src/application/path_anomaly_detector.dart` | Dart only; needs the rebuild |
| The iOS consent, welcome and permission texts (EN + FR) and the iOS anomaly rules are **approved** | `lib/l10n/*.arb` | none |
| `phase4/ios` is merged into `main`. All work since then is on `main`. | | |
| The Android "Upload now" uses REPLACE (the old KEEP policy got stuck) | Android Kotlin | none |
| Android device validation passed (cadence, fresh radio, reboot, survey → Firestore, free-tier upload: 3,493 samples → 2 batches → buffer 0 → 3,508 rows exported) | `docs/PHASE3_ANDROID.md`, `docs/FREE_TIER_MIGRATION.md` | none |

## 1b. iOS changes required: report alignment (2026-11-14, after this brief was first written)

The owner compared the app with the MSc report and approved a set of changes. They were
implemented and tested on Windows (Dart + Android, device-checked on the Infinix). The iOS
side is mostly shared Dart, but **one Swift method was written on Windows and has never been
compiled**. Do these as part of task A, before the acceptance tests.

| # | Change | Where | What the Mac must do |
|---|---|---|---|
| R1 | **Upload reminder** after 3 days without a successful upload (buffer not empty, at most once a day). Dart decides (`UploadReminderPolicy`) and passes EN/FR texts; native code posts a local notification. Existing installs use the native last-upload time, so they aren't reminded wrongly after the update (a bug found on Android). | `lib/src/application/upload_reminder.dart`; pigeon `IosCollectorApi.showUploadReminder`; **Swift `IosCollectorHost.showUploadReminder` (NOT YET COMPILED)** | Build; fix compile errors only. On the iPhone: it hasn't uploaded since the free-tier change, so the reminder should appear within ~15 min of the first collector tick after the reinstall, **before** "Upload now" (in the iPhone's language, FR or EN). After a successful upload it must not come back. Record the evidence. |
| R2 | **Survey wording:** "How was your experience in the last few minutes?" / « Comment s'est passée votre expérience au cours des dernières minutes ? » | `ios/Runner/IosSurvey.swift` (`SurveyStrings`), `lib/l10n/*.arb` (sheet) | Check the notification and the in-app sheet show the new text. |
| R3 | **Uploads every 3 h** instead of hourly (free-tier scale, "Option A") | Dart `UploadGate.interval`; Swift `IosCollectorHost.uploadInterval` (BGTask) | Nothing to change. "Upload now" still forces a run. |
| R4 | **Free-path uploads are contract v2** (statuses incl. STALE/TIMEOUT, `platform`, `capabilitySet`, provenance) | Dart `uploadContractVersion` | Nothing to change. When the owner says "iPhone uploaded", the Windows session checks that the exported iPhone rows have `schemaVersion` 2 and `platform` IOS. |
| R5 | **Self-report:** new options "Messenger call" (video conferencing) and "Messenger messages" (social media) | `lib/src/application/self_report.dart`, `survey_sheet.dart`, arb | Check both appear in the sheet (EN/FR). |
| R6 | New v2 field **`cellChangesSinceLastSample`** (Android only) | pigeon `CapturedSampleMessage`, regenerated `TelemetryApi.g.swift` | **iOS leaves it nil** (the generated initializer defaults it). The contract rules reject a non-null value on iOS, so don't set it. Just check the generated file compiles with `IosCapture.swift`. |
| R7 | `TelemetryApi.g.swift` was regenerated (it also adds `autoStartBrand` / `showUploadReminder` to the Android API) | `ios/Runner/TelemetryApi.g.swift` | Don't hand-edit. If pigeon output differs on the Mac, regenerate with `dart run pigeon --input pigeons/telemetry_api.dart`. |
| R8 | **Firebase App Check** (2026-11-16) in **monitoring mode, not enforced**: debug builds use the debug provider, release builds DeviceCheck (no entitlement, so the free team still signs) | `lib/src/data/backend/app_check.dart`, plugin `firebase_app_check` (new CocoaPod), `docs/APP_CHECK.md` | Run `pod install` (or let `flutter build ios` do it). Don't add the App Attest entitlement: the free team can't sign it. Check the app still uploads and rates as before. **Don't** enable enforcement in the console. Note in the results whether the Xcode console shows an App Check error. That's expected without a paid account, as long as uploads still succeed. |

**Not applicable to iOS** (Android-only by design, nothing to do):
- Facebook Lite, Instagram Lite, TikTok Lite and Messenger foreground detection, and the Messenger call cadence;
- the brand-specific auto-start onboarding;
- the cell-change counter;
- WorkManager's UPDATE policy.

No 3G/2G detail was added: the study stays LTE.

Add these rows to the test matrix in §3 C and to `PHASE6_IOS_RESULTS.md`:

| # | Check |
|---|---|
| 15 | R1: the Swift reminder compiles; it shows on the iPhone after the reinstall (no upload for more than 3 days); it isn't repeated within a day; it doesn't come back after a successful upload |
| 16 | R2 + R5: the new survey wording (notification + sheet); the Messenger options in the sheet |
| 17 | R4: the iPhone's uploaded rows are v2 (checked from Windows after "iPhone uploaded") |

**Test devices.** Their data is **test data** and is excluded from analyses:
- iPhone 14 Pro Max (friend's): UID `UD1DfRM9K9Wow7GaL8BrGfbSFiG2`;
- Android Infinix X669: UID `0y5ZtaFlJbMVBMyigwzN6TrKEHq1`.

## 2. Rules for this session

- Work on a new branch: **`phase6/ios-acceptance`**, created from the latest `origin/main`.
- **Don't** change Android code, the data contract, Firebase rules, Cloud Functions or
  BigQuery. **Don't** deploy anything, and **don't** release to TestFlight or the App Store.
- Phase 6 is testing. Record defects first, fix them only in small changes with a test, and
  rerun what they affect. No architectural changes.
- **Never report a test as passed unless it was actually run.** Label every result: unit,
  XCTest, simulator, physical device, or production pipeline.
- Keep the sampling at **60 s / 15 s**. Older prompts saying 20 s / 5 s are superseded.

## 3. Tasks, in order

### A. Update, rebuild, reinstall (first)

1. If `~/dev/QoESense-CrossPlatform` exists: `git fetch origin && git checkout main && git pull`.
   Otherwise clone `https://github.com/Kouotou/QoESense-CrossPlatform.git` into it. Then
   `git checkout -b phase6/ios-acceptance`.
2. `export PATH="$HOME/dev/flutter/bin:$PATH"`. Install Flutter **3.47.9** if it's missing
   (see `PHASE4_MAC_SESSION_SUMMARY.md` §10). Then run `SKIP_ANDROID=1 ./tool/verify.sh`;
   everything must pass.
3. Signing: the owner signs in to Xcode with their Apple ID (free Personal Team, as before).
   Build a **release** build, install it **over** the existing app (keeping its buffer), and
   check that it opens. The free-team install lasts 7 days from this install.

   **Install lifetime (the owner asked for 1 month, 2026-11-16).** Apple fixes it by account
   type. No build setting changes it, so don't try to work around it:

   | Owner's Apple account | How the install is made | Lifetime |
   |---|---|---|
   | Free (Personal Team) | Xcode run/install, as above | **7 days**: the profile can't be longer. Re-install from the Mac to renew (the data is kept). |
   | **Paid Apple Developer Program** ($99/year) | Register the iPhone's UDID in the developer account. Then use a Development (or Ad Hoc) profile, built and installed from Xcode | **up to 1 year** (the profile's expiry) |
   | Paid, via TestFlight | Archive → upload to App Store Connect → internal testing | **90 days** per build, and the phone needs no Mac to renew. This is an upload to Apple, so it needs the owner's explicit OK. |

   Before signing, ask the owner which account is signed in. With a paid account, install a
   Development build and **read the real expiry** from the installed profile (iPhone Settings →
   General → VPN & Device Management, or `security cms -D -i` on the `embedded.mobileprovision`
   inside the built app). Report that date. Never claim a lifetime you haven't read from the
   profile. With the free account, report the 7-day date, and say that a month needs the paid
   program.

### B. Check the free-tier upload on the iPhone

1. On Wi-Fi, tap "Upload now" on the status screen. "Last upload" should update, and the
   buffered count should drop.
2. Tell the owner to tell the **Windows Claude session** "iPhone uploaded". That session
   checks Firestore (`devices/UD1DfRM9…/telemetryBatches`) and runs the exporter, because
   this Mac has no Firebase admin login.

### C. Phase 6 iOS acceptance tests (physical iPhone)

Use `docs/PHASE4_IOS.md` §8 and `docs/IOS_CAPABILITY_MATRIX.md`. Cover each line, and record
for each: PASS / FAIL / NOT RUN, with evidence.

| # | Check |
|---|---|
| 1 | The capability screen matches the documented public-API matrix |
| 2 | Captured values: RAT, Wi-Fi/cellular, throughput, RTT, location. Radio fields are **null + NOT_SUPPORTED**, never estimated |
| 3 | Cadence: ~60 s at rest; ~15 s during a connected call |
| 4 | Background ≥ 1 h with the screen locked |
| 5 | Interruptions: swipe-away / force-quit (gap, then reopen); reboot; relaunch after a move of > 1 km, if practical |
| 6 | Permission revoked mid-run (location → status, no crash) |
| 7 | Survey: answering from a **notification button**; from the **lock screen**; from the in-app sheet with a self-report |
| 8 | Daily cap of 6 on the local day; the in-call RAT fix (a normal call no longer triggers ANOMALY) |
| 9 | Consent: nothing is collected before consent (fresh install on the simulator, if not on the friend's phone) |
| 10 | Local persistence: kill the app, and the buffered rows are kept; nothing is deleted without a confirmed upload |
| 11 | Free-tier upload (B) |
| 12 | Logs: no location, UID or credentials printed (Console.app filter on the app) |
| 13 | Battery: rough % per hour over a long unplugged run, if time allows |
| 14 | **Backup/identity (found on Android in Phase 6):** the app's data must not go to iCloud/device backups. Mark the SQLite database (and its `-wal`/`-shm` files) with `isExcludedFromBackup`, and check how the Firebase Auth session is stored in the Keychain: restoring a backup onto another iPhone must **not** give it the same anonymous UID. Fix it if it's small; otherwise record it as a defect. |

Copy the buffer off the phone at the end (`devicectl … copy from`, then
`python3 -I tool/analyze_buffer.py <dir>`), and include its summary.

### D. Record and hand back

1. Write **`docs/PHASE6_IOS_RESULTS.md`**:
   - the test matrix (#1–17) with PASS/FAIL/NOT RUN and evidence;
   - the defects found and fixed;
   - the open defects;
   - the iOS limitations;
   - what will need a Mac again.
2. `SKIP_ANDROID=1 ./tool/verify.sh` must pass. Then commit and
   `git push -u origin phase6/ios-acceptance`, and check the branch on github.com.
3. **Before leaving the Mac:** run the cleanup in `PHASE4_MAC_SESSION_SUMMARY.md` §9:
   - Claude `/logout`;
   - remove the GitHub token from Keychain and revoke it;
   - remove the Apple ID and its certificate.

   Keep the project folder and Flutter if the friend agrees.
4. The iPhone keeps the app for further testing only with the friend's agreement. Its data
   stays test data.

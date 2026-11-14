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
   - the test matrix (#1–13) with PASS/FAIL/NOT RUN and evidence;
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

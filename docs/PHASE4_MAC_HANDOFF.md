# Phase 4 handoff: iOS work on the borrowed Mac

**Read this first if you are a Claude Code session on the Mac.** You have none of the
history of the Windows sessions. Everything you need is here, in `CLAUDE.md`, and in
`docs/*.md`. The owner (Kouotou) will paste a "Phase 4" prompt. Where that prompt conflicts
with a decision recorded below, **the recorded decision wins**. Point out the conflict, and
don't silently follow the prompt. In particular, the owner's pre-written prompts may say
"20 s / 5 s sampling" or "14-day retention"; both are superseded.

Written 2026-11-09 on the Windows PC, at the end of Phase 3.

## 1. Where the project is

| Phase | State |
|---|---|
| 0: audit of the reference Android app (`../QoESense`, not on this Mac) | done |
| 1: Flutter workspace, Pigeon channel, CI | done |
| 2: data contract v2 (`docs/DATA_CONTRACT.md`) | **approved**, not deployed (Firebase billing is blocked) |
| 3: Android integration (`docs/PHASE3_ANDROID.md`) | done and **validated on a physical phone** (Infinix X669, Android 12, 2 days) |
| **4: iOS** | starts on this Mac |

**The iOS side as of now:**
- Only `ios/Runner/IOSCapabilityReporter.swift` exists, and it implements
  `TelemetryHostApi.getCapabilityReport`.
- **That Swift code has never been compiled.** Windows can't, and the GitHub Actions macOS job
  is blocked by a GitHub billing lock.
- Compile it first: `flutter build ios --debug --no-codesign`.

**`lib/main.dart` is Android-only today:** it wires `AndroidCollectorControl` and the
`AndroidCollectorApi`. On iOS the UI must get iOS implementations of the same interfaces
(`lib/src/presentation/app_services.dart`). Never call the Android channel on iOS.

## 2. Decisions that bind the iOS work (all approved by the owner)

| ID | Decision |
|---|---|
| Sampling | **60 s at rest, 15 s during a call** (`SamplingPolicy`). The shared Dart `Collector` loop is reused as is. |
| D-1 / D-8 | This app **replaces** the reference app. There is no ID linking. |
| D-2 | Bundle ID **`io.github.kouotou.qoesense`**, already set in `ios/Runner.xcodeproj` |
| D-3 | Every iOS sample has `telemetryCapabilityTier = IOS_RAT` (`CapabilityTierResolver` does this) |
| D-4 | Any CallKit-detected call (`CXCallObserver`) counts as `VIDEO_CONFERENCING`, so it gets the 15 s cadence |
| D-5 | On iOS, `androidVersion` holds the iOS **major** version; `osVersion` holds the full string |
| D-6 | The "what were you doing?" self-report uses Android package names (`com.whatsapp` …), with `contextSource = SELF_REPORTED` |
| D-9 | Contract v2. iOS radio fields (RSRP, RSRQ, RSSNR, TA, cell ID, TAC, bars, CQI, physical channel), the foreground app and roaming are **always null + NOT_SUPPORTED, never estimated**. `contract_rules.dart` rejects anything else, and every sample must pass `contractViolations`. |
| Uploads | Uploads stay on contract **v1** (`BatchSerializer.defaultVersion`) until the v2 functions are deployed. Don't change that. |
| Backend | Firebase/GCP project `qoesense` only. **No** BigQuery, functions or rules changes. |
| Phase 3 C | While the device sleeps, bounded gaps (~10 min) are acceptable. Doze is the Android counterpart. |

## 3. What Phase 4 has to build (the design is in ARCHITECTURE §5 and MIGRATION_MATRIX)

1. **iOS capture (Swift):** one `captureSample(locationTimeoutMs, staleAfterMs)` call per
   tick, the same shape as the Android one. Either make the Pigeon message cross-platform, or
   add an `IosCollectorApi`.
   - RAT via `CTTelephonyNetworkInfo`: LTE → `LTE`; NR/NRNSA → `NR`; nil → `UNKNOWN`; other → `OTHER`.
   - `NWPathMonitor` → `WIFI` / `CELLULAR` / `OTHER`.
   - `getifaddrs` byte counters → throughput, with the window.
   - Core Location fix with its age.
   - `CXCallObserver` for call state.
   - RTT stays in shared Dart (`HttpRttProbe`).
2. **Keeping the app alive in the background:**
   - Background Modes: *Location updates*, *Background fetch*, *Background processing*.
   - Continuous coarse location updates with `allowsBackgroundLocationUpdates = true` and
     `pausesLocationUpdatesAutomatically = false`, so the Dart timer keeps running.
   - Significant-location-change monitoring, to relaunch the app after it's terminated.
   - `BGTaskScheduler` for uploads; Wi-Fi only, checked with `NWPathMonitor`.
3. **The survey on iOS:**
   - An actionable notification with 5 actions (1–5) → `presentationMode = NOTIFICATION_ACTION`.
   - Tapping the notification opens an in-app sheet, which also asks "what were you doing?".
   - Taps go into a durable native queue, then the shared `MosPipeline`, the same as on Android.
4. **Permissions and onboarding on iOS:**
   - Location When-In-Use, then **Always**, then notifications.
   - Skip the Android-only steps (usage access, overlay, battery).
   - **The consent text mentions Android, Usage Access and overlays.** It needs an iOS variant
     in English and French, approved by the owner, before any iOS participant.
5. **Info.plist:** location usage strings (When-In-Use and Always), `UIBackgroundModes`, and
   `BGTaskSchedulerPermittedIdentifiers`.
6. **Firebase iOS:** after the owner registers the iOS app (§5 step 7), copy the values from
   `GoogleService-Info.plist` into `QoESenseFirebaseOptions.ios` in `lib/firebase_options.dart`.
   **Never commit the plist itself**; `test/architecture/layering_test.dart` forbids it.
7. **Tests:** Dart mapping and contract tests for iOS records (`test/support/fixtures.dart`
   already has `iosInCall` / `iosOnWifi`), plus XCTest for any Swift logic that can be tested
   without a device.
8. **Validation on the iPhone:** onboarding; the capability screen; one hour of collection
   with the app in the background; a FaceTime or WhatsApp call (15 s cadence); a survey
   answered from the notification; and the buffer, read through Xcode → Devices → Download
   Container.

## 4. Commands on the Mac

```bash
cd ~/dev/QoESense-CrossPlatform
git checkout -b phase4/ios            # all Mac work on this branch
./tool/verify.sh                      # format, codegen, analyze, tests, iOS build (no signing); APK only if an Android SDK exists
open ios/Runner.xcworkspace           # signing team, capabilities, run on the iPhone
flutter run                           # with the iPhone connected and unlocked
```

## 5. Owner checklist on the Mac (Claude: walk the owner through these, in order)

1. **Install Xcode** from the App Store (large: plan 1–2 h), open it once, and accept the
   license. Then run `xcode-select --install`, and install the iOS platform when Xcode offers it.
2. **Install Flutter 3.47.9.** It must match the Windows machine. Download the macOS zip for
   the right chip (Apple silicon = arm64) from the Flutter SDK archive. Unzip it to
   `~/dev/flutter`, add `~/dev/flutter/bin` to PATH in `~/.zshrc`, then run `flutter doctor`.
3. **Clone with a GitHub token.** Create a fine-grained personal access token with read/write
   access to Contents on `QoESense-CrossPlatform` only, and a 7-day expiry. Then run
   `git clone https://github.com/Kouotou/QoESense-CrossPlatform.git ~/dev/QoESense-CrossPlatform`,
   using the token as the password.
4. **Claude Code:** install it, run `claude` inside the project folder, and log in with the
   owner's account.
5. **Sign in to Xcode** with the owner's Apple Developer account (Xcode → Settings →
   Accounts). In Runner → Signing & Capabilities, select the team and keep automatic signing.
6. **The iPhone:**
   - Connect it with a cable and tap *Trust*.
   - Turn on Settings → Privacy & Security → **Developer Mode**, then restart.
   - If it's the friend's iPhone: the friend must agree, and the data it collects is
     **test data**. Write down its anonymous ID from the status screen, so its rows can be
     excluded or deleted later.
7. **Register the iOS app in Firebase** (console → project `qoesense` → ⚙️ Project settings →
   Add app → iOS):
   - bundle ID `io.github.kouotou.qoesense`;
   - nickname `QoESense Flutter iOS`;
   - App Store ID left empty.

   Download `GoogleService-Info.plist` to `~/Downloads`. Claude copies the values from it.

## 6. Before leaving the Mac (do not skip)

Everything that needs a Mac must be finished, or written down, before returning it.

- [x] `./tool/verify.sh` passes, **including the iOS build**: `SKIP_ANDROID=1 ./tool/verify.sh`,
      "All checks passed" on 2026-11-10, with the Firebase iOS options in place.
- [x] The app was built, installed and run on the iPhone, and validation §3.8 is done or its
      results are recorded (§7; the open items are listed there).
- [x] `lib/firebase_options.dart` has the iOS values. The plist isn't in the repo.
- [x] §7 below is filled in: what was done, what wasn't, and what will need a Mac again.
- [x] Everything is committed and pushed: `git push -u origin phase4/ios`. The branch was
      checked on GitHub (API: `phase4/ios` → the latest commit).
- [ ] Optional, for later iOS testing without the Mac: create the app in App Store Connect
      and upload one TestFlight build (Xcode → Product → Archive → Distribute). That needs
      a privacy policy URL and an export-compliance answer. Ask the owner first.
      **Not done:** this session signs with a free Personal Team, and TestFlight needs a paid
      Apple Developer Program membership.
- [ ] **Cleanup on the friend's Mac** (the owner does this last; the steps are in
      `docs/PHASE4_MAC_SESSION_SUMMARY.md` §9):
  - `claude` → `/logout`;
  - remove the GitHub token from Keychain Access (search "github.com") and **revoke it** on github.com;
  - Xcode → Settings → Accounts → remove the Apple ID;
  - delete `~/dev/QoESense-CrossPlatform`, only after the push is confirmed on GitHub.
- [ ] On the iPhone: either leave the app installed for longer testing, with the friend's
      agreement, or delete it. The free-team install stops opening around 2026-11-16 (7 days).

## 7. Phase 4 results (Mac session: fill this in before leaving)

- Date(s): 2026-11-09 and 2026-11-10.
- Branch / last commit: `phase4/ios` (see `git log`).
- Toolchain: Xcode 27.2 (iOS 27.2 SDK, iOS 26.4 simulator), Flutter 3.47.9 in `~/dev/flutter`
  (the Homebrew Flutter on PATH is 3.41.9, too old). The first Flutter download was truncated;
  it was resumed and checked against Google's MD5.
- iOS build compiles: **yes**. It is the first compile ever of the Swift side. `flutter build ios
  --debug --no-codesign` and 24 XCTests on the simulator pass, as does `flutter test`.
- What was built: everything in [PHASE4_IOS.md](PHASE4_IOS.md):
  - the iOS capture;
  - the headless collector engine;
  - background location keep-alive and relaunch;
  - in-loop and BGTask uploads;
  - the actionable-notification survey and in-app sheet;
  - iOS onboarding;
  - the capability matrix.
- Run on device (model, iOS version): **yes**. iPhone15,3 (iPhone 14 Pro Max, a friend's phone,
  test data only), iOS 26. Release build, signed with the Personal Team `5LDC75A843` (free
  Apple ID: the install expires after 7 days).
- Validated on the device, 2026-11-09:
  - PHASE4_IOS §8 #1, onboarding: passed. When-In-Use, then Always, then notifications were
    granted, and collection is on.
  - #2, capability screen: passed. Radio, CQI, physical channel, app in use and survey overlay
    show "Not possible"; network type, connection, throughput, call detection, location,
    background location and notifications show "Available".
  - Samples are buffered (3 within the first minutes). The test survey notification was posted.
  - 2026-11-10, after Firebase iOS registration: a new release build installed over the old one
    kept the buffer (926 samples). Status shows anonymous ID **`UD1DfRM9K9Wow7GaL8BrGfbSFiG2`**,
    so **Firebase Auth sign-in works on iOS**, and "Upload now" is enabled. **This is the
    friend's test phone: every row and rating under this UID is test data**, to exclude or
    delete (§5 step 6). Uploads may still fail until billing is fixed; the rows then stay
    buffered.
  - **Unplugged run, 2026-11-09 22:34 → 2026-11-10 20:52** (container downloaded with
    `devicectl device copy from`; analysis script in the session scratchpad):
    - 922 samples, all `IOS_RAT` / `IOS`, all radio, CQI, physical channel and foreground-app
      groups `NOT_SUPPORTED`. No radio value or roaming flag appears anywhere.
    - **Cadence:** 779 gaps of 55–65 s at rest and 115 gaps of 14–17 s in calls. The few
      70 s gaps are a tick whose location wait took ~10 s: `timestampMs` is when the capture
      completed, while the ticks still start 60 s apart.
    - **Background continuity:** from 08:17 to 20:52 (12.6 h of normal use) no gap exceeds
      70 s. #4 passed, and longer than the 1 h asked.
    - **Two restarts**, each marked by `throughputStatus = UNAVAILABLE` on its first row:
      - 23:25 → 23:30 (5.7 min, right after the airplane-mode test);
      - 23:48 → 08:17 (8.5 h overnight).
      The tester confirmed both: they swiped the app away in the app switcher, and they
      reopened it themselves each time (23:30 and 08:17). No restart came from iOS. A force-quit
      stops collection until the app is reopened, as documented.
      **#9 is inconclusive:** the phone presumably didn't move ~500 m overnight before being
      reopened, so the significant-change relaunch after a force-quit wasn't exercised. Repeat
      it: swipe the app away, then travel more than 1 km without opening it.
    - **#5, calls:** CallKit calls switch to the 15 s cadence (median 15.0 s), e.g. 36 samples
      over 15:18–15:27. Cellular calls coincide with `networkType` LTE → OTHER, which is the
      carrier's circuit-switched fallback (no VoLTE).
    - **#6, transitions:** Wi-Fi → none (airplane) → cellular → Wi-Fi are all recorded.
      `UNKNOWN` appears 20:32–20:35 (no service). No NR was seen on this network.
    - **#3, measurements:**
      - location: 908 `OK` + 14 `STALE`, median accuracy 8.8 m;
      - RTT: 281 values, median 656 ms, 1 timeout and 1 failed probe;
      - throughput: non-zero (median 2.9 kB/s, max 904 kB/s), which settles the open question
        in the capability matrix: `getifaddrs` counters do work on device.
    - **#7, survey:** 2 in-app sheet answers were queued as `NOTIFICATION` + `SELF_REPORTED`
      ("something else"; Google Meet `VIDEO_CONFERENCING`). They are pending until Firebase.
      On 11-10 the daily cap (6) was reached by 10:18, and none of those prompts were answered.
      No notification-action answer is recorded yet.
    - **#12, storage:** hourly upload attempts ran (last 20:18), and the unconfigured backend
      deleted nothing. All 922 rows were still buffered.
    - **Finding for the owner:** the proposed `ratDowngrade` rule fires on every cellular call
      (circuit-switched fallback), and `POST_SESSION` follows every short call, so the 6-a-day
      cap fills by mid-morning. Proposal: ignore RAT changes while a call is active
      (PHASE4_IOS §6).
- Not done / known issues:
  - the Android build isn't confirmed after the Pigeon change (the Mac SDK lacks `android-37`);
    run `tool\verify.ps1` on Windows before merging `phase4/ios`;
  - the iOS consent and permission texts are drafts waiting for the owner;
  - the iOS anomaly rules are proposed, not approved. The device run showed `ratDowngrade`
    firing on every cellular call; the proposed fix is to ignore RAT changes during a call;
  - device checks not done:
    - #7, an answer through the notification buttons (only in-app sheet answers so far);
    - #9, relaunch after a force-quit with a move of more than 1 km;
    - #10, a reboot;
    - #11, permission revoked;
    - #13, battery;
  - the first real upload: it depends on Firebase billing, which wasn't observed. Check that
    `Last upload` changes, or that rows appear in BigQuery under the test UID;
  - an unfinished simulator smoke test (`integration_test/`) was dropped, not committed.
- Things that will need a Mac again:
  - **any Swift / Xcode change** (ios/Runner), and checking that it compiles;
  - **reinstalling on an iPhone.** The free Personal Team install expires after 7 days
    (around 2026-11-16), and each new build needs a Mac to sign and install it;
  - **reading the phone's on-device buffer** (`xcrun devicectl device copy from …`). Once
    uploads work, BigQuery shows the data without a Mac;
  - the device checks above that need a new build or a data download (#9, #10 and #13 can
    run on the installed app, but their analysis needs the container or uploads);
  - a TestFlight or App Store build, which also needs the paid Developer Program.
  With TestFlight, later iOS testing would no longer need a Mac.
- Firebase iOS registered: **yes**, on 2026-11-10 from the Windows PC (app ID
  `1:412391455735:ios:6aeb22d05ae939d991ccf2`). The values are in `QoESenseFirebaseOptions.ios`.
  No `GoogleService-Info.plist` exists on this Mac or in the repo.

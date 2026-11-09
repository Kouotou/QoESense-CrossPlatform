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
./tool/verify.sh                      # format, codegen, analyze, tests, Android APK, iOS build (no signing)
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

- [ ] `./tool/verify.sh` passes, **including the iOS build**.
- [ ] The app was built, installed and run on the iPhone, and validation §3.8 is done or its
      results are recorded.
- [ ] `lib/firebase_options.dart` has the iOS values. The plist isn't in the repo.
- [ ] §7 below is filled in: what was done, what wasn't, and what will need a Mac again.
- [ ] Everything is committed and pushed: `git push -u origin phase4/ios`. Then check the
      branch on github.com.
- [ ] Optional, for later iOS testing without the Mac: create the app in App Store Connect
      and upload one TestFlight build (Xcode → Product → Archive → Distribute). That needs
      a privacy policy URL and an export-compliance answer. Ask the owner first.
- [ ] **Cleanup on the friend's Mac:**
  - `claude` → `/logout`;
  - remove the GitHub token from Keychain Access (search "github.com") and **revoke it** on github.com;
  - Xcode → Settings → Accounts → remove the Apple ID;
  - delete `~/dev/QoESense-CrossPlatform`, only after the push is confirmed on GitHub.
- [ ] On the iPhone: either leave the app installed for longer testing, with the friend's
      agreement, or delete it.

## 7. Phase 4 results (Mac session: fill this in before leaving)

- Date(s):
- Branch / last commit:
- iOS build compiles: yes / no
- Run on device (model, iOS version):
- Validated:
- Not done / known issues:
- Things that will need a Mac again:
- Firebase iOS registered: yes / no

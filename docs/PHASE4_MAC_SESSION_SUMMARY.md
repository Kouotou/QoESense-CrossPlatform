# Phase 4 Mac session: summary

**Written:** 2026-11-10, at the end of the work on the borrowed Mac (Apple M1 Pro, Xcode 27.2).
**Branch:** `phase4/ios` on `Kouotou/QoESense-CrossPlatform`, pushed. It is **not merged** into `main`.
**Read this first when you're back on Windows.** The detail is in:
- [PHASE4_IOS.md](PHASE4_IOS.md): the iOS design, its differences from Android, and the device protocol;
- [IOS_CAPABILITY_MATRIX.md](IOS_CAPABILITY_MATRIX.md): what iOS can measure, field by field;
- [PHASE4_MAC_HANDOFF.md](PHASE4_MAC_HANDOFF.md) §7: the formal results record.

## 1. In short

The iOS app now exists and works:
- It runs the same Dart collector as Android, at the same 60 s / 15 s cadence. It records
  network type (LTE/5G/older), Wi-Fi vs cellular, throughput, latency, location and call
  state. It records no signal strength, cell ID, roaming or foreground app, because iOS
  doesn't allow those; they are null with status NOT_SUPPORTED.
- Ratings come from an actionable notification, or from an in-app sheet that also asks
  "what were you doing?".
- It ran for 22 h on a friend's iPhone 14 Pro Max (iOS 26). From 08:17 to 20:52 it collected
  in the background with no gap over 70 s, and calls switched to 15 s spacing.
- The iOS app is registered in Firebase, and anonymous sign-in works on the phone.
- Uploads still wait for Firebase billing.

## 2. Timeline

| When | What |
|---|---|
| 2026-11-09, evening | Project analysed. The Flutter 3.47.9 download was truncated (999 MB of 2.27 GB); resumed, checked against Google's MD5, unzipped to `~/dev/flutter`. Baseline `verify.sh` passed: 118 tests, analyze clean, codegen in sync. |
| 11-09 | Step 1: iOS API research against the iOS 27.2 SDK headers and Apple's docs → `IOS_CAPABILITY_MATRIX.md`. |
| 11-09 | Steps 2–3: Swift collector, survey, onboarding, Dart integration, tests, docs. **First compile ever of the Swift side.** `verify.sh`: all checks passed. |
| 11-09, 22:30 | Signed with the free Personal Team, installed a release build on the iPhone, onboarding done. Capability screen correct. |
| 11-09 22:34 → 11-10 20:52 | Unplugged run: 922 samples (results in §5). |
| 11-10, evening | Data copied off the phone. iOS Firebase options added, `verify.sh` passed, new build installed (buffer kept). Anonymous ID shown. Committed and pushed `phase4/ios`. |

## 3. What was built

**Swift** (`ios/Runner/`; every new file is registered in `project.pbxproj`):

| File | Role |
|---|---|
| `IosCollectorHost.swift` | The counterpart of the Android service. It starts a **headless Flutter engine** running the shared `collectorMain`; keeps the app alive with background location; relaunches it on significant location changes; schedules the BGTask upload fallback; implements `IosCollectorApi`. |
| `IosCapture.swift` | One capture per tick: RAT (`CTTelephonyNetworkInfo`), Wi-Fi/cellular (`NWPathMonitor`), throughput (`getifaddrs`, with 32-bit counter wrap handled), call state (`CXCallObserver`), device info. |
| `IosLocation.swift` | 3 km keep-alive updates, a 100 m one-shot fix per tick, native When-In-Use → Always prompts. |
| `IosSurvey.swift` | A notification with 5 rating buttons that work without opening the app; a durable answer queue; tapping the notification opens the in-app sheet. |
| `IOSCapabilityReporter.swift`, `AppDelegate.swift` | Updated. |
| `Info.plist`, `en.lproj`/`fr.lproj` `InfoPlist.strings`, `PrivacyInfo.xcprivacy` | Background modes (location, processing), BGTask id, EN/FR location purpose texts, privacy manifest. |
| `ios/RunnerTests/RunnerTests.swift` | 24 XCTests. |

**Dart:**
- `pigeons/telemetry_api.dart`: the new `IosCollectorApi` and `SurveyUiEvents`, and
  self-report fields on `SurveyAnswerMessage`.
- `lib/src/platform/ios_collector.dart`: iOS adapters. `main.dart` and `entrypoints.dart`
  choose the platform.
- `lib/src/application/`:
  - `path_anomaly_detector.dart`: the iOS ANOMALY rules;
  - `upload_gate.dart`: the hourly upload inside the iOS collector;
  - `self_report.dart`: the "what were you doing?" answers → Android package names (D-6).
- `lib/src/presentation/survey_sheet.dart`, plus iOS variants in `onboarding_screen.dart`,
  with new EN/FR strings in `lib/l10n/*.arb`.
- `lib/firebase_options.dart`: the iOS values, registered 2026-11-10. No plist is in the repo.
- Tests: 151 Dart tests, 33 new for iOS. `tool/verify.sh`: XCTest step, `SKIP_ANDROID=1`,
  executable bit. `tool/analyze_buffer.py`: summarises a buffer copied off a phone.

**Not changed:** the data contract (uploads stay **v1**), BigQuery, Cloud Functions, rules,
golden fixtures, and the app ID.

## 4. Decisions made during the session (please review)

Waiting for the owner:
1. **The iOS consent, welcome and permission texts (EN + FR) are drafts.** Approve them before
   any real iOS participant (`app_en.arb` / `app_fr.arb`, the `*Ios` keys).
2. **iOS ANOMALY rules (proposed):**
   - path lost;
   - Wi-Fi ↔ cellular;
   - LTE/NR → older RAT on cellular;
   - an RTT spike (≥ 2× the median and +200 ms);
   - 2 failed probes in a row.

   The device run found a problem: see §5.

My choices, which can be changed:
- On iOS a call counts once it's **connected**, not while it rings.
- Location: 3 km keep-alive plus a 100 m fix per tick. The blue background-location indicator
  is shown, as the counterpart of Android's notification.
- Uploads run every hour from the collector, only on a network that isn't expensive
  (cellular, hotspot) or constrained (Low Data Mode), and with Low Power Mode off. A
  BGProcessingTask is the fallback.
- Background modes: **location + processing** only. The handoff also listed "fetch"; it isn't
  used, and an unused mode is an App Review risk.
- iOS permissions are asked natively, not through permission_handler.
- Survey: a notification button gives `NOTIFICATION_ACTION` with context UNKNOWN; the sheet
  gives `NOTIFICATION` with an optional SELF_REPORTED context. There are 7 self-report options.
- The iOS display name changed from "Qoesense" to "QoESense".

## 5. What the iPhone run showed (2026-11-09 22:34 → 11-10 20:52)

**Device:** a friend's iPhone 14 Pro Max (iPhone15,3), iOS 26. The data was copied off the
phone with `devicectl`.

- **922 samples**, all `IOS_RAT`, with no radio value or roaming flag anywhere.
- **Cadence:** 779 gaps of ~60 s at rest and 115 of ~15 s in calls. For example, a call at
  15:18–15:27 gave 36 samples.
- **Background:** from 08:17 to 20:52 (12.6 h) no gap exceeds 70 s.
- **The two stops, 23:25 → 23:30 and 23:48 → 08:17,** happened because the tester swiped the
  app away, and they reopened it themselves both times. As documented, a force-quit stops
  collection until the app is reopened. Whether iOS relaunches it by itself after a move of
  more than 1 km wasn't tested.
- **Network changes were recorded.** Wi-Fi → airplane → cellular → Wi-Fi; no service at
  20:32–20:35. No 5G on this network.
- **Measurements:**
  - location: median accuracy 9 m;
  - latency: median 656 ms;
  - throughput works on the device. The research had flagged this as unverified.
- **Survey:**
  - 2 answers came from the sheet, with self-reports ("something else", Google Meet).
  - On 11-10 the **daily cap of 6 was reached by 10:18**, and none of those prompts were
    answered.
  - **Finding:** on this network every cellular call drops from LTE to 3G (circuit-switched
    fallback), and the proposed `ratDowngrade` rule fires on it. With POST_SESSION after each
    call, the cap fills in the morning. **Proposed fix:** ignore RAT changes while a call is
    active. It's a Dart-only change, so it can be done on Windows.
- **Firebase:** anonymous ID **`UD1DfRM9K9Wow7GaL8BrGfbSFiG2`**. This is the friend's phone, so
  every row and rating under this UID is **test data** to exclude or delete.
- **Uploads:** attempted every hour. Nothing was deleted while uploads weren't set up. The
  first real upload, which depends on billing, hasn't been observed yet.

## 6. Next steps on Windows

1. **Confirm the Android build:**
   ```powershell
   git fetch; git checkout phase4/ios
   powershell -ExecutionPolicy Bypass -File tool\verify.ps1
   ```
   The Pigeon change regenerated `TelemetryApi.g.kt`. The change is additive and should
   compile, but this Mac couldn't build the APK: its Android SDK only has `android-37.0`.
2. **Quick re-test on the Android phone.** The shared Dart changed: entrypoints refactor,
   `drainBuffer`, the MOS self-report path. Install, check that samples arrive at 60 s, and
   send one test survey.
3. **Decide:**
   - approve the consent drafts;
   - the anomaly fix (ignore RAT changes during a call; I can implement it in Dart and test
     it on Windows);
   - whether to merge `phase4/ios` into `main`. A PR can be opened at
     https://github.com/Kouotou/QoESense-CrossPlatform/pull/new/phase4/ios
4. **Firebase billing.** Once fixed, check that uploads land: the iPhone's "Last upload"
   changes and BigQuery has rows under the test UID. Then the v2 functions deploy
   (DATA_CONTRACT §7) and switching `BatchSerializer.defaultVersion`.
5. **The next Mac session** (§8).

## 7. Open iPhone checks (PHASE4_IOS.md §8)

| # | Check | State |
|---|---|---|
| 1 | Onboarding | ✅ |
| 2 | Capability screen | ✅ |
| 3 | Capture values | ✅ (from the downloaded data) |
| 4 | Background ≥ 1 h | ✅ 12.6 h |
| 5 | Call cadence 15 s | ✅ |
| 6 | Network transitions | ✅ |
| 7 | Survey answers | 🟡 the in-app sheet works; a **notification-button answer** is still untested |
| 8 | Lock-screen answer | ⏳ |
| 9 | Relaunch after a force-quit and a move of more than 1 km | ⏳ (the stops so far were reopened by hand) |
| 10 | Reboot | ⏳ |
| 11 | Permission revoked | ⏳ |
| 12 | Storage, nothing deleted without an upload | ✅ |
| 13 | Battery over 24 h | ⏳ |

## 8. What needs a Mac again

- **Any Swift / Xcode change**, and checking that it compiles (`verify.sh` on macOS).
- **Installing on an iPhone.** The free Personal Team install **expires after 7 days (around
  2026-11-16)**, and every new build has to be signed and installed from a Mac.
- **Reading a phone's buffer** before uploads work: `devicectl … copy from`, then
  `python3 -I tool/analyze_buffer.py <dir>`.
- **TestFlight or the App Store.** This needs the paid Apple Developer Program
  ($99/year) and a Mac for the first upload. After that, testers install over the air with no
  Mac.

Dart-only changes, such as the anomaly-rule fix or texts, can be made and tested on Windows.
They only reach the iPhone after a Mac rebuild.

## 9. Cleanup on the friend's Mac and iPhone (do this last)

**Mac:**
1. Make sure the branch is on GitHub. It is: `phase4/ios`, checked through the GitHub API.
2. **Xcode → Settings → Accounts →** select the Apple ID → **−** to remove it.
3. **Keychain Access** (open it with Spotlight):
   - delete the certificate **"Apple Development: <your Apple ID>"** together with its private
     key;
   - search **github.com** and delete the saved GitHub login. If it was a personal access
     token, **revoke it** on github.com → Settings → Developer settings.
4. Delete the provisioning profile:
   `rm ~/Library/Developer/Xcode/UserData/Provisioning\ Profiles/fa5c4eba-*.mobileprovision`.
5. Claude Code: run `claude`, then `/logout`. To remove this session's history too, delete
   `~/.claude/projects/-Users-mac-dev-QoESense-CrossPlatform`.
6. Free the disk space:
   - `~/dev/QoESense-CrossPlatform` (the project, including `build/`);
   - `~/dev/flutter` (3.9 GB) and `~/dev/flutter_macos_arm64_3.47.9-stable.zip` (2.1 GB);
   - in `~/Library/Developer/Xcode/DerivedData`, only the `Runner-*` folders. The rest may be
     your friend's.
   The pub, Gradle and SwiftPM caches can stay.
7. Optional: during the first build, Gradle added Android SDK Build-Tools 36.0.0 and Platform
   37.0 to the Mac's Android SDK (`~/Library/Android/sdk`). They are harmless; ask your
   friend whether to keep them.
8. The iPhone 17 simulator has a test copy of the app. Remove it with
   `xcrun simctl uninstall booted io.github.kouotou.qoesense`, or leave it.

**iPhone (your friend's):**
1. Agree with your friend: keep the app for more tests (it stops opening around 11-16) or
   delete it (long-press the icon → Remove App).
2. If you delete it, also:
   - **Settings → General → VPN & Device Management** → the developer profile → Delete;
   - **Settings → Privacy & Security → Developer Mode** → off, if your friend didn't use it
     before.
3. The data it recorded is test data under UID `UD1DfRM9K9Wow7GaL8BrGfbSFiG2`.

## 10. Reference

| Item | Value |
|---|---|
| Bundle / app ID | `io.github.kouotou.qoesense` |
| Firebase iOS app ID | `1:412391455735:ios:6aeb22d05ae939d991ccf2` (project `qoesense`) |
| Apple signing team | Personal Team `5LDC75A843` (your free Apple ID). It is saved in `project.pbxproj`; choose another team in Xcode on another account |
| Test iPhone | iPhone 14 Pro Max (iPhone15,3), iOS 26 (a friend's phone). Get its UDID with `xcrun devicectl list devices` |
| Test UID | `UD1DfRM9K9Wow7GaL8BrGfbSFiG2` (test data) |
| Flutter / Xcode | Flutter 3.47.9 (Dart 3.13.7) / Xcode 27.2, iOS 27.2 SDK |
| Mac commands | `export PATH="$HOME/dev/flutter/bin:$PATH"`; `SKIP_ANDROID=1 ./tool/verify.sh`; `flutter build ios --release`; `xcrun devicectl device install app --device <udid> build/ios/iphoneos/Runner.app` |

**Problems hit on the Mac, and their fixes:**
- **A truncated Flutter download** was resumed with `curl -C -` and checked with MD5.
- **The first signed build hung for 30 min** on a hidden keychain prompt. Enter the Mac
  password and choose **Always Allow**, then rebuild.
- **Debug builds** don't open from the home screen without the Mac attached, so use
  **release** builds for device tests.
- **"Untrusted Developer"** on a free team: Settings → General → VPN & Device Management →
  Trust.
- **devicectl error 4016** means the phone is locked; keep it unlocked while copying.

# Dependencies

Each dependency must have a reason to be here. Versions are pinned in `pubspec.lock`, which
is committed. Nothing here is a new backend or cloud provider.

## Toolchain

| Tool | Version | Where | Notes |
|---|---|---|---|
| Flutter (stable) | 3.47.9 (Dart 3.13.7) | `C:\Users\Ahmad\flutter` (Windows); CI pins the same | Not on PATH on Windows; `tool/verify.ps1` uses the full path |
| JDK | Android Studio's bundled JBR 17+ | `C:\Program Files\Android\Android Studio\jbr` | Same workaround as the reference app (auto-discovery picks a broken VS Code JRE) |
| Android SDK | from Android Studio | `%LOCALAPPDATA%\Android\sdk` | compile/target SDK set by the Flutter Gradle plugin |
| Xcode + CocoaPods-free SwiftPM | latest stable | **Mac only**; also used by the CI `ios` job | Flutter 3.47 uses Swift Package Manager for plugins, so CocoaPods isn't needed |
| GitHub Actions | `subosito/flutter-action@v2`, `actions/setup-java@v4` | CI | |

## Phase 1, in use now

| Package | Kind | Why |
|---|---|---|
| `flutter`, `flutter_localizations` (SDK) | runtime | UI, and the English and French strings carried over from the reference app |
| `intl` ^0.20.3 | runtime | Required by `flutter gen-l10n` |
| `flutter_test` (SDK) | dev | Unit, widget and contract tests |
| `flutter_lints` ^6.0.0 | dev | Lint baseline. `analysis_options.yaml` makes it stricter. |
| `pigeon` ^29.1.1 | dev, codegen | Type-safe Dart ↔ Kotlin/Swift channel (ARCHITECTURE §3) |
| `org.jetbrains.kotlinx:kotlinx-coroutines-android` 1.10.2 | Android native | Pigeon 29 generates `suspend` host APIs |

## Planned (not added yet: each comes with the phase that uses it)

| Package | Phase | Purpose | Replaces in the reference app |
|---|---|---|---|
| `firebase_core`, `firebase_auth` | 2 | Anonymous identity, against the **existing** `qoesense` project | Firebase Android SDK Auth |
| `cloud_firestore` | 2 | MOS ratings and the consent record | Firestore Android SDK |
| `firebase_storage` | 4 | Telemetry batch upload | Storage Android SDK |
| `drift` + `sqlite3` (+ `drift_dev`, `build_runner` dev) | 2 | Durable offline buffer with tested migrations, usable from several isolates | Room v1 |
| `shared_preferences` or drift tables | 2 | Onboarding, consent and survey bookkeeping | DataStore |
| `permission_handler` | 2 | One cross-platform permission flow. Usage access and overlay stay native, since the plugin can't grant them. | hand-rolled Android flow |
| `workmanager` *or* native WorkManager + headless engine | 3/4 | Hourly Wi-Fi-only upload. Native is preferred, to keep the reference's exact constraints. | WorkManager |
| iOS frameworks: CoreLocation, CoreTelephony, CallKit (`CXCallObserver`), Network (`NWPathMonitor`), BackgroundTasks, UserNotifications | 3 | iOS adapters. These are Apple system frameworks, not third-party packages. | n/a |
| Android: `play-services-location` | 3 | Fused location, as in the reference | same |

**Explicitly excluded:** FastAPI, PostgreSQL, any non-Google cloud, and any replacement
warehouse. Analytics/ads SDKs are also excluded: no third-party tracking in a research app
that promises anonymity.

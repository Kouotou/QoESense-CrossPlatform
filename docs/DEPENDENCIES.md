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

## Phase 3, in use now

| Package | Why |
|---|---|
| `drift` ^2.35, `drift_flutter` ^0.3 (+ `drift_dev`, `build_runner` dev) | SQLite buffer, pending-MOS queue and settings, shared by the UI and the headless engines (WAL) |
| `path_provider` | Database location (used by drift_flutter) |
| `firebase_core` ^5.1, `firebase_auth` ^7.0, `firebase_storage` ^14.0, `cloud_firestore` ^7.1 | The existing `qoesense` project; inactive until `lib/firebase_options.dart` is filled in after registration |
| `permission_handler` ^13.0 | Runtime permissions (location, phone, background location, notifications). Usage access, overlay and battery stay native intents. Needs compileSdk 37. |
| Android: `androidx.core:core-ktx` 1.19.0, `androidx.work:work-runtime-ktx` 2.11.2, `play-services-location` 21.4.0 | The same versions as the reference app |

## Phase 4 (iOS), in use now

| Package / framework | Why |
|---|---|
| iOS frameworks: CoreLocation, CoreTelephony, CallKit (`CXCallObserver`), Network (`NWPathMonitor`), BackgroundTasks, UserNotifications | The iOS collector (docs/PHASE4_IOS.md). System frameworks only; no new pods or packages |

On iOS, permission prompts are native (`IosCollectorApi`), not `permission_handler`, which is
still compiled in but asks for nothing there, so it needs no Podfile macros.

## Planned (not added yet: each comes with the phase that uses it)

| Package | Phase | Purpose | Replaces in the reference app |
|---|---|---|---|
| `shared_preferences` or drift tables | 2 | Onboarding, consent and survey bookkeeping | DataStore |
| `workmanager` *or* native WorkManager + headless engine | 3/4 | Hourly Wi-Fi-only upload. Native is preferred, to keep the reference's exact constraints. | WorkManager |
| iOS frameworks: CoreLocation, CoreTelephony, CallKit (`CXCallObserver`), Network (`NWPathMonitor`), BackgroundTasks, UserNotifications | 3 | iOS adapters. These are Apple system frameworks, not third-party packages. | n/a |
| Android: `play-services-location` | 3 | Fused location, as in the reference | same |

**Explicitly excluded:** FastAPI, PostgreSQL, any non-Google cloud, and any replacement
warehouse. Analytics/ads SDKs are also excluded: no third-party tracking in a research app
that promises anonymity.

# QoESense cross-platform (Flutter)

This is the Flutter port of `../QoESense`, the native Android **reference app**. Never modify
the reference from here. Read `docs/ARCHITECTURE.md` and `docs/DATA_CONTRACT.md` before
changing any model, serializer or channel.

## Commands (Windows)

- Flutter is at `C:\Users\Ahmad\flutter\bin` and is **not on PATH**.
- Set `JAVA_HOME=C:/Program Files/Android/Android Studio/jbr` for Android builds.
- Run everything with `powershell -ExecutionPolicy Bypass -File tool\verify.ps1`. That covers
  format, codegen, analyze, test and the APK build.
- After editing `pigeons/telemetry_api.dart`, run `dart run pigeon --input pigeons/telemetry_api.dart`.
- After editing `lib/l10n/*.arb`, run `flutter gen-l10n`.
- Swift can't be compiled on Windows. Only the CI `ios` job or a Mac proves it builds.
- A new Swift file must also be added to `ios/Runner.xcodeproj/project.pbxproj`, because the
  project doesn't use synchronized folders.

## Non-negotiables

- Sampling is **60 s at rest / 15 s in a video call**. Older prompts and the handbook say
  20 s / 5 s; ignore them.
- Backend is the existing Firebase/GCP `qoesense` project only.
- No BigQuery schema or cloud-resource changes. Contract changes follow DATA_CONTRACT §6.
- `BatchSerializer.defaultEmitPlatformField` stays `false` until the functions deployment is
  confirmed. As of 2026-11-07 the deploy is blocked by billing.
- No secrets in this repo: no keystores, no `keystore.properties`, no reference
  `google-services.json`. `test/architecture/layering_test.dart` enforces this.
- `domain/` and `application/` stay pure Dart, which is also enforced by a test.
- iOS fields without a public API are null, never estimated.
- Placeholder app ID `org.qoesense.xplat.qoesense` stays until decision D-2.

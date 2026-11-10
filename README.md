# QoESense cross-platform

This is the Flutter (Android + iOS) version of the QoESense passive QoE telemetry collector,
an MSc research project.

The native Android app in `../QoESense` is the **verified reference implementation**. This
project reuses its research rules and its Firebase/GCP backend unchanged, and replaces the
reference app on participants' phones through a side-by-side handover (D-1, ARCHITECTURE §9.1).

**Status (2026-11-09):** Android collects on the device (Phase 3, validated on a phone). iOS
is code complete on branch `phase4/ios` (Phase 4: compiles, unit tests green, 22 h on an iPhone;
see docs/PHASE4_MAC_SESSION_SUMMARY.md). Uploads wait for Firebase billing.

## Documents

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): layers, the Flutter ↔ Kotlin/Swift channel,
  Android and iOS background strategy, backend integration, open decisions, phases
- [docs/MIGRATION_MATRIX.md](docs/MIGRATION_MATRIX.md): every reference requirement, where it
  lives, and its iOS parity
- [docs/DATA_CONTRACT.md](docs/DATA_CONTRACT.md): the frozen wire contract with the backend
- [docs/DEPENDENCIES.md](docs/DEPENDENCIES.md): what each dependency is for
- [docs/PHASE3_ANDROID.md](docs/PHASE3_ANDROID.md): the Android collector and its device protocol
- [docs/PHASE4_IOS.md](docs/PHASE4_IOS.md): the iOS collector, its differences from Android, and its device protocol
- [docs/IOS_CAPABILITY_MATRIX.md](docs/IOS_CAPABILITY_MATRIX.md): what iOS can and can't measure, per field
- [docs/PHASE4_MAC_SESSION_SUMMARY.md](docs/PHASE4_MAC_SESSION_SUMMARY.md): what happened on the Mac, what is open, what needs a Mac again

## Layout

```
lib/src/domain/        pure Dart models + wire enums
lib/src/application/   research rules (sampling, survey triggers, anomaly, tier, upload drain)
lib/src/data/          ports + implementations: local buffer, batch serializer, backend ports
lib/src/platform/      Pigeon-generated channel + adapters
lib/src/presentation/  Flutter UI
lib/l10n/              en + fr strings (generated code in lib/l10n/generated)
pigeons/               channel definition (source of truth for the generated code)
contracts/             BigQuery schemas exported from ../QoESense/functions/index.js + golden NDJSON
android/               Kotlin: AndroidCapabilityReporter (+ Phase 3 adapters/service)
ios/                   Swift:  IOSCapabilityReporter + Phase 4 collector host, capture, location, survey
test/                  unit, widget, contract and architecture tests
tool/verify.ps1|.sh    local equivalent of CI
```

## Verify

Windows:
```powershell
cd C:\Users\Ahmad\AndroidStudioProjects\QoESense-CrossPlatform
powershell -ExecutionPolicy Bypass -File tool\verify.ps1
```
On a Mac: `./tool/verify.sh`. That script also compiles the Swift code and runs the XCTests.

## Rules that must not drift

- Sampling: **60 s at rest / 15 s during a video call.** The handbook's 20 s / 5 s is superseded.
- MOS: 1–5. Triggers: PERIODIC 2 h / POST_SESSION 15 min / ANOMALY 10 min. Cap: 6 per local day.
- A row is deleted from the buffer only after a confirmed upload. Drain first, then retention (45 days).
- Telemetry batches stay on contract **v1** until the v2 functions are deployed. v2 adds `platform`,
  per-field status and quality metadata (docs/DATA_CONTRACT.md).
- No secrets in this repo. The reference keystore and `google-services.json` are never copied here.

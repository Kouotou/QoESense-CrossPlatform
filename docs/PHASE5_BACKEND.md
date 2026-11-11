# Phase 5: Firebase/GCP compatibility

**Status (2026-11-11):** the analysis, the tests and the proposed changes are complete.
**Nothing in production has been changed:** no deploy, no rules change, no IAM change, no
schema change, no data written or deleted. Every production step in §6 waits for the
owner's approval.

**Code:**
- reference repo `Kouotou/QoESense`, branch **`backend/phase5-compat`** (`b2052d8`): functions,
  tests, proposed rules and the backfill tool;
- this repo: this document.

## 1. Live inspection (all read-only, 2026-11-11)

| Item | Finding |
|---|---|
| Billing | **`billingEnabled: false`** (account `010BC4-320E08-598199` attached). Cloud Functions and Cloud Storage writes don't work. Auth and Firestore do. |
| Deployed functions | `loadTelemetryBatch` and `exportMosResponse`: v2, africa-south1, nodejs22. **This is the version from commit `63debb0`**, without `platform` or contract v2. |
| `qoesense_telemetry.samples` | 28 columns, **6,798 rows, the last on 2026-09-03**, from 5 devices, none of them the new app |
| `qoesense_telemetry.mos_responses` | 9 columns, **10 rows, the last on 2026-09-02** |
| Firestore `mosResponses` | **68 ratings**, so 58 never reached BigQuery: the export trigger couldn't run, and Firestore doesn't replay triggers. That breaks down as 61 from the reference app and 7 from the new app (4 from the Android test phone, 3 from the iPhone test). |
| Storage `telemetry/` | 172 batch files from 5 reference-app devices, **the last on 2026-09-03**. The new app has never completed an upload; its data is still in the phones' buffers, which is the intended fail-closed behaviour. |
| Production logs (deployed code) | Contain raw participant UIDs, in every load and export log line |

## 2. Identity strategy

| Concept | What it is | Where | Rule |
|---|---|---|---|
| **Installation identity** | The Firebase anonymous Auth UID of one install of one app on one device | `deviceId` in every row, path segment `{uid}` | It's the only identity used for joins and access control. It's never derived from the device, and **never merged across installs or platforms**. |
| Platform | `ANDROID` / `IOS` | `platform` (v2); for v1 rows, `COALESCE(platform, IF(tier='IOS_RAT','IOS','ANDROID'))` | One person's Android and iOS installs are always two `deviceId`s with two platforms, so their data can't collide |
| Reinstall | A new install gets a new UID on Android. On iOS, Firebase Auth keeps its session in the Keychain, which *can* survive a reinstall, keeping the same UID. | | Neither behaviour is relied on. A reused iOS UID simply continues the same installation's lineage. |
| **Research participant identity** (proposed, optional) | A researcher-issued enrolment code (e.g. `P017`) that the participant types after consent | Firestore `devices/{uid}.participantCode` only, never in telemetry rows | It **links** installations (Android + iOS, or a reinstall) for analysis through a mapping, **without merging rows**. Format `^P[0-9]{3,4}$`, so no names, phones or emails. Needs a consent-text change, a rules change and owner approval (P7). Not implemented. |
| Test installations | Devices used for development | Excluded from analyses | iOS test UID `UD1DfRM9K9Wow7GaL8BrGfbSFiG2`. The Android test phone's UID starts with `0y5ZtaFlJb` (full ID on its status screen). |

**The join is unchanged:** `mos_responses.deviceId = samples.deviceId` and
`samples.timestampMs BETWEEN windowStartMs AND windowEndMs`. Because it's per installation,
it can never pair one platform's rating with another platform's telemetry.

## 3. Compatibility findings

| # | Requirement | Result | Evidence |
|---|---|---|---|
| 1 | iOS rows ingest without the Android radio fields | ✅ **already, with the deployed functions** (v1 format): radio fields NULL, `cqiSupported=false`, tier `IOS_RAT` | functions test 1 |
| 2 | v2 metadata reaches BigQuery only through the approved plan | ✅ The deployed functions **reject a v2 batch as a whole**, so clients stay on v1 (`BatchSerializer.defaultVersion`) until P2 | functions tests 2, 4 |
| 3 | Additive schema evolution | ✅ The proposed functions reconcile a production-shaped table: **+21 sample columns** (incl. REPEATED `capabilitySet`) and **+9 MOS columns**, with v1 columns unchanged and in the same order, and existing rows untouched | functions tests 5, 10 |
| 4 | Old clients keep working after the deploy | ✅ v1 Android and iOS lines and v1 MOS documents load unchanged under the proposed functions | functions tests 6, 10 |
| 5 | Batch atomicity | ✅ A batch with one bad line is rejected whole, and nothing is half-loaded | functions test 8 |
| 6 | Upload batching, retry, keeping data until confirmed | ✅ Client side, unchanged: delete only after a confirmed `putData`; 20 × 2,000 rows per run; drain-then-retain (45 d). Tested in the app's 153 tests. |  |
| 7 | Idempotency | 🟡 **MOS:** idempotent (`set` on the tap-time UUID; `onDocumentCreated` fires once). **Batches:** a retry after a lost acknowledgement uploads a new object, and the same file finalized twice loads twice. That's the same as the reference app, and it's why the dedup view (P5) and create-only rules (P4) are proposed. | functions test 13 |
| 8 | Security rules | 🟡 **Current rules work for both apps.** Ownership is correct, but they allow out-of-range scores, deleting ratings, and overwriting or deleting batches. The proposed rules close these gaps without breaking either app. | rules tests 1–16 |
| 9 | Consent records | ✅ Both apps merge only `{consentGivenAtMs}` into `devices/{uid}`. The proposed rules allow exactly that field. | rules tests 3, 14 |
| 10 | No personal data in logs | ✅ Client: no location, UID or credentials logged (Dart, Kotlin and Swift scanned). ❌ Deployed functions log raw UIDs; the proposed functions log a short hash instead (`uid#2bec8083`). | functions test 12 |
| 11 | Backend unchanged in kind | ✅ Firebase/GCP only: no FastAPI, no PostgreSQL, no new provider | |

## 4. Test evidence

**A. The real function code vs synthetic Android and iOS payloads** (`functions/`, `npm test`)
- In-memory BigQuery and Storage enforce the load-job rules: unknown key → the whole job
  fails; REQUIRED fields must be present; types must match; a load schema can't exceed
  the table.
- Three code versions are tested: deployed (`63debb0`), main, and proposed.
- **13/13 pass.**

```
✔ deployed (production today): Android + iOS v1 batches load - iOS radio fields simply NULL
✔ deployed: a v2 batch is rejected as a whole (unknown fields) - why clients stay on v1 until the deploy
✔ deployed: a v2 MOS document is exported with its 9 known columns; the extra fields are ignored
✔ main (never deployed): adds `platform` to a live table; v1 still loads, v2 still rejected
✔ proposed: reconciles a production-shaped table additively (+21 columns, REPEATED allowed, old rows untouched)
✔ proposed: old clients keep working - v1 Android and iOS lines load after the v2 deploy
✔ proposed: v2 Android + iOS batches load, with statuses, capabilitySet arrays and no iOS radio values
✔ proposed: a batch with a broken line is rejected as a whole (REQUIRED field missing) - nothing half-loaded
✔ all versions ignore objects outside telemetry/ or not .json.gz
✔ proposed MOS: v1 documents export unchanged; v2 documents export all 18 columns
✔ proposed MOS: null optional fields are omitted, not inserted as explicit NULL
✔ privacy: proposed logs never contain a raw participant UID (deployed logs do)
✔ characterisation: the same batch file finalized twice loads twice (why a dedup view is proposed)
```

The payloads are this repo's golden fixtures, byte-identical copies:
- `batch_v1.ndjson`: Android CQI_29 + iOS IOS_RAT;
- `samples_v2.ndjson`: Android full, Android degraded/stale, iOS in a call, iOS on Wi-Fi;
- `mos_v2.ndjson`: Android overlay, iOS self-reported, iOS unknown context.

**B. Security rules on the local Firebase emulators** (`rules-tests/`, `npm test`)
- Project `demo-qoesense`; the demo- prefix keeps the emulators offline.
- **16/16 pass.**

```
CURRENT production rules
  ✔ owner can write a v1 (Android reference) and a v2 (iOS) rating
  ✔ another device or a signed-out client cannot
  ✔ consent merge works
  ✔ WEAKNESS: an out-of-range score and deleting a rating are both allowed today
  ✔ storage: owner can upload a batch, others cannot, nobody can read
  ✔ WEAKNESS: today an existing batch can be overwritten or deleted by its owner
PROPOSED rules
  ✔ every current client keeps working: v1 Android, v2 Android, v2 iOS ratings
  ✔ idempotent retry: re-sending the identical document is allowed
  ✔ a stored rating can't be changed or deleted
  ✔ invalid ratings are refused: score 0 or 6, unknown field, bad trigger, bad window
  ✔ ownership unchanged: other devices and signed-out clients are refused
  ✔ consent record: the merge both apps do works; extra fields are refused
  ✔ storage: the real batch path uploads; wrong owner, bad name, overwrite, delete, read refused
  ✔ storage: an empty or oversized object is refused
```

The emulator found a real issue in the first draft: Storage evaluates an overwrite as a
*create*, so `allow update: if false` didn't stop it. The rule now requires `resource == null`.

**C. Client contract tests** (this repo, `tool\verify.ps1`)
- **153/153 pass:** v1 byte-for-byte; v2 vs the proposed schema; additive-only evolution;
  iOS records with legitimately unavailable radio fields.

**D. On-device evidence:**
- Android: a test rating went overlay → native queue → SQLite → **Firestore**, confirmed on
  2026-11-11.
- iOS: anonymous sign-in and ratings reached Firestore (3 docs).

**E. Backfill dry run against production** (read-only), `node tools/backfill_mos.js`:

```
Firestore ratings: 68; already in BigQuery: 10; missing: 58
missing per device (redacted): { uid#d2b9b736: 4, uid#2bec8083: 3, uid#ea08caaf: 17, uid#41a66c9c: 4, uid#43634d14: 30 }
Dry run - nothing written.
```

**Not testable without production or billing:** the real BigQuery load and streaming insert,
and the real Storage trigger. P0–P2 include verification steps for them.

## 5. What doesn't change

- Anonymous Auth.
- The Storage path `telemetry/{uid}/{yyyy-MM-dd}/{uuid}.json.gz`, gzipped NDJSON.
- Both trigger functions and their names, region and runtime.
- Both tables and every existing column.
- The join, and the 10-minute MOS window.
- Clients send v1 until P6.

## 6. Proposed production changes (each needs approval, in this order)

| Step | Change | Command / action | Verify | Rollback |
|---|---|---|---|---|
| **P0** | **Re-enable billing** (owner) | Cloud Console → Billing → link a working payment method | `gcloud billing projects describe qoesense` → `billingEnabled: True` | n/a |
| **P1** | Smoke test of the **current** pipeline before changing anything | Wait for the next hourly upload from the Android test phone (v1). It holds ~2,300 buffered rows. | New `telemetry/…` objects appear; `samples` gains rows with `appVersion='2.0.0'`; the phone's "Last upload" updates; its buffer shrinks | none needed; nothing changed |
| **P2** | Deploy the **proposed functions** (contract v2 + redacted logs) | Merge `backend/phase5-compat` into `main` in `QoESense`, then `cd functions && npx firebase-tools deploy --only functions --project qoesense` | `functions:list` shows a new update time. After the next upload, `bq show` reports **49** sample and **18** MOS columns, and v1 rows keep loading. | `git checkout 63debb0 -- functions/index.js && git checkout HEAD~ -- functions/schema.js`, then redeploy. The added nullable columns are harmless and stay; drop them only on request (`ALTER TABLE … DROP COLUMN`). |
| **P3** | **Backfill the 58 ratings** | `node tools/backfill_mos.js --apply`, after P2 | `mos_responses` = Firestore count (68+). A re-run inserts 0. | `DELETE FROM mos_responses WHERE responseId IN (…)`; the tool prints the list |
| **P4** | Deploy the **proposed rules** | Copy `rules-tests/*.proposed.rules` over `firestore.rules` / `storage.rules`, then `npx firebase-tools deploy --only firestore:rules,storage` | Re-run `rules-tests`, send one test rating and wait for one upload from each app | `git checkout HEAD~ -- firestore.rules storage.rules`, then redeploy. This takes seconds. |
| **P5** | Analysis **views** (new resources) | `samples_v`: dedup on (deviceId, timestampMs) + resolved platform + `COALESCE(schemaVersion,1)`; `mos_v`: dedup on responseId; test UIDs excluded. SQL in §7. | Row counts ≤ table counts; no duplicates | `DROP VIEW` |
| **P6** | Clients switch to **contract v2** | Set `BatchSerializer.defaultVersion = ContractVersion.v2`, rebuild Android (PC) and iOS (Mac) | The first v2 rows appear with `schemaVersion=2`, statuses and `capabilitySet` | Set it back to v1 and rebuild. v1 always loads; buffered rows re-serialize at upload time. |
| P7 | Optional: participant code (§2) | New onboarding step, Firestore field, rule, consent text | the owner decides | Remove the field and the step |

**Why this order:**
- P1 proves the existing path before anything changes.
- P2 must precede P6: deploy before send.
- P3 needs P2's columns.
- P4 comes after P2 and P3, so a rules problem can't hide a functions problem.

## 7. View SQL (P5, not created)

```sql
CREATE OR REPLACE VIEW `qoesense.qoesense_telemetry.samples_v` AS
SELECT * EXCEPT(rn),
  COALESCE(platform, IF(telemetryCapabilityTier = 'IOS_RAT', 'IOS', 'ANDROID')) AS platform_resolved,
  COALESCE(schemaVersion, 1) AS schema_version_resolved
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY deviceId, timestampMs ORDER BY deviceId) AS rn
  FROM `qoesense.qoesense_telemetry.samples`
  WHERE deviceId NOT IN ('UD1DfRM9K9Wow7GaL8BrGfbSFiG2' /* , Android test UID */)
)
WHERE rn = 1;

CREATE OR REPLACE VIEW `qoesense.qoesense_telemetry.mos_v` AS
SELECT * EXCEPT(rn) FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY responseId ORDER BY deviceId) AS rn
  FROM `qoesense.qoesense_telemetry.mos_responses`
  WHERE deviceId NOT IN ('UD1DfRM9K9Wow7GaL8BrGfbSFiG2')
) WHERE rn = 1;
```

## 8. Risks

| Risk | Mitigation |
|---|---|
| Billing comes back and ~2 months of buffered data arrives at once | The client drains 40,000 rows per hourly run; the load is per file. Expect a few hours of catch-up. |
| Rows older than 45 days were purged on the phones before billing returned | That's by design (retention runs after the drain). Reference-app phones have been buffering since September. Check them **before** P0 if that data matters. |
| A streaming insert right after a column is added briefly rejects that column | Optional MOS fields are sent only when present. A failed insert throws, so the platform retries the event. |
| Duplicate rows from upload retries | P5 views. A deterministic batch ID + create-only rules would remove most of them (future client change). |

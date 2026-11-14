# Free-tier migration: Firebase without billing

**Decision (owner, 2026-11-14):** keep Firebase, and use only the parts that work without
billing (no payment card). Neon and Supabase were considered and rejected:
- they would replace Firebase with PostgreSQL, which the project's own constraints forbid;
- they need a new sign-in system and a server in between;
- they mean a large rewrite on both apps;
- Supabase pauses free projects after 7 days of inactivity.

## 1. What changed

| Before (needs billing) | Now (free, no card) |
|---|---|
| Batches → **Cloud Storage** `telemetry/{uid}/{day}/{id}.json.gz` | Batches → **Firestore** `devices/{uid}/telemetryBatches/{id}`. The **same gzipped NDJSON bytes**, plus `batchId`, `day`, `objectPath`, `sizeBytes`, `createdAtMs`. |
| **Cloud Functions** load each batch / export each rating to BigQuery | **`QoESense/functions/tools/export_firestore.js`**, run on the PC. It's incremental and read-only, and writes `samples` / `mos_responses` as NDJSON + CSV in the exact BigQuery column layout, with duplicates removed. |
| **BigQuery** `qoesense_telemetry` tables, loaded automatically | The local files, or the **BigQuery sandbox** dataset `qoesense_free_export`, loaded with `bq load` (free; tables expire after 60 days, so reload from the files) |

**Unchanged:**
- anonymous sign-in;
- MOS ratings and consent (they were always in Firestore);
- the batch format, buffering, retries, the 20 × 2,000 drain, "delete only after a confirmed
  write" and the 45-day retention;
- the data contract (uploads stay v1);
- the security rules: the current production rules already allow these writes, and this is
  proven on the emulator.

**Switching back once billing works:** set `activeUploadTarget = UploadTarget.cloudStorage` in
`lib/src/data/backend/batch_document.dart`, rebuild, then follow PHASE5_BACKEND §6 (P1 onwards).
The batch bytes are identical either way.

## 2. Free limits vs this study

Firestore on Spark: 1 GiB stored, 20,000 writes/day, 50,000 reads/day.

| | Measured / estimated | Free limit |
|---|---|---|
| Size of a sample | **30–37 bytes** gzipped (measured on 2,244 real samples from the test phone) | |
| Storage, 3 months | ~5 MB per participant, so 100 participants ≈ 0.5 GB | 1 GiB |
| Writes per participant per day | ~24 batches + ≤ 6 ratings + consent | 20,000/day in total (≈ 600 participants) |
| Export reads | Each batch is read once (checkpoint per device) | 50,000/day |

**If a daily limit is ever hit:** writes are refused until the next day. The phones keep the
data and retry, and nothing is charged, because there's no card.

## 3. Evidence

**Client** (this repo, branch `free-tier/firestore-uploads`):
- 157 tests pass, including `test/data/batch_document_test.dart`. The document holds the
  same bytes as the Storage path; non-batch paths are refused; a full 2,000-row batch is
  smaller than a tenth of the document limit.

**Rules** (`QoESense/rules-tests`, emulators): 18/18.
- "FREE-TIER UPLOADS need no rules change: the owner can already write telemetryBatches;
  others can't".
- The proposed tightened rules also cover batches: create-once with identical retry, shape
  and size checks.

**Exporter** (`QoESense/functions`, `npm test`): 16/16.
- Batches decode into rows that fit the BigQuery schema.
- A retried batch is exported once.
- The CSV format is checked.

**Real run against production** (read-only), 2026-11-14:
```
exported 0 new samples from 0 batches (0 duplicates skipped), 72 new ratings; ~72 Firestore reads
```

**BigQuery sandbox:**
- A load of the 72 ratings into `qoesense_free_export.mos_responses` succeeded, free of charge.
- Query: ANDROID 4, IOS 3, legacy (NULL) 65.
- The table expires on 2027-01-13: the sandbox's 60 days.

**Backup** before any change: `C:\Users\Ahmad\QoESense-backups\2026-11-14`. It holds the
BigQuery tables (6,798 samples, 10 ratings) and all 79 Firestore documents. The 172 Storage
files can't be downloaded without billing (HTTP 403). They are the raw form of the 6,798
rows, and they are still stored.

**On-device check:** ⏳ the Android test phone wasn't connected (§5).

## 4. Running the export (researcher's PC)

```powershell
cd C:\Users\Ahmad\AndroidStudioProjects\QoESense\functions
node tools\export_firestore.js --exclude UD1DfRM9K9Wow7GaL8BrGfbSFiG2,0y5ZtaFlJbMVBMyigwzN6TrKEHq1
# Files: C:\Users\<you>\QoESense-exports\samples.csv, mos_responses.csv (+ .ndjson)
# Optional, free BigQuery copy:
bq load --location=africa-south1 --source_format=NEWLINE_DELIMITED_JSON --replace qoesense_free_export.samples C:\Users\Ahmad\QoESense-exports\samples.ndjson <schema.json>
```

It needs the Google login already set up on this PC (`gcloud auth application-default login`).
The two `--exclude` IDs are the **test devices**: the friend's iPhone and the Android test phone.

## 5. Still to do

1. **Android on-device check:**
   - connect the phone and install the build;
   - press "Upload now" on Wi-Fi;
   - expect `telemetryBatches` documents in Firestore, the phone's buffer to shrink and
     "Last upload" to update, and `export_firestore.js` to report the samples.
2. **iOS:** rebuild and reinstall at the next Mac visit. There are no Swift changes; the
   upload path is shared Dart.
3. **The reference (original) Android app** can't use this path, because its uploads need
   Cloud Storage. Its participants should switch to the new app; their old buffers stay
   blocked until billing returns.
4. Merge `free-tier/firestore-uploads` into `main` once step 1 passes.

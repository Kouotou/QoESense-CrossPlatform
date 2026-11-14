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
- the data contract's content. **Since 2026-11-14 the free path uploads contract v2**
  (`uploadContractVersion` in `batch_document.dart`): the exporter reads v2, so the
  STALE/TIMEOUT statuses, `platform`, `capabilitySet`, the provenance fields and
  `cellChangesSinceLastSample` reach the analysis files. The Cloud Storage path would still
  send v1, because the deployed loader rejects unknown fields;
- the security rules: the current production rules already allow these writes, and this is
  proven on the emulator.

**Switching back once billing works:** set `activeUploadTarget = UploadTarget.cloudStorage` in
`lib/src/data/backend/batch_document.dart`, rebuild, then follow PHASE5_BACKEND §6 (P1 onwards).
The batch bytes are identical either way.

## 2. Free limits vs this study (Option A, owner decision 2026-11-14)

Firestore on Spark: 1 GiB stored, 20,000 writes/day, 20,000 deletes/day, 50,000 reads/day.

**Option A** stretches these to a large study without billing:
- uploads run **every 3 hours** instead of hourly (Android WorkManager period, iOS
  `UploadGate.interval` and BGTask), so a participant writes at most 8 batch documents a day;
- the exporter's **`--delete-exported`** removes batch documents once they are safely in the
  export files, so Firestore storage only holds what hasn't been exported yet.

| | Per participant per day | Free limit | Participants it allows |
|---|---|---|---|
| Size of a sample | ~19–37 bytes gzipped (measured on the test phone) | | |
| Writes | ≤ 8 batches + ≤ 6 ratings (+ consent once). Typically ~5 batches (Wi-Fi isn't on all day) + ~2–3 answered ratings ≈ 8 | 20,000/day | **~2,500 typical**; ~1,300 in the worst case (Wi-Fi all day and every prompt answered) |
| Stored data | ~1,440 samples ≈ 45 KB | 1 GiB | storage fills in ≈ 1 GiB / (participants × 45 KB) days: **export with `--delete-exported` at least weekly** at 2,000+ participants (≈ every 9 days is the limit at 2,500) |
| Export reads | each batch read once, plus 1 read per device for the delete sweep | 50,000/day | run the export **daily or every 2 days** at 2,000+ participants, so one run stays under 50,000 reads |
| Deletes | one per exported batch (≤ 8) | 20,000/day | same as writes |

**If a daily limit is ever hit:** writes are refused until the next day. The phones keep the
data and retry, and nothing is charged, because there's no card. An export or delete pass cut
short by its quota simply continues on the next run (incremental checkpoint, idempotent
delete sweep).

Above ~2,000 participants, re-enabling billing (and switching back to Cloud Storage +
BigQuery) is the comfortable path; the batch bytes are identical.

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

**On-device check** (Infinix X669, Android 12, 2026-11-14): ✅ **passed.**
- Before: 3,493 buffered samples, on Wi-Fi.
- After "Upload now": the UploadWorker reported `SUCCESS`, and **2 `telemetryBatches` documents
  (65,637 bytes, ~19 bytes per sample)** appeared in Firestore.
- The phone buffer went to **0** (rows are deleted only after the write is confirmed), and
  "Last upload" was recorded.
- `export_firestore.js` exported **3,508 rows** (7 Nov → 14 Nov, every sample since the new
  app was installed, plus those taken during the test), with 0 duplicates, 28 v1 columns and
  3,489 rows with a fresh RSRP.
- **Bug found and fixed on the way:** "Upload now" used `ExistingWorkPolicy.KEEP`. A one-off
  job left in WorkManager's retry backoff by earlier failed Cloud Storage attempts swallowed
  every new tap. It now uses `REPLACE`.

## 4. Running the export (researcher's PC)

```powershell
cd C:\Users\Ahmad\AndroidStudioProjects\QoESense\functions
node tools\export_firestore.js --exclude UD1DfRM9K9Wow7GaL8BrGfbSFiG2,0y5ZtaFlJbMVBMyigwzN6TrKEHq1
# Option A, once the study runs at scale (deletes exported batch documents afterwards):
node tools\export_firestore.js --exclude UD1DfRM9K9Wow7GaL8BrGfbSFiG2,0y5ZtaFlJbMVBMyigwzN6TrKEHq1 --delete-exported
# Files: C:\Users\<you>\QoESense-exports\samples.csv, mos_responses.csv (+ .ndjson)
# Optional, free BigQuery copy:
bq load --location=africa-south1 --source_format=NEWLINE_DELIMITED_JSON --replace qoesense_free_export.samples C:\Users\Ahmad\QoESense-exports\samples.ndjson <schema.json>
```

It needs the Google login already set up on this PC (`gcloud auth application-default login`).
The two `--exclude` IDs are the **test devices**: the friend's iPhone and the Android test phone.

**`--delete-exported` (off by default).** It runs only after the export files and
`checkpoint.json` are written and flushed to disk. It then deletes each device's batch
documents up to its checkpoint: first those exported in this run (no extra reads), then a
sweep for leftovers of an interrupted earlier pass (normally 1 read per device). Rating
documents are never deleted, and excluded devices are never touched.

> **After `--delete-exported`, the export folder is the only copy of those rows.** Back up
> `C:\Users\Ahmad\QoESense-exports` after every run: copy it to an external drive and to a
> private cloud folder (e.g. Google Drive or OneDrive). The free BigQuery sandbox is **not** a
> backup, because its tables expire after 60 days.

**New columns.** When the column list grows (e.g. `cellChangesSinceLastSample`, 2026-11-14),
the exporter rebuilds `samples.csv` from `samples.ndjson` with the new header before appending,
so the CSV never mixes two layouts.

## 5. Still to do

1. ~~Android on-device check~~: ✅ passed, 2026-11-14 (§3).
2. **iOS:** rebuild and reinstall at the next Mac visit (docs/PHASE6_MAC_HANDOFF.md §1b
   lists everything the iOS build must pick up, including the 3 h upload interval).
3. **The reference (original) Android app** can't use this path, because its uploads need
   Cloud Storage. Its participants should switch to the new app; their old buffers stay
   blocked until billing returns.
4. ~~Merge `free-tier/firestore-uploads` into `main`~~: ✅ merged on 2026-11-14.

"""Summarise a QoESense on-device buffer (read-only). Works for iOS and Android.

Usage: python3 -I tool/analyze_buffer.py <dir>
<dir> holds qoesense.sqlite (+ -wal, -shm), either directly or in a Documents/ subfolder, as
downloaded from the phone:
- iOS:  xcrun devicectl device copy from --device <udid> --domain-type appDataContainer
          --domain-identifier io.github.kouotou.qoesense --source Documents --destination <dir>/Documents
        (optionally also --source "Library/Application Support" --destination <dir>/AppSupport
        for the native survey queue)
- Android: the adb commands in docs/PHASE3_ANDROID.md §6.
It prints cadence, gaps, call periods, path/RAT changes, field statuses, survey bookkeeping
and pending MOS ratings. The pulled files are copied before opening, never modified.
"""
import collections
import datetime as dt
import json
import os
import shutil
import sqlite3
import sys
import tempfile

root = sys.argv[1]
docs = os.path.join(root, "Documents")
if not os.path.isdir(docs):
    docs = root
db_files = [f for f in os.listdir(docs) if f.startswith("qoesense.sqlite")] if os.path.isdir(docs) else []
print("files:", sorted(db_files))
work = tempfile.mkdtemp()
for f in db_files:
    shutil.copy(os.path.join(docs, f), work)  # never open the pulled copy in place
con = sqlite3.connect(os.path.join(work, "qoesense.sqlite"))


def ts(ms):
    return dt.datetime.fromtimestamp(ms / 1000).strftime("%m-%d %H:%M:%S")


rows = [(r[0], r[1], json.loads(r[2])) for r in con.execute(
    "select id, timestamp_ms, payload from buffered_samples order by timestamp_ms")]
print(f"\nsamples: {len(rows)}")
if rows:
    print("first", ts(rows[0][1]), "last", ts(rows[-1][1]))

# Cadence: gap to previous sample, bucketed, and long gaps listed.
gaps = [(rows[i][1] - rows[i - 1][1]) / 1000 for i in range(1, len(rows))]
buckets = collections.Counter()
for g in gaps:
    b = ("<14s" if g < 14 else "14-17s" if g <= 17 else "17-55s" if g < 55 else "55-65s" if g <= 65
         else "65-120s" if g <= 120 else "2-10min" if g <= 600 else "10-60min" if g <= 3600 else ">1h")
    buckets[b] += 1
print("\ngap buckets:", dict(sorted(buckets.items())))
print("long gaps (>3 min):")
for i in range(1, len(rows)):
    g = (rows[i][1] - rows[i - 1][1]) / 1000
    if g > 180:
        p = rows[i][2]
        print(f"  {ts(rows[i-1][1])} -> {ts(rows[i][1])}  {g/60:.1f} min   next: throughput={p['throughputStatus']}")

# Samples per hour.
per_hour = collections.Counter(ts(r[1])[:8] for r in rows)
print("\nsamples per hour:")
for h, n in sorted(per_hour.items()):
    print(f"  {h}:00  {n}")

# Calls (CallKit) and the cadence inside them.
print("\ncall periods (appSessionType VIDEO_CONFERENCING):")
run = []
for r in rows + [(None, None, {"appSessionType": "END"})]:
    if r[2]["appSessionType"] == "VIDEO_CONFERENCING":
        run.append(r)
    elif run:
        inner = [(run[i][1] - run[i - 1][1]) / 1000 for i in range(1, len(run))]
        med = sorted(inner)[len(inner) // 2] if inner else None
        print(f"  {ts(run[0][1])} -> {ts(run[-1][1])}  {len(run)} samples, median spacing {med}s")
        run = []


def transitions(key, status_key):
    out, last = [], object()
    for r in rows:
        v = (r[2].get(key), r[2].get(status_key))
        if v != last:
            out.append((ts(r[1]), v))
            last = v
    return out


for key, sk in [("connectionType", "connectivityStatus"), ("networkType", "networkTypeStatus")]:
    t = transitions(key, sk)
    print(f"\n{key} changes ({len(t)}):")
    for x in t[:40]:
        print("  ", x)

for sk in ["locationStatus", "throughputStatus", "rttStatus", "radioStatus", "foregroundAppStatus"]:
    print(f"\n{sk}:", dict(collections.Counter(r[2][sk] for r in rows)))
print("\ntier:", dict(collections.Counter(r[2]["telemetryCapabilityTier"] for r in rows)))
print("platform:", dict(collections.Counter(r[2]["platform"] for r in rows)))
acc = sorted(r[2]["locationAccuracyMeters"] for r in rows if r[2]["locationAccuracyMeters"] is not None)
if acc:
    print("location accuracy m: min", acc[0], "median", acc[len(acc) // 2], "max", acc[-1])
ages = sorted(r[2]["locationAgeMs"] for r in rows if r[2]["locationAgeMs"] is not None)
if ages:
    print("location age ms: median", ages[len(ages) // 2], "max", ages[-1])
rtts = sorted(r[2]["rttMs"] for r in rows if r[2]["rttMs"] is not None)
if rtts:
    print("rtt ms: n", len(rtts), "median", rtts[len(rtts) // 2], "max", rtts[-1])
tp = sorted(r[2]["throughputBytesPerSecond"] for r in rows if r[2]["throughputBytesPerSecond"] is not None)
if tp:
    print("throughput B/s: n", len(tp), "median", tp[len(tp) // 2], "max", tp[-1])
cd = sorted(r[2]["captureDurationMs"] for r in rows)
if cd:
    print("captureDurationMs: median", cd[len(cd) // 2], "max", cd[-1])
any_radio = [r for r in rows if r[2]["rsrp"] is not None or r[2]["isRoaming"] is not None]
print("rows with a radio value or roaming (must be 0):", len(any_radio))

print("\nkey_values:")
for k, v in con.execute("select key, value from key_values order by key"):
    if k.startswith("survey.") or k.startswith("upload.") or k.startswith("consent") or k.startswith("onboarding"):
        extra = f"  ({ts(int(v))})" if v.isdigit() and len(v) == 13 else ""
        print(f"  {k} = {v}{extra}")

print("\npending MOS (not yet accepted by Firestore):")
for rid, payload, attempts, created in con.execute(
        "select response_id, payload, attempts, created_at_ms from pending_mos_responses"):
    p = json.loads(payload)
    print(f"  {rid[:8]} score={p.get('score')} trigger={p.get('triggerType')} mode={p.get('presentationMode')} "
          f"context={p.get('contextSource')}/{p.get('contextAppPackage')}/{p.get('contextSessionType')} "
          f"tap={ts(p.get('submittedAtMs'))} prompted={ts(p['promptedAtMs']) if p.get('promptedAtMs') else None} "
          f"attempts={attempts}")

ans = os.path.join(root, "AppSupport", "qoesense", "survey_answers.json")
print("\nnative answer queue:", open(ans).read() if os.path.exists(ans) else "(no file)")

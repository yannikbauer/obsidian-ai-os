"""Read a Garmin Connect data export (read-only) into one daily CSV table.

Usage: python3 -I tools/garmin-export.py <unzipped export>/DI_CONNECT <out.csv>
The export is untrusted data: unzip it into its own empty folder outside the vault, and
keep the CSV out of git (databases/ is ignored). Health data: private.
Row date = the calendar day. Night fields come from the sleep that ENDS the next morning
(the daily-log convention: night D -> D+1 belongs to day D).
"""
import csv, datetime as dt, glob, json, os, statistics as st, sys
from zoneinfo import ZoneInfo

root, out = sys.argv[1], sys.argv[2]
# Local time for sleep timestamps: AIOS_TZ (an IANA name) if set, else the system zone.
TZ = ZoneInfo(os.environ["AIOS_TZ"]) if os.environ.get("AIOS_TZ") else None
D = lambda s: dt.date.fromisoformat(s[:10])
rows = {}
def row(d): return rows.setdefault(d, {"date": d})

for p in glob.glob(f"{root}/DI-Connect-Aggregator/UDSFile_*.json"):
    for r in json.load(open(p)):
        if not r.get("includesWellnessData"): continue
        x = row(D(r["calendarDate"]))
        x["steps"] = r.get("totalSteps")
        x["rhr"] = r.get("restingHeartRate")
        x["int_min"] = (r.get("moderateIntensityMinutes") or 0) + 2 * (r.get("vigorousIntensityMinutes") or 0)
        for a in (r.get("allDayStress") or {}).get("aggregatorList", []):
            if a.get("type") == "TOTAL":
                x["stress"] = a.get("averageStressLevel")
                x["stress_high_min"] = round((a.get("highDuration") or 0) / 60)
        bb = r.get("bodyBattery") or {}
        x["bb_drain"] = bb.get("drainedValue")

for p in glob.glob(f"{root}/DI-Connect-Wellness/*_sleepData.json"):
    try: data = json.load(open(p))
    except Exception: continue
    for r in data:
        if "sleepStartTimestampGMT" not in r: continue
        wake = D(r["calendarDate"]); x = row(wake - dt.timedelta(days=1))
        secs = sum(r.get(k) or 0 for k in ("deepSleepSeconds", "lightSleepSeconds", "remSleepSeconds"))
        if secs < 3 * 3600: continue
        x["sleep_h"] = round(secs / 3600, 2)
        x["awake_min"] = round((r.get("awakeSleepSeconds") or 0) / 60)
        x["deep_min"] = round((r.get("deepSleepSeconds") or 0) / 60)
        x["sleep_score"] = (r.get("sleepScores") or {}).get("overallScore")
        x["sleep_stress"] = r.get("avgSleepStress")
        start = dt.datetime.fromisoformat(r["sleepStartTimestampGMT"][:19]).replace(tzinfo=dt.timezone.utc).astimezone(TZ)
        h = start.hour + start.minute / 60
        x["bed_h"] = round(h if h >= 12 else h + 24, 2)   # 23.5 = 23:30, 25 = 01:00

for p in glob.glob(f"{root}/DI-Connect-Wellness/*_healthStatusData.json"):
    for r in json.load(open(p)):
        for m in r.get("metrics", []):
            if m.get("type") == "HRV" and m.get("value"):
                row(D(r["calendarDate"]) - dt.timedelta(days=1))["hrv"] = m["value"]  # morning HRV = night before

for p in glob.glob(f"{root}/DI-Connect-Fitness/*summarizedActivities.json"):
    for a in json.load(open(p))[0]["summarizedActivitiesExport"]:
        d = dt.datetime.fromtimestamp(a["startTimeLocal"] / 1000, dt.timezone.utc).date()
        x = row(d); x["sport_min"] = x.get("sport_min", 0) + round(a["duration"] / 60000)
        x["sports"] = (x.get("sports", "") + " " + a.get("activityType", "")).strip()

# body battery charged overnight: highest of next day is closest proxy -> use UDS of wake day
for p in glob.glob(f"{root}/DI-Connect-Aggregator/UDSFile_*.json"):
    for r in json.load(open(p)):
        bb = r.get("bodyBattery") or {}
        if bb.get("chargedValue") is not None:
            row(D(r["calendarDate"]) - dt.timedelta(days=1))["bb_charge"] = bb["chargedValue"]

keys = ["date", "steps", "rhr", "int_min", "stress", "stress_high_min", "bb_drain", "sleep_h", "awake_min",
        "deep_min", "sleep_score", "sleep_stress", "bed_h", "hrv", "bb_charge", "sport_min", "sports"]
data = [rows[d] for d in sorted(rows)]
with open(out, "w", newline="") as f:
    w = csv.DictWriter(f, keys); w.writeheader(); [w.writerow({k: r.get(k) for k in keys}) for r in data]
print(f"{len(data)} days, {data[0]['date']} .. {data[-1]['date']}")

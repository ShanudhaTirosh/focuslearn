"""Contract tests: hand-written planner vectors <-> Python reference (<-> SQL constraints, added once the migration exists).
The same vectors are loaded by the Dart test (packages/core/test/planner_test.dart)."""
import glob, json, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
import planner_reference as pr
V = json.load(open(os.path.join(ROOT, "test-vectors", "planner.json"), encoding="utf-8"))
results = []

def check(name, cond, detail=""):
    results.append(bool(cond)); print(("PASS  " if cond else "FAIL  ") + name + (f"   [{str(detail)[:600]}]" if (detail and not cond) else ""))

check("vectors file is up to date with its generator", subprocess.run([sys.executable, os.path.join(HERE, "make_planner_vectors.py"), "--check"], capture_output=True).returncode == 0)

# ---- rrule
for c in V["rrule"]["valid"]:
    try:
        got = pr.canonical(c["in"])
    except pr.PlannerError as e:
        got = "ERROR " + e.code
    check(f"rrule valid: {c['in'][:60]}", got == c["canonical"], got)
    check(f"rrule canonical form is stable (idempotent): {c['canonical'][:50]}", pr.canonical(c["canonical"]) == c["canonical"])
for c in V["rrule"]["invalid"]:
    try:
        pr.parse_rrule(c["in"]); got = "accepted"
    except pr.PlannerError as e:
        got = e.code
    check(f"rrule invalid ({c['code']}): {c['in'][:50]!r}", got == c["code"], got)

# ---- expand
for c in V["expand"]:
    got = pr.expand(c["rule"], c["start"], c["zone"], c["durationMin"], c["from"], c["to"], c["skip"], c["override"])
    check(f"expand: {c['name']}", got == c["expect"], {"got": got, "want": c["expect"]})

# ---- split
for c in V["split"]:
    try:
        got = pr.split_series(c["rule"], c["start"], c["zone"], c["at"])
    except pr.PlannerError as e:
        got = {"error": e.code}
    want = {"error": c["error"]} if "error" in c else {k: c[k] for k in ("first", "second", "secondStartUtc")}
    check(f"split: {c['name']}", got == want, {"got": got, "want": want})
    if "error" not in c:  # the two halves must be valid rules, and together they must reproduce the original series
        a = pr.expand(c["rule"], c["start"], c["zone"], 150, "2026-01-01T00:00:00Z", "2028-01-01T00:00:00Z")
        first = pr.expand(c["first"], c["start"], c["zone"], 150, "2026-01-01T00:00:00Z", "2028-01-01T00:00:00Z")
        d, hm = c["start"].split("T")
        sec_local = pr.parse_iso(c["secondStartUtc"]).astimezone(pr.ZoneInfo(c["zone"])).strftime("%Y-%m-%dT%H:%M")
        second = pr.expand(c["second"], sec_local, c["zone"], 150, "2026-01-01T00:00:00Z", "2028-01-01T00:00:00Z")
        check(f"split: the halves together equal the original series: {c['name']}", first + second == a, (len(first), len(second), len(a)))

# ---- conflicts, free slots, duration hint
for c in V["conflicts"]:
    try:
        got = pr.conflicts(c["in"])
    except pr.PlannerError as e:
        got = {"error": e.code}
    check(f"conflicts: {c['name']}", got == (c["expect"] if "expect" in c else {"error": c["error"]}), got)
for c in V["freeSlots"]:
    try:
        got = pr.free_slots(c["window"][0], c["window"][1], c["busy"], c["min"], c["max"], c["buffer"])
    except pr.PlannerError as e:
        got = {"error": e.code}
    check(f"freeSlots: {c['name']}", got == (c["expect"] if "expect" in c else {"error": c["error"]}), got)
for c in V["durationHint"]:
    check(f"durationHint: {c['minutes']} minutes is {c['expect']}", pr.duration_hint(c["minutes"]) == c["expect"])

# ---- meeting url
for c in V["meetingUrl"]:
    got = pr.validate_meeting_url(c["in"])
    want = {k: c[k] for k in ("code", "provider", "normalized") if k in c}
    check(f"meetingUrl: {c['name']}", got == want, {"got": got, "want": want})

# ---- reminders
for c in V["reminders"]:
    got = pr.plan_reminders(c["starts"], c["offsets"], c["now"], c["zone"], c.get("quiet"))
    check(f"reminders: {c['name']}", got == c["expect"], {"got": got, "want": c["expect"]})


# ---------------------------------------------------------------- SQL parity
import glob, itertools
sql = open(os.path.join(ROOT, "backend/supabase/migrations/20261018000000_planner.sql"), encoding="utf-8").read()
m = re.search(r"rrule ~ '(\^FREQ=[^']*\$)'", sql)
RR = m.group(1) if m else None
check("SQL: the rrule pattern was found in the migration", RR is not None)
def sql_rrule(s):
    return (len(s) <= 200 and re.fullmatch(RR, s) is not None and not (";COUNT=" in s and ";UNTIL=" in s)
            and (";BYDAY=" not in s or s.startswith("FREQ=WEEKLY")) and (";BYMONTHDAY=" not in s or s.startswith("FREQ=MONTHLY")))
bad = [c["canonical"] for c in V["rrule"]["valid"] if not sql_rrule(c["canonical"])]
check("SQL parity: every valid canonical rule is accepted by the database", not bad, bad)
bad = [c["in"] for c in V["rrule"]["invalid"] if not c.get("sqlMayAccept") and sql_rrule(c["in"])]
check("SQL parity: every invalid rule is rejected by the database (except the two documented looser cases)", not bad, bad)
check("SQL: the three cross-field constraints exist", all(x in sql for x in ("event_recurrences_count_until_chk", "event_recurrences_byday_chk", "event_recurrences_bymonthday_chk")))

# Grammar sweep: all canonical-order combinations of small component lists
freqs = ["DAILY", "WEEKLY", "MONTHLY"]; ints = [None, "1", "2", "999", "1000", "0"]
bydays = [None, "MO", "MO,TU", "TU,TU", "XX", "1TU"]; bymds = [None, "1", "-1", "15,-1", "32", "0", "5,5"]
cnts = [None, "1", "1000", "1001", "0"]; unts = [None, "20261231T235959Z", "20261331T000000Z", "20260431T000000Z", "20261231T240000Z"]
total = ok_client = looser = 0; problems = []
for f, i, bd, bm, c, u in itertools.product(freqs, ints, bydays, bymds, cnts, unts):
    parts = ["FREQ=" + f] + (["INTERVAL=" + i] if i else []) + (["BYDAY=" + bd] if bd else []) + (["BYMONTHDAY=" + bm] if bm else []) + (["COUNT=" + c] if c else []) + (["UNTIL=" + u] if u else [])
    s = ";".join(parts); total += 1
    try:
        canon = pr.canonical(s); client_ok = True
    except pr.PlannerError:
        client_ok = False
    sql_ok = sql_rrule(s)
    if client_ok:
        ok_client += 1
        if not sql_rrule(canon):
            problems.append(("client accepts but SQL rejects", s, canon))
    elif sql_ok:
        known = ("BYDAY=TU,TU" in s) or ("BYMONTHDAY=5,5" in s) or ("UNTIL=20260431T000000Z" in s)
        looser += 1
        if not known:
            problems.append(("SQL accepts but the client rejects", s))
check(f"SQL parity sweep over {total} rule combinations ({ok_client} valid): the database never rejects what the client accepts, and is looser only in the known cases", not problems, problems[:5])
# Counted by hand from the component lists above: DAILY 4 intervals x 4 (count/until) = 16, WEEKLY 4 x 3 byday x 4 = 48, MONTHLY 4 x 4 bymonthday x 4 = 64.
check("the sweep found exactly the 128 valid combinations counted by hand, and some looser-in-SQL cases", ok_client == 128 and looser > 0 and total == 18900, (total, ok_client, looser))

m = re.search(r"meeting_url ~ '(\^https://[^']*\$)'", sql)
UR = m.group(1) if m else None
check("SQL: the meeting link pattern was found in the migration", UR is not None)
def posix_to_python(pattern):
    """PostgreSQL understands [:space:] and [:cntrl:]; Python's re does not (it would read them as sets of letters)."""
    return pattern.replace("[:space:]", r"\s").replace("[:cntrl:]", r"\x00-\x1f\x7f")
UR = posix_to_python(UR) if UR else UR
check("the translated link pattern keeps its character classes (a path with the letters s, p, a, c, e is accepted)", UR and re.fullmatch(UR, "https://zoom.us/space") is not None and re.fullmatch(UR, "https://zoom.us/a b") is None)
def sql_url(u):
    return len(u) <= 500 and re.fullmatch(UR, u) is not None
bad = [c["name"] for c in V["meetingUrl"] if c["code"] == "ok" and not sql_url(c["normalized"])]
check("SQL parity: every normalised link the client accepts is accepted by the database", not bad, bad)
bad = [c["name"] for c in V["meetingUrl"] if c["code"] in ("not_https", "credentials", "too_long", "invalid_url") and not c.get("sqlMayAccept") and sql_url(c["in"])]
check("SQL parity: links the client rejects for scheme, credentials, length or syntax are rejected by the database too", not bad, bad)

L = V["limits"]
check("SQL parity: title, location, notes, link length and the 24-hour limit", all(x in sql for x in (f"between 1 and {L['titleMax']} and title", f"char_length(location) <= {L['locationMax']}", f"char_length(notes) <= {L['notesMax']}", f"char_length(meeting_url) <= {L['meetingUrlMax']}", f"interval '{L['eventMaxHours']} hours'")))
check("SQL parity: reminder limits", f"cardinality(reminder_offsets) <= {L['reminderCountMax']}" in sql and f"{L['reminderOffsetMax']} >= all (reminder_offsets)" in sql)
mm = re.search(r"category in \(([^)]*)\)", sql)
check("SQL parity: event categories", mm and [x.strip().strip("'") for x in mm.group(1).split(",")] == L["categories"])
check("limits: the soft planning range is 150 to 240 minutes (2.5 to 4 hours)", L["preferredBlockMinutes"] == [150, 240] and pr.duration_hint(150) == "within" and pr.duration_hint(240) == "within")

# ---- structure of the vectors themselves
check("the acceptance example (Tuesday 7:30 PM class) is in the vectors", any("Tuesday 7:30 PM" in c["name"] for c in V["expand"]))
check("month ends, a leap year, and both DST directions are covered", all(any(k in c["name"] for c in V["expand"]) for k in ("leap year", "no 31st", "spring forward", "fall back")))
check("every rrule error code in the reference is exercised by a vector", {c["code"] for c in V["rrule"]["invalid"]} >= {"empty", "unsupported_freq", "missing_freq", "invalid_byday", "byday_needs_weekly", "bymonthday_needs_monthly", "invalid_bymonthday", "invalid_interval", "invalid_count", "count_and_until", "invalid_until", "unsupported_key", "duplicate_key", "invalid_syntax", "too_long"})

print(f"\n{sum(results)} passed, {len(results) - sum(results)} failed")
sys.exit(0 if all(results) else 1)

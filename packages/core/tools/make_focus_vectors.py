#!/usr/bin/env python3
"""Writes test-vectors/focus.json. Every EXPECTED value is worked out by hand from the rules (see the comments), never from the code
under test. 2026-10-20 is a Tuesday. Run: make_focus_vectors.py [--check]"""
import json, os, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(ROOT, "test-vectors", "focus.json")
V = {"validated": [], "tree": [], "streak": [], "longest": [], "achievements": []}
BASE = "2026-10-17T"

def val(name, planned, s, e, paused, reported, recv, expect):
    V["validated"].append({"name": name, "planned": planned, "started": s, "ended": e, "paused": paused, "reported": reported, "received": recv, "expect": expect})

# validated seconds = max(0, min(max(reported,0), elapsed - clamp(paused,0,elapsed), planned + 300, 28800)); 0 if the times are bad or stale
val("a full 25-minute session", 1500, BASE + "10:00:00Z", BASE + "10:25:00Z", 0, 1500, BASE + "10:25:05Z", 1500)
val("the client claims more than the clock allows (elapsed 1500)", 1500, BASE + "10:00:00Z", BASE + "10:25:00Z", 0, 1800, BASE + "10:25:05Z", 1500)
val("the client reports less than elapsed", 1500, BASE + "10:00:00Z", BASE + "10:25:00Z", 0, 1200, BASE + "10:25:05Z", 1200)
val("300 seconds paused out of 1500 elapsed", 1500, BASE + "10:00:00Z", BASE + "10:25:00Z", 300, 1500, BASE + "10:25:05Z", 1200)
val("ran an hour on a 25-minute plan: the plan plus 300 seconds (1800)", 1500, BASE + "10:00:00Z", BASE + "11:00:00Z", 0, 3600, BASE + "11:00:05Z", 1800)
val("an overrun inside the 300 seconds (elapsed 1700, cap 1800)", 1500, BASE + "10:00:00Z", BASE + "10:28:20Z", 0, 1700, BASE + "10:28:25Z", 1700)
val("exactly the cap: plan 600, elapsed 900", 600, BASE + "10:00:00Z", BASE + "10:15:00Z", 0, 900, BASE + "10:15:05Z", 900)
val("a 60-second plan that ran 600 seconds: cap 360", 60, BASE + "10:00:00Z", BASE + "10:10:00Z", 0, 600, BASE + "10:10:05Z", 360)
val("the 8-hour cap (elapsed 32400 on a 28800 plan)", 28800, BASE + "00:00:00Z", BASE + "09:00:00Z", 0, 32400, BASE + "09:00:05Z", 28800)
val("the end is before the start", 1500, BASE + "10:25:00Z", BASE + "10:00:00Z", 0, 1500, BASE + "10:25:05Z", 0)
val("zero length", 1500, BASE + "10:00:00Z", BASE + "10:00:00Z", 0, 100, BASE + "10:00:05Z", 0)
val("the end is exactly 300 s ahead of the server clock: tolerated", 600, BASE + "10:00:00Z", BASE + "10:10:00Z", 0, 600, BASE + "10:05:00Z", 600)
val("the end is 301 s ahead of the server clock: nothing", 600, BASE + "10:00:00Z", BASE + "10:10:00Z", 0, 600, BASE + "10:04:59Z", 0)
val("received exactly 14 days after it ended: still counts", 600, "2026-10-01T10:00:00Z", "2026-10-01T10:10:00Z", 0, 600, "2026-10-15T10:10:00Z", 600)
val("received 14 days and 1 second after it ended: nothing (no back-filling a streak)", 600, "2026-10-01T10:00:00Z", "2026-10-01T10:10:00Z", 0, 600, "2026-10-15T10:10:01Z", 0)
val("a negative report", 1500, BASE + "10:00:00Z", BASE + "10:25:00Z", 0, -5, BASE + "10:25:05Z", 0)
val("a negative pause counts as none", 1500, BASE + "10:00:00Z", BASE + "10:25:00Z", -100, 1500, BASE + "10:25:05Z", 1500)
val("a negative pause cannot create extra time (elapsed 1500, report 1600)", 1500, BASE + "10:00:00Z", BASE + "10:25:00Z", -100, 1600, BASE + "10:25:05Z", 1500)
val("a pause longer than the session leaves nothing", 1500, BASE + "10:00:00Z", BASE + "10:25:00Z", 5000, 1500, BASE + "10:25:05Z", 0)
val("nothing reported", 1500, BASE + "10:00:00Z", BASE + "10:25:00Z", 0, 0, BASE + "10:25:05Z", 0)
val("a short session of 299 seconds is accepted as 299 (it just does not count)", 600, BASE + "10:00:00Z", BASE + "10:04:59Z", 0, 299, BASE + "10:05:00Z", 299)
val("a session synced late from an offline phone (3 days)", 1500, "2026-10-14T10:00:00Z", "2026-10-14T10:25:00Z", 0, 1500, "2026-10-17T08:00:00Z", 1500)

for v, stage, counted in [(0, "none", False), (1, "none", False), (299, "none", False), (300, "seedling", True), (899, "seedling", True), (900, "sapling", True), (1499, "sapling", True),
                          (1500, "tree", True), (2999, "tree", True), (3000, "grove", True), (28800, "grove", True)]:
    V["tree"].append({"validated": v, "stage": stage, "counted": counted})

D = lambda day: "2026-10-%02d" % day
def st(name, days, expect_streak, expect_rest, today="2026-10-20", goal=1800):
    V["streak"].append({"name": name, "days": days, "today": today, "goal": goal, "streak": expect_streak, "rest_days": expect_rest})
met = lambda ds: [[D(d), 2000] for d in ds]
st("no data", [], 0, 0)
st("only today met", met([20]), 1, 0)
st("today still open, yesterday met: the streak is kept", [[D(20), 1000], [D(19), 2000]], 1, 0)
st("three days in a row", met([18, 19, 20]), 3, 0)
st("one isolated missed day is a rest day (19)", met([17, 18, 20]), 3, 1)
st("two missed days in a row break the streak", met([20, 17, 16]), 1, 0)
st("a second rest day within 7 days is not forgiven", met([20, 18, 16]), 2, 1)
st("rest days exactly 7 days apart (19 and 12) are both forgiven", met([20, 18, 17, 16, 15, 14, 13, 11, 10]), 9, 2)
st("rest days 6 days apart (19 and 13): the second one breaks the streak", met([20, 18, 17, 16, 15, 14, 12, 11]), 6, 1)
st("exactly the goal counts", [[D(20), 1800]], 1, 0)
st("one second under the goal does not", [[D(20), 1799]], 0, 0)
st("yesterday and today both open: yesterday becomes a pending rest day", met([18]), 1, 1)
st("two days of nothing after a met day", [[D(18), 2000]], 1, 1, today="2026-10-20")
st("last met day too long ago", met([15]), 0, 0)
st("a different goal (600)", [[D(19), 700], [D(20), 700]], 2, 0, goal=600)
st("several rows for one day add up", [[D(20), 1000], [D(20), 900]], 1, 0)
st("across a month boundary", [["2026-09-30", 2000], ["2026-10-01", 2000]], 2, 0, today="2026-10-01")
st("across a year boundary", [["2026-12-31", 2000], ["2027-01-01", 2000]], 2, 0, today="2027-01-01")
st("a met day in the future is ignored", [[D(21), 5000]], 0, 0)
st("a rest day then an open today", met([17, 18]), 2, 1)

def lg(name, days, expect, goal=1800):
    V["longest"].append({"name": name, "days": days, "goal": goal, "expect": expect})
lg("no data", [], 0)
lg("a rest day joins two runs (1-3, 5-7, 4 missed)", met([1, 2, 3, 5, 6, 7]), 6)
lg("a two-day gap separates runs", met([1, 2, 3, 6, 7]), 3)
lg("one met day", met([9]), 1)
lg("only unmet days", [[D(1), 1000], [D(2), 1000]], 0)
lg("two gaps close together: the second is not forgiven (best run is 3)", met([1, 2, 4, 6, 7]), 3)
lg("a perfect month of 30 days", met(list(range(1, 31))), 30)
lg("29 days", met(list(range(1, 30))), 29)

for name, args, expect in [
    ("nothing yet", [0, 0, 0], []), ("the first session", [1, 300, 0], ["first_session"]), ("just short of everything", [24, 35999, 2], ["first_session"]),
    ("25 sessions, 10 hours, a 7-day streak", [25, 36000, 7], ["first_session", "sessions_25", "hours_10", "streak_3", "streak_7"]),
    ("everything", [100, 180000, 30], ["first_session", "sessions_25", "hours_10", "hours_50", "streak_3", "streak_7", "streak_30"]),
    ("29-day streak, 179999 seconds", [25, 179999, 29], ["first_session", "sessions_25", "hours_10", "streak_3", "streak_7"]),
    ("few sessions but many hours", [5, 200000, 3], ["first_session", "hours_10", "hours_50", "streak_3"])]:
    V["achievements"].append({"name": name, "sessions": args[0], "total_seconds": args[1], "longest": args[2], "expect": expect})

V["constants"] = {"skewSeconds": 300, "staleDays": 14, "overrunSeconds": 300, "maxSessionSeconds": 28800, "countedMinSeconds": 300,
                  "treeStages": [[300, "seedling"], [900, "sapling"], [1500, "tree"], [3000, "grove"]], "restDaySpacing": 7, "defaultGoalSeconds": 1800}

def main(argv):
    text = json.dumps(V, indent=1, ensure_ascii=False, sort_keys=True) + "\n"
    if "--check" in argv:
        good = os.path.exists(OUT) and open(OUT, encoding="utf-8").read() == text
        print("OK    focus vectors are up to date" if good else "FAIL  test-vectors/focus.json is out of date: run make_focus_vectors.py")
        return 0 if good else 1
    open(OUT, "w", encoding="utf-8").write(text)
    print("wrote", os.path.relpath(OUT, ROOT), "-", sum(len(V[k]) for k in V if k != "constants"), "cases")
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv))

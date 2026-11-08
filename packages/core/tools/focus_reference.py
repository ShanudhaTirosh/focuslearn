#!/usr/bin/env python3
"""Python REFERENCE for the focus-session rules (Phase 3): validated seconds, tree growth, daily streaks with a gentle rest-day
allowance, and achievements. The DATABASE is the authority (SQL functions in private.*); this reference proves the rules against
hand-written vectors and is what the Dart client mirrors for offline display only. Client reports are advisory."""
import datetime as dt

UTC = dt.timezone.utc
SKEW_SECONDS = 300           # an end time up to 5 minutes ahead of the server clock is tolerated
STALE_DAYS = 14              # a session received more than 14 days after it ended earns nothing (stops back-filling a streak)
OVERRUN_SECONDS = 300        # time beyond the planned length that still counts (the timer was left running a little)
MAX_SESSION_SECONDS = 28800  # 8 hours
COUNTED_MIN_SECONDS = 300    # under 5 minutes is kept in history but grows no tree and counts towards nothing
TREE_STAGES = [(3000, "grove"), (1500, "tree"), (900, "sapling"), (300, "seedling")]
REST_DAY_SPACING = 7         # at most one forgiven (rest) day in any 7 consecutive days
MAX_SCAN_DAYS = 4000
DEFAULT_GOAL_SECONDS = 1800
ACHIEVEMENT_ORDER = ["first_session", "sessions_25", "hours_10", "hours_50", "streak_3", "streak_7", "streak_30"]


def _t(s):
    return dt.datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=UTC)


def validated_seconds(planned, started, ended, paused, reported, received):
    """Focus seconds the server accepts. Never more than the wall clock allows, never more than was reported, never more than
    the plan plus a small overrun, never more than 8 hours. A bad or stale timestamp earns 0 (not a penalty: simply nothing)."""
    s, e, r = _t(started), _t(ended), _t(received)
    if e <= s or e > r + dt.timedelta(seconds=SKEW_SECONDS) or r - e > dt.timedelta(days=STALE_DAYS):
        return 0
    elapsed = int((e - s).total_seconds())
    paused_c = min(max(paused, 0), elapsed)
    active = elapsed - paused_c
    return max(0, min(max(reported, 0), active, planned + OVERRUN_SECONDS, MAX_SESSION_SECONDS))


def is_counted(validated):
    return validated >= COUNTED_MIN_SECONDS


def tree_stage(validated):
    for floor, name in TREE_STAGES:
        if validated >= floor:
            return name
    return "none"


def _met(totals, day, goal):
    return totals.get(day, 0) >= goal


def streak(days, today, goal=DEFAULT_GOAL_SECONDS):
    """Current streak of days that reached the goal, ending today (or yesterday while today is still open).
    A single unmet day between two met days is a 'rest day': it neither breaks the streak nor adds to it, and only one rest day is
    allowed in any 7 consecutive days. `days` is a list of [date, seconds]; several rows for one date add up."""
    totals = {}
    for d, secs in days:
        k = dt.date.fromisoformat(d)
        totals[k] = totals.get(k, 0) + secs
    t = dt.date.fromisoformat(today)
    d = t if _met(totals, t, goal) else t - dt.timedelta(days=1)
    count = rest = 0
    last_forgiven = None
    for _ in range(MAX_SCAN_DAYS):
        if _met(totals, d, goal):
            count += 1
        elif _met(totals, d - dt.timedelta(days=1), goal) and (last_forgiven is None or (last_forgiven - d).days >= REST_DAY_SPACING):
            rest += 1
            last_forgiven = d
        else:
            break
        d -= dt.timedelta(days=1)
    return {"streak": count, "rest_days": rest}


def longest_streak(days, goal=DEFAULT_GOAL_SECONDS):
    totals = {}
    for d, secs in days:
        k = dt.date.fromisoformat(d)
        totals[k] = totals.get(k, 0) + secs
    best = 0
    for d in sorted(k for k in totals if totals[k] >= goal):
        best = max(best, streak(days, d.isoformat(), goal)["streak"])
    return best


def achievements(counted_sessions, total_counted_seconds, longest):
    got = []
    if counted_sessions >= 1: got.append("first_session")
    if counted_sessions >= 25: got.append("sessions_25")
    if total_counted_seconds >= 36000: got.append("hours_10")
    if total_counted_seconds >= 180000: got.append("hours_50")
    if longest >= 3: got.append("streak_3")
    if longest >= 7: got.append("streak_7")
    if longest >= 30: got.append("streak_30")
    return got

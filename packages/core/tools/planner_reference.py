#!/usr/bin/env python3
"""Python REFERENCE implementation of the planner rules (recurrence, conflicts, free time, class links, reminders).
It proves the rules against hand-written vectors (test-vectors/planner.json) and is the second implementation the Dart one is compared with.
Standard library only (zoneinfo supplies the IANA time zone rules)."""
import datetime as dt
import re
import sys
from zoneinfo import ZoneInfo

HERE = __file__.rsplit("/", 1)[0]
sys.path.insert(0, HERE)
import reference_validation as rv  # noqa: E402  (trim_ws)

UTC = dt.timezone.utc
WD = ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]
ALLOWED_KEYS = {"FREQ", "INTERVAL", "BYDAY", "BYMONTHDAY", "COUNT", "UNTIL"}
MAX_ITERATIONS = 100000


class PlannerError(ValueError):
    def __init__(self, code):
        super().__init__(code)
        self.code = code


# ---------------------------------------------------------------- time helpers
def iso(d):
    return d.astimezone(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")


def parse_iso(s):
    return dt.datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=UTC)


def local_to_utc(tz, d, hour, minute):
    """Wall-clock time in a zone to UTC. A time that does not exist (spring-forward gap) moves forward by the gap
    (it keeps the offset from before the change); a time that happens twice (fall-back overlap) means the FIRST one."""
    return dt.datetime(d.year, d.month, d.day, hour, minute).replace(tzinfo=tz, fold=0).astimezone(UTC)


# ---------------------------------------------------------------- RRULE subset
def parse_rrule(s):
    if s == "":
        raise PlannerError("empty")
    if len(s) > 200:
        raise PlannerError("too_long")
    if re.search(r"\s", s):
        raise PlannerError("invalid_syntax")
    kv = {}
    for part in s.split(";"):
        if part == "" or part.count("=") != 1:
            raise PlannerError("invalid_syntax")
        k, v = part.split("=")
        if k == "" or v == "":
            raise PlannerError("invalid_syntax")
        if k not in ALLOWED_KEYS:
            raise PlannerError("unsupported_key")
        if k in kv:
            raise PlannerError("duplicate_key")
        kv[k] = v
    if "FREQ" not in kv:
        raise PlannerError("missing_freq")
    freq = kv["FREQ"]
    if freq not in ("DAILY", "WEEKLY", "MONTHLY"):
        raise PlannerError("unsupported_freq")
    rule = {"freq": freq, "interval": 1, "byday": [], "bymonthday": [], "count": None, "until": None}
    if "INTERVAL" in kv:
        if not re.fullmatch(r"[1-9][0-9]{0,2}", kv["INTERVAL"]):
            raise PlannerError("invalid_interval")
        rule["interval"] = int(kv["INTERVAL"])
    if "BYDAY" in kv:
        if freq != "WEEKLY":
            raise PlannerError("byday_needs_weekly")
        days = kv["BYDAY"].split(",")
        if any(x not in WD for x in days) or len(set(days)) != len(days):
            raise PlannerError("invalid_byday")
        rule["byday"] = sorted(days, key=WD.index)
    if "BYMONTHDAY" in kv:
        if freq != "MONTHLY":
            raise PlannerError("bymonthday_needs_monthly")
        vals = kv["BYMONTHDAY"].split(",")
        if any(not re.fullmatch(r"-1|[1-9]|[12][0-9]|3[01]", x) for x in vals) or len(set(vals)) != len(vals):
            raise PlannerError("invalid_bymonthday")
        rule["bymonthday"] = sorted((int(x) for x in vals), key=lambda n: (n < 0, n))
    if "COUNT" in kv:
        if not re.fullmatch(r"[1-9][0-9]{0,2}|1000", kv["COUNT"]):
            raise PlannerError("invalid_count")
        rule["count"] = int(kv["COUNT"])
    if "UNTIL" in kv:
        try:
            if not re.fullmatch(r"\d{8}T\d{6}Z", kv["UNTIL"]):
                raise ValueError
            rule["until"] = dt.datetime.strptime(kv["UNTIL"], "%Y%m%dT%H%M%SZ").replace(tzinfo=UTC)
        except ValueError:
            raise PlannerError("invalid_until")
    if rule["count"] is not None and rule["until"] is not None:
        raise PlannerError("count_and_until")
    return rule


def serialize_rrule(rule):
    parts = ["FREQ=" + rule["freq"]]
    if rule["interval"] > 1:
        parts.append("INTERVAL=%d" % rule["interval"])
    if rule["byday"]:
        parts.append("BYDAY=" + ",".join(sorted(rule["byday"], key=WD.index)))
    if rule["bymonthday"]:
        parts.append("BYMONTHDAY=" + ",".join(str(n) for n in sorted(rule["bymonthday"], key=lambda n: (n < 0, n))))
    if rule["count"] is not None:
        parts.append("COUNT=%d" % rule["count"])
    if rule["until"] is not None:
        parts.append("UNTIL=" + rule["until"].strftime("%Y%m%dT%H%M%SZ"))
    return ";".join(parts)


def canonical(s):
    return serialize_rrule(parse_rrule(s))


# ---------------------------------------------------------------- expansion
def _add_months(y, m, k):
    idx = y * 12 + (m - 1) + k
    return idx // 12, idx % 12 + 1


def _last_day(y, m):
    return (dt.date(y + (m == 12), m % 12 + 1, 1) - dt.timedelta(days=1)).day


def candidates(rule, d0):
    """Local dates of the rule in ascending order, never before d0. DTSTART must match the rule (the app guarantees it)."""
    n = rule["interval"]
    if rule["freq"] == "DAILY":
        k = 0
        while k < MAX_ITERATIONS:
            yield d0 + dt.timedelta(days=k * n)
            k += 1
    elif rule["freq"] == "WEEKLY":
        days = sorted(WD.index(x) for x in rule["byday"]) or [d0.weekday()]
        week0 = d0 - dt.timedelta(days=d0.weekday())
        w = 0
        while w < MAX_ITERATIONS:
            base = week0 + dt.timedelta(weeks=w * n)
            for wd in days:
                d = base + dt.timedelta(days=wd)
                if d >= d0:
                    yield d
            w += 1
    else:
        wanted = rule["bymonthday"] or [d0.day]
        k = 0
        while k < MAX_ITERATIONS:
            y, m = _add_months(d0.year, d0.month, k * n)
            last = _last_day(y, m)
            resolved = sorted({last if x == -1 else x for x in wanted if (x == -1 or x <= last)})
            for day in resolved:
                d = dt.date(y, m, day)
                if d >= d0:
                    yield d
            k += 1


def expand(rule_str, start_local, zone, duration_min, frm, to, skips=(), overrides=()):
    """Occurrences whose (effective) start lies in [frm, to). `skips` are original start instants removed from the series;
    `overrides` replace one occurrence by another start and end. COUNT counts every generated occurrence, skipped or not."""
    rule = parse_rrule(rule_str)
    tz = ZoneInfo(zone)
    day, hm = start_local.split("T")
    d0 = dt.date.fromisoformat(day)
    hour, minute = (int(x) for x in hm.split(":"))
    frm_dt, to_dt = parse_iso(frm), parse_iso(to)
    skip_set = set(skips)
    ov = {o["original"]: o for o in overrides}
    limit = max([to_dt] + [parse_iso(k) for k in ov])
    out, n = [], 0
    for d in candidates(rule, d0):
        s_utc = local_to_utc(tz, d, hour, minute)
        if rule["until"] is not None and s_utc > rule["until"]:
            break
        n += 1
        if rule["count"] is not None and n > rule["count"]:
            break
        if s_utc > limit or n > MAX_ITERATIONS:
            break
        key = iso(s_utc)
        if key in skip_set:
            continue
        if key in ov:
            s, e, flag = parse_iso(ov[key]["start"]), parse_iso(ov[key]["end"]), True
        else:
            s, e, flag = s_utc, s_utc + dt.timedelta(minutes=duration_min), False
        if frm_dt <= s < to_dt:
            item = {"s": iso(s), "e": iso(e)}
            if flag:
                item["o"] = True
            out.append(item)
    out.sort(key=lambda x: x["s"])
    return out


def split_series(rule_str, start_local, zone, split_iso):
    """Edit 'this and following': end the old series just before the chosen occurrence and start a new one at it."""
    rule = parse_rrule(rule_str)
    tz = ZoneInfo(zone)
    day, hm = start_local.split("T")
    d0 = dt.date.fromisoformat(day)
    hour, minute = (int(x) for x in hm.split(":"))
    split_dt = parse_iso(split_iso)
    before, found = 0, False
    for idx, d in enumerate(candidates(rule, d0)):
        s_utc = local_to_utc(tz, d, hour, minute)
        if rule["until"] is not None and s_utc > rule["until"]:
            break
        if rule["count"] is not None and idx + 1 > rule["count"]:
            break
        if s_utc == split_dt:
            found = True
            break
        if s_utc > split_dt or idx >= MAX_ITERATIONS:
            break
        before += 1
    if not found:
        raise PlannerError("not_an_occurrence")
    if before == 0:
        raise PlannerError("split_at_first")
    first, second = dict(rule), dict(rule)
    if rule["count"] is not None:
        first["count"], second["count"] = before, rule["count"] - before
    else:
        first["until"] = split_dt - dt.timedelta(seconds=1)
    return {"first": serialize_rrule(first), "second": serialize_rrule(second), "secondStartUtc": iso(split_dt)}


# ---------------------------------------------------------------- conflicts and free time (minutes of a day)
def conflicts(intervals):
    for a, b in intervals:
        if b <= a:
            raise PlannerError("invalid_interval")
    out = []
    for i in range(len(intervals)):
        for j in range(i + 1, len(intervals)):
            (a1, b1), (a2, b2) = intervals[i], intervals[j]
            if a1 < b2 and a2 < b1:
                out.append([i, j])
    return out


def free_slots(win_start, win_end, busy, min_len, max_len, buffer):
    if min_len > max_len or min_len <= 0 or win_end <= win_start or buffer < 0:
        raise PlannerError("invalid_range")
    expanded = sorted((max(win_start, a - buffer), min(win_end, b + buffer)) for a, b in busy if b > win_start and a < win_end)
    merged = []
    for a, b in expanded:
        if merged and a <= merged[-1][1]:
            merged[-1] = (merged[-1][0], max(merged[-1][1], b))
        else:
            merged.append((a, b))
    gaps, cursor = [], win_start
    for a, b in merged:
        if a > cursor:
            gaps.append((cursor, a))
        cursor = max(cursor, b)
    if cursor < win_end:
        gaps.append((cursor, win_end))
    return [[a, a + min(b - a, max_len)] for a, b in gaps if b - a >= min_len]


def duration_hint(minutes, lo=150, hi=240):
    """Soft planning hint only. Users can create any duration."""
    return "short" if minutes < lo else ("long" if minutes > hi else "within")


# ---------------------------------------------------------------- class links
MEETING_MAX = 500


def validate_meeting_url(url):
    u = rv.trim_ws(url)
    if u == "":
        return {"code": "blank"}
    if len(u) > MEETING_MAX:
        return {"code": "too_long"}
    if re.search(r"[\s\x00-\x1f\x7f-\x9f]", u):
        return {"code": "invalid_url"}
    m = re.fullmatch(r"([A-Za-z][A-Za-z0-9+.-]*):(.*)", u, re.S)
    if not m or m.group(1).lower() != "https":
        return {"code": "not_https"}
    rest = m.group(2)
    if not rest.startswith("//"):
        return {"code": "invalid_url"}
    rest = rest[2:]
    slash = rest.find("/")
    authority, path = (rest, "") if slash == -1 else (rest[:slash], rest[slash:])
    if re.search(r"[?#]", authority):
        return {"code": "invalid_url"}
    if "@" in authority:
        return {"code": "credentials"}
    if authority.startswith("["):
        return {"code": "ip_host"}
    host, port = authority, None
    if ":" in authority:
        host, port = authority.rsplit(":", 1)
        if not re.fullmatch(r"[0-9]{1,5}", port) or not (1 <= int(port) <= 65535):
            return {"code": "invalid_url"}
    host = host.lower()
    if any(ord(c) > 127 for c in host):
        return {"code": "invalid_host"}
    if re.fullmatch(r"[0-9]{1,3}(\.[0-9]{1,3}){3}", host):
        return {"code": "ip_host"}
    if not re.fullmatch(r"[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+", host):
        return {"code": "invalid_host"}
    if host == "zoom.us" or host.endswith(".zoom.us"):
        provider = "zoom"
    elif host == "meet.google.com":
        provider = "meet"
    elif host in ("teams.microsoft.com", "teams.live.com"):
        provider = "teams"
    else:
        provider = "other"
    return {"code": "ok", "provider": provider, "normalized": "https://" + host + (":" + port if port else "") + path}


# ---------------------------------------------------------------- reminders
def plan_reminders(starts, offsets, now_iso, zone, quiet=None):
    """Fire times (UTC) for reminders: start minus each offset. Past ones are dropped. A reminder that would fire inside quiet
    hours (local minutes-of-day [start, end), may wrap midnight) moves to the end of quiet hours, but only if that is still
    before the event starts."""
    tz = ZoneInfo(zone)
    now = parse_iso(now_iso)
    out = []
    for s_iso in starts:
        s = parse_iso(s_iso)
        for off in sorted(set(offsets), reverse=True):
            fire = s - dt.timedelta(minutes=off)
            if fire <= now:
                continue
            shifted = False
            if quiet and quiet[0] != quiet[1]:
                loc = fire.astimezone(tz)
                m = loc.hour * 60 + loc.minute
                qs, qe = quiet
                inside = (qs <= m < qe) if qs < qe else (m >= qs or m < qe)
                if inside:
                    end_day = loc.date() if (qs < qe or m < qe) else loc.date() + dt.timedelta(days=1)
                    fire = local_to_utc(tz, end_day, qe // 60, qe % 60)
                    shifted = True
                    if fire >= s or fire <= now:
                        continue
            out.append({"event": s_iso, "fire": iso(fire), "shifted": shifted})
    out.sort(key=lambda r: (r["fire"], r["event"]))
    return out

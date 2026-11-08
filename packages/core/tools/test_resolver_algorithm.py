"""Validates the ALGORITHM of the Dart OffsetZoneResolver (packages/core/lib/src/planner/zone.dart) without Dart:
a line-for-line Python port, driven by the real zone database's UTC offsets, is compared minute by minute with the reference
(zoneinfo fold=0 semantics) around every 2026 clock change in several zones, then used to re-run the DST vectors."""
import datetime as dt, json, os, sys
from zoneinfo import ZoneInfo

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import planner_reference as pr

MIN, DAY = 60000, 86400000
UTC = dt.timezone.utc
results = []

def check(name, cond, detail=""):
    results.append(bool(cond)); print(("PASS  " if cond else "FAIL  ") + name + (f"   [{str(detail)[:500]}]" if (detail and not cond) else ""))


class OffsetZoneResolverPort:
    """Port of zone.dart. `offset_minutes_at(ms)` is the only primitive."""
    def __init__(self, offset_minutes_at):
        self.f = offset_minutes_at

    def local_to_utc_ms(self, y, mo, d, h, mi):
        as_utc = int(dt.datetime(y, mo, d, h, mi, tzinfo=UTC).timestamp() * 1000)
        before, after = self.f(as_utc - DAY), self.f(as_utc + DAY)
        valid = []
        for off in {before, after}:
            utc = as_utc - off * MIN
            if self.f(utc) == off:
                valid.append(utc)
        if not valid:
            return as_utc - before * MIN
        valid.sort()
        return valid[0]


def lookup_for(zone):
    tz = ZoneInfo(zone)
    return lambda ms: int(dt.datetime.fromtimestamp(ms / 1000, tz).utcoffset().total_seconds() // 60)


ZONES = ["Asia/Colombo", "Europe/London", "America/New_York", "Australia/Sydney", "Australia/Lord_Howe", "Asia/Kathmandu", "Pacific/Auckland", "UTC"]
total = mismatches = transitions_seen = 0
first_bad = None
for zone in ZONES:
    f = lookup_for(zone); port = OffsetZoneResolverPort(f); tz = ZoneInfo(zone)
    # find the instants in 2026 where the offset changes (scan hourly, then refine to the minute)
    start = int(dt.datetime(2026, 1, 1, tzinfo=UTC).timestamp() * 1000)
    end = int(dt.datetime(2027, 1, 1, tzinfo=UTC).timestamp() * 1000)
    changes, prev = [], f(start)
    t = start + 3600000
    while t < end:
        cur = f(t)
        if cur != prev:
            lo, hi = t - 3600000, t
            while hi - lo > MIN:
                mid = (lo + hi) // 2
                lo, hi = (mid, hi) if f(mid) == prev else (lo, mid)
            changes.append(hi); prev = cur
        t += 3600000
    transitions_seen += len(changes)
    for c in changes:                     # every local minute within +-36 hours of the change
        base = dt.datetime.fromtimestamp(c / 1000, UTC) - dt.timedelta(hours=36)
        for k in range(0, 72 * 60 + 1):
            local = (base + dt.timedelta(minutes=k)).replace(tzinfo=None)
            want = dt.datetime(local.year, local.month, local.day, local.hour, local.minute).replace(tzinfo=tz, fold=0).astimezone(UTC)
            got = port.local_to_utc_ms(local.year, local.month, local.day, local.hour, local.minute)
            total += 1
            if got != int(want.timestamp() * 1000):
                mismatches += 1
                first_bad = first_bad or (zone, str(local), dt.datetime.fromtimestamp(got / 1000, UTC).isoformat(), want.isoformat())
# Counted by hand: London, New York, Sydney, Lord Howe and Auckland each change clocks twice in 2026 (10 changes); Colombo, Kathmandu and UTC never do.
# Each window is 72 hours of minutes, endpoints included: 72 * 60 + 1 = 4321.
check(f"the Dart resolver algorithm equals the reference for every local minute around every 2026 clock change ({total} minutes, {transitions_seen} changes, {len(ZONES)} zones)", mismatches == 0 and transitions_seen == 10 and total == 10 * 4321, (first_bad, transitions_seen, total))
check("gaps and overlaps were both exercised (a spring-forward and a fall-back in the same year for London)", any(z == "Europe/London" for z in ZONES) and transitions_seen == 10)

# Re-run the vectors with the ported resolver standing in for zoneinfo
V = json.load(open(os.path.join(HERE, "..", "..", "..", "test-vectors", "planner.json"), encoding="utf-8"))
def patched_local_to_utc(tz, d, hour, minute):
    port = OffsetZoneResolverPort(lookup_for(tz.key))
    return dt.datetime.fromtimestamp(port.local_to_utc_ms(d.year, d.month, d.day, hour, minute) / 1000, UTC)
original = pr.local_to_utc
pr.local_to_utc = patched_local_to_utc
try:
    bad = [c["name"] for c in V["expand"] if pr.expand(c["rule"], c["start"], c["zone"], c["durationMin"], c["from"], c["to"], c["skip"], c["override"]) != c["expect"]]
    check("every expand vector (including both daylight-saving cases) passes with the ported Dart resolver", not bad, bad)
    bad = [c["name"] for c in V["reminders"] if pr.plan_reminders(c["starts"], c["offsets"], c["now"], c["zone"], c.get("quiet")) != c["expect"]]
    check("every reminder vector passes with the ported Dart resolver", not bad, bad)
finally:
    pr.local_to_utc = original

# Synthetic offsets used by the Dart unit tests (no zone database)
spring = int(dt.datetime(2026, 3, 29, 1, tzinfo=UTC).timestamp() * 1000)
fall = int(dt.datetime(2026, 10, 25, 1, tzinfo=UTC).timestamp() * 1000)
fwd, back = OffsetZoneResolverPort(lambda ms: 0 if ms < spring else 60), OffsetZoneResolverPort(lambda ms: 60 if ms < fall else 0)
iso = lambda ms: dt.datetime.fromtimestamp(ms / 1000, UTC).strftime("%Y-%m-%dT%H:%M:%SZ")
check("the synthetic cases in the Dart unit test give the values the test expects",
      iso(fwd.local_to_utc_ms(2026, 3, 29, 1, 30)) == "2026-03-29T01:30:00Z" and iso(fwd.local_to_utc_ms(2026, 3, 29, 0, 30)) == "2026-03-29T00:30:00Z"
      and iso(fwd.local_to_utc_ms(2026, 3, 29, 2, 30)) == "2026-03-29T01:30:00Z" and iso(back.local_to_utc_ms(2026, 10, 25, 1, 30)) == "2026-10-25T00:30:00Z"
      and iso(back.local_to_utc_ms(2026, 10, 25, 0, 30)) == "2026-10-24T23:30:00Z" and iso(back.local_to_utc_ms(2026, 10, 25, 2, 30)) == "2026-10-25T02:30:00Z")

print(f"\n{sum(results)} passed, {len(results) - sum(results)} failed")
sys.exit(0 if all(results) else 1)

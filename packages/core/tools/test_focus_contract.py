"""Contract tests: hand-written focus vectors <-> Python reference, plus property checks. The same vectors are loaded by the Dart test
and turned into pgTAP assertions for the SQL functions (gen_focus_pgtap.py), so the database is held to the same numbers."""
import datetime as dt, json, os, random, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
import focus_reference as fr
V = json.load(open(os.path.join(ROOT, "test-vectors", "focus.json"), encoding="utf-8"))
results = []

def check(name, cond, detail=""):
    results.append(bool(cond)); print(("PASS  " if cond else "FAIL  ") + name + (f"   [{str(detail)[:500]}]" if (detail and not cond) else ""))

check("vectors file is up to date with its generator", subprocess.run([sys.executable, os.path.join(HERE, "make_focus_vectors.py"), "--check"], capture_output=True).returncode == 0)
bad = [(c["name"], fr.validated_seconds(c["planned"], c["started"], c["ended"], c["paused"], c["reported"], c["received"]), c["expect"]) for c in V["validated"]
       if fr.validated_seconds(c["planned"], c["started"], c["ended"], c["paused"], c["reported"], c["received"]) != c["expect"]]
check(f"{len(V['validated'])} validated-seconds vectors", not bad, bad[:3])
bad = [(c["validated"], fr.tree_stage(c["validated"]), fr.is_counted(c["validated"])) for c in V["tree"] if fr.tree_stage(c["validated"]) != c["stage"] or fr.is_counted(c["validated"]) != c["counted"]]
check(f"{len(V['tree'])} tree-stage and counted vectors", not bad, bad[:3])
bad = [(c["name"], fr.streak(c["days"], c["today"], c["goal"]), (c["streak"], c["rest_days"])) for c in V["streak"] if fr.streak(c["days"], c["today"], c["goal"]) != {"streak": c["streak"], "rest_days": c["rest_days"]}]
check(f"{len(V['streak'])} streak vectors", not bad, bad[:3])
bad = [(c["name"], fr.longest_streak(c["days"], c["goal"]), c["expect"]) for c in V["longest"] if fr.longest_streak(c["days"], c["goal"]) != c["expect"]]
check(f"{len(V['longest'])} longest-streak vectors", not bad, bad[:3])
bad = [(c["name"], fr.achievements(c["sessions"], c["total_seconds"], c["longest"])) for c in V["achievements"] if fr.achievements(c["sessions"], c["total_seconds"], c["longest"]) != c["expect"]]
check(f"{len(V['achievements'])} achievement vectors", not bad, bad[:3])

K = V["constants"]
check("constants in the vectors equal the constants in the reference", (K["skewSeconds"], K["staleDays"], K["overrunSeconds"], K["maxSessionSeconds"], K["countedMinSeconds"], K["restDaySpacing"], K["defaultGoalSeconds"]) ==
      (fr.SKEW_SECONDS, fr.STALE_DAYS, fr.OVERRUN_SECONDS, fr.MAX_SESSION_SECONDS, fr.COUNTED_MIN_SECONDS, fr.REST_DAY_SPACING, fr.DEFAULT_GOAL_SECONDS) and
      [[f, n] for f, n in sorted(fr.TREE_STAGES)] == K["treeStages"])
check("the achievement order is canonical", fr.ACHIEVEMENT_ORDER == ["first_session", "sessions_25", "hours_10", "hours_50", "streak_3", "streak_7", "streak_30"])


# ---- SQL parity: every constant in the migration equals the reference and the vectors
import re
sql = open(os.path.join(ROOT, "backend/supabase/migrations/20261019000000_focus.sql"), encoding="utf-8").read()
check("generated pgTAP file 050_focus_rules.test.sql is up to date", subprocess.run([sys.executable, os.path.join(HERE, "gen_focus_pgtap.py"), "--check"], capture_output=True).returncode == 0)
check("SQL parity: skew, stale window, overrun and the 8-hour cap",
      f"interval '{K['skewSeconds']} seconds'" in sql and f"interval '{K['staleDays']} days'" in sql and f"p_planned + {K['overrunSeconds']}" in sql and f"{K['maxSessionSeconds']}::bigint" in sql)
check("SQL parity: the counted threshold", f"p_validated >= {K['countedMinSeconds']}; " in sql or f"p_validated >= {K['countedMinSeconds']};" in sql)
stages = sorted([int(a), b] for a, b in re.findall(r"when p_validated >= (\d+) then '(\w+)'", sql))
check("SQL parity: tree stage thresholds and names", stages == sorted(K["treeStages"]), stages)
check("SQL parity: the rest-day spacing, the scan guard and the default goal", f"last_forgiven - d >= {K['restDaySpacing']}" in sql and "guard > 4000" in sql and fr.MAX_SCAN_DAYS == 4000
      and f"focus_longest_streak_from(v_days, v_secs, {K['defaultGoalSeconds']})" in sql)
triples = re.findall(r"case when p_(sessions|total|longest) >= (\d+) then '(\w+)' end", sql)
bad = []
for param, n, kind in triples:
    n = int(n)
    def earned(value):
        args = {"sessions": 0, "total": 0, "longest": 0}; args[param] = value
        return kind in fr.achievements(args["sessions"], args["total"], args["longest"])
    if not earned(n) or earned(n - 1): bad.append((kind, param, n))
check("SQL parity: every badge threshold is exactly the reference's (earned at N, not at N-1)", len(triples) == 7 and not bad and [k for _, _, k in triples] == fr.ACHIEVEMENT_ORDER, (triples, bad))
m = re.search(r"achievements_kind_chk check \(kind in \(([^)]*)\)\)", sql)
check("SQL parity: the allowed badge kinds are the reference's, in order", m and [x.strip().strip("'") for x in m.group(1).split(",")] == fr.ACHIEVEMENT_ORDER)
m = re.search(r"study_sessions_tree_chk check \(tree in \(([^)]*)\)\)", sql)
check("SQL parity: the allowed tree values are 'none' plus the stages", m and [x.strip().strip("'") for x in m.group(1).split(",")] == ["none"] + [n for _, n in sorted(fr.TREE_STAGES)])
check("SQL: server-computed columns are not in any client grant", "validated_s" not in re.search(r"grant insert \(([^)]*)\) on public.study_sessions", sql).group(1) and "counted" not in re.search(r"grant insert \(([^)]*)\) on public.study_sessions", sql).group(1)
      and "received_at" not in re.search(r"grant insert \(([^)]*)\) on public.study_sessions", sql).group(1) and "tree" not in re.search(r"grant insert \(([^)]*)\) on public.study_sessions", sql).group(1))
check("SQL: no client can write or change a session or a badge (no update, delete or achievements insert grant)", not re.search(r"grant (update|delete)[^;]*on public\.(study_sessions|achievements)", sql) and not re.search(r"grant insert[^;]*on public\.achievements", sql))

# ---- properties over random inputs (deterministic seed)
rng = random.Random(20261018)
fails = []
base = dt.datetime(2026, 10, 17, 10, 0, 0)
f = lambda d: d.strftime("%Y-%m-%dT%H:%M:%SZ")
for _ in range(3000):
    planned = rng.choice([60, 600, 1500, 3000, 28800]); elapsed = rng.randint(1, 40000); paused = rng.randint(-50, 5000); reported = rng.randint(-50, 40000)
    end = base + dt.timedelta(seconds=elapsed); recv = end + dt.timedelta(seconds=rng.randint(-400, 100))
    v = fr.validated_seconds(planned, f(base), f(end), paused, reported, f(recv))
    if v < 0 or v > max(reported, 0) or v > elapsed or v > planned + 300 or v > 28800: fails.append(("bounds", planned, elapsed, paused, reported, v))
    v2 = fr.validated_seconds(planned, f(base), f(end), paused, reported + 100, f(recv))
    if v2 < v: fails.append(("more reported never earns less", v, v2))
    v3 = fr.validated_seconds(planned, f(base), f(end), paused + 100, reported, f(recv))
    if v3 > v: fails.append(("more pause never earns more", v, v3))
check("3000 random sessions: validated seconds are within every bound, never fall when more is reported, never rise when more is paused", not fails, fails[:3])

fails = []
today = dt.date(2026, 10, 20)
for _ in range(600):
    days = [[(today - dt.timedelta(days=k)).isoformat(), rng.choice([0, 600, 1799, 1800, 2400])] for k in range(rng.randint(0, 60)) if rng.random() < 0.7]
    s = fr.streak(days, today.isoformat()); L = fr.longest_streak(days)
    met_days = {d for d, secs in days if secs >= 1800}
    if s["streak"] > L: fails.append(("current <= longest", days, s, L))
    if s["streak"] > len({d for d, secs in days if secs >= 1800}) : fails.append(("streak <= met days", s))
    if s["rest_days"] > (s["streak"] + s["rest_days"]) // 7 + 1: fails.append(("rest days are rare", s))
    run = best = 0
    for k in range(80, -1, -1):
        d = (today - dt.timedelta(days=k)).isoformat()
        run = run + 1 if any(dd == d and sec >= 1800 for dd, sec in [(a, sum(b for c, b in days if c == a)) for a in {x for x, _ in days}]) else 0
        best = max(best, run)
    if L < best: fails.append(("longest >= plain run", L, best))
    extra = days + [[(today - dt.timedelta(days=rng.randint(0, 59))).isoformat(), 3000]]
    if fr.longest_streak(extra) < L: fails.append(("adding a met day never shortens the longest streak", days))
check("600 random histories: current <= longest, streak <= met days, rest days are rare, longest >= the plain run, adding a met day never shortens it", not fails, fails[:2])

print(f"\n{sum(results)} passed, {len(results) - sum(results)} failed")
sys.exit(0 if all(results) else 1)

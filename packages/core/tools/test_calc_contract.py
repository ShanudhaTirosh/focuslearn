"""Contract tests: hand-verified calculator vectors <-> Python reference, plus property checks.
The same vectors are loaded by the Dart test (packages/core/test/calculators_test.dart)."""
import json, os, random, subprocess, sys
from fractions import Fraction as F

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
import calc_reference as cr
D = json.load(open(os.path.join(ROOT, "test-vectors", "calculators.json"), encoding="utf-8"))
results = []

def check(name, cond, detail=""):
    results.append(bool(cond)); print(("PASS  " if cond else "FAIL  ") + name + (f"   [{str(detail)[:500]}]" if (detail and not cond) else ""))

check("vectors file is up to date with its generator", subprocess.run([sys.executable, os.path.join(HERE, "make_calc_vectors.py"), "--check"], capture_output=True).returncode == 0)

def call(c):
    try:
        return getattr(cr, c["fn"])(*c["args"]), None
    except cr.CalcError as e:
        return None, e.code

bad_out, bad_steps, bad_err, no_steps = [], [], [], []
for c in D["cases"]:
    got, code = call(c)
    if "error" in c:
        if code != c["error"]:
            bad_err.append((c["fn"], c["name"], code, c["error"]))
        continue
    if code is not None:
        bad_out.append((c["fn"], c["name"], "raised " + code)); continue
    for k, v in c["out"].items():
        if got.get(k) != v:
            bad_out.append((c["fn"], c["name"], k, got.get(k), v))
    if "steps" in c and got["steps"] != c["steps"]:
        bad_steps.append((c["fn"], c["name"], got["steps"], c["steps"]))
    if not (isinstance(got.get("steps"), list) and len(got["steps"]) >= 2 and got.get("formula")):
        no_steps.append((c["fn"], c["name"]))
n_err = sum("error" in c for c in D["cases"]); n_ok = len(D["cases"]) - n_err
check(f"{n_ok} successful vectors: every listed result matches", not bad_out, bad_out[:4])
check(f"{n_err} error vectors: every error code matches", not bad_err, bad_err[:4])
check("steps vectors: the exact step text matches", not bad_steps, bad_steps[:2])
check("every successful result shows a formula id and at least two steps", not no_steps, no_steps[:3])
check("every calculator function is covered by vectors", {c["fn"] for c in D["cases"]} == {"percent_of", "percent_what", "percent_change", "percent_increase", "percent_decrease", "ratio_simplify", "ratio_split", "proportion", "profit_loss", "selling_from_markup", "selling_from_margin", "simple_interest", "compound_interest", "break_even", "accounting_equation", "statistics", "convert", "evaluate"})
codes = {c["error"] for c in D["cases"] if "error" in c}
check("a rich set of error codes is exercised", len(codes) >= 25, sorted(codes))

# ---- rounding rule
check("rounding: exact halves go AWAY from zero (0.125 -> 0.13, -0.125 -> -0.13, 2.5 -> 3, -2.5 -> -3)", [cr.fixed(F(125, 1000)), cr.fixed(F(-125, 1000)), cr.fixed(F(5, 2), 0), cr.fixed(F(-5, 2), 0)] == ["0.13", "-0.13", "3", "-3"])
check("rounding: just below a half goes down (0.12499999 -> 0.12)", cr.fixed(F(12499999, 10 ** 8)) == "0.12")
check("rounding: never a negative zero", all(cr.fixed(F(-1, 10 ** k)) == "0.00" for k in (3, 4, 9)) and cr.trimmed(F(-1, 10 ** 12)) == "0")
check("trimmed: no trailing zeros and no trailing point", [cr.trimmed(F(5, 2)), cr.trimmed(F(100)), cr.trimmed(F(1, 8))] == ["2.5", "100", "0.125"])

# ---- exactness properties (deterministic pseudo-random inputs)
rng = random.Random(20261018)
def dec(max_int=10000, dp=2): return f"{rng.randint(0, max_int)}.{rng.randint(0, 10 ** dp - 1):0{dp}d}"
fails = []
for _ in range(300):
    a, b = dec(), dec()
    if cr.evaluate(f"{a}+{b}")["result"] != cr.evaluate(f"{b}+{a}")["result"]: fails.append(("commutative +", a, b))
    if cr.evaluate(f"({a})+({b})")["result"] != cr.evaluate(f"{a}+{b}")["result"]: fails.append(("brackets", a, b))
    if F(b) != 0 and cr.evaluate(f"{a}*{b}/{b}")["result"] != cr.trimmed(F(a)): fails.append(("a*b/b", a, b))
    if cr.evaluate(f"{a}-{a}")["result"] != "0": fails.append(("a-a", a))
    if cr.evaluate(f"{a}+{b}")["result"] != cr.trimmed(F(a) + F(b)): fails.append(("sum exact", a, b))
check("300 random sums, products and quotients are exact and consistent (no floating point drift)", not fails, fails[:3])

fails = []
for _ in range(400):
    amount = f"{rng.randint(0, 100000)}.{rng.randint(0, 99):02d}"
    parts = [str(rng.randint(0, 9)) for _ in range(rng.randint(2, 6))]
    if sum(map(int, parts)) == 0: continue
    shares = cr.ratio_split(amount, parts)["shares"]
    if sum(F(s) for s in shares) != F(amount): fails.append(("sum", amount, parts, shares))
    exact = [F(amount) * int(p) / sum(map(int, parts)) for p in parts]
    if any(abs(F(s) - e) >= F(1, 100) for s, e in zip(shares, exact)): fails.append(("within a cent", amount, parts, shares))
    if any(F(s) < 0 for s in shares): fails.append(("negative", amount, parts))
check("400 random splits: the shares always add up to EXACTLY the amount, each within one cent of its exact share, never negative", not fails, fails[:3])

fails = []
for _ in range(200):
    p, r, t = dec(100000), dec(30, 2), str(rng.randint(0, 20))
    si = cr.simple_interest(p, r, t)
    if abs(F(si["amount"]) - F(si["interest"]) - F(p)) > F(1, 100): fails.append(("amount - interest = principal", p, r, t))
    if cr.compound_interest(p, "0", "12", "3")["amount"] != cr.fixed(F(p)): fails.append(("0% compound", p))
    n, yrs = rng.choice([1, 2, 4, 12]), rng.randint(1, 5)
    ci = cr.compound_interest(p, r, str(n), str(yrs))
    if F(ci["amount"]) < F(p) - F(1, 100): fails.append(("compounding never loses money", p, r, n, yrs))
    if cr.compound_interest(p, r, "1", "1")["amount"] != cr.simple_interest(p, r, "1")["amount"]: fails.append(("one year, yearly: compound equals simple", p, r))
    if F(r) > 0 and F(p) >= 100 and yrs >= 2 and n == 1 and F(cr.compound_interest(p, r, "1", str(yrs))["amount"]) < F(cr.simple_interest(p, r, str(yrs))["amount"]): fails.append(("compound >= simple after 2+ years", p, r, yrs))
check("200 random interest cases: amount - interest = principal, 0% leaves the principal, compounding never loses money, one year yearly equals simple, compound beats simple over 2+ years", not fails, fails[:3])

# A price rounded to a cent shifts the recovered percent by at most 0.5 / price (percent units), plus 0.01 for rounding the percent itself.
fails = []
for _ in range(200):
    cost, markup = f"{rng.randint(1, 5000)}.{rng.randint(0, 99):02d}", str(rng.randint(0, 200))
    sp = cr.selling_from_markup(cost, markup)["selling"]
    pl = cr.profit_loss(cost, sp)
    if abs(F(pl["percent_on_cost"]) - F(markup)) > F(1, 2) / F(cost) + F(1, 100): fails.append(("markup round trip", cost, markup, sp, pl["percent_on_cost"]))
    m = str(rng.randint(0, 90))
    sp2 = cr.selling_from_margin(cost, m)["selling"]
    if abs(F(cr.profit_loss(cost, sp2)["percent_on_selling"]) - F(m)) > F(1, 2) / F(sp2) + F(1, 100): fails.append(("margin round trip", cost, m, sp2))
check("200 random price cases: a markup (or margin) turned into a price and back gives the percent asked for, within the one-cent rounding bound", not fails, fails[:3])

fails = []
for _ in range(200):
    v = dec(100000, 2)
    for a, b in [("m", "cm"), ("km", "m"), ("kg", "g"), ("l", "ml"), ("ha", "m2"), ("h", "min"), ("day", "h"), ("t", "kg")]:
        if cr.convert(cr.convert(v, a, b)["result"], b, a)["result"] != cr.trimmed(F(v)): fails.append(("round trip", v, a, b))
for c in range(-100, 301, 5):
    f_ = cr.convert(str(c), "c", "f")["result"]
    if cr.convert(f_, "f", "c")["result"] != str(c) and c != 0 or (c == 0 and cr.convert(f_, "f", "c")["result"] != "0"): fails.append(("temperature", c))
check("200 random values x 8 metric pairs and 81 temperatures round-trip exactly", not fails, fails[:3])

fails = []
for _ in range(200):
    n = rng.randint(1, 12); vals = [dec(1000, 1) for _ in range(n)]
    s = cr.statistics(vals, 4)
    if abs(F(s["mean"]) * n - F(s["sum"])) > F(n, 10 ** 4): fails.append(("mean*n=sum", vals))
    if F(s["min"]) > F(s["median"]) or F(s["median"]) > F(s["max"]): fails.append(("order", vals))
    if F(s["pop_variance"]) < 0 or (n >= 2 and F(s["sample_variance"]) < F(s["pop_variance"]) - F(1, 10 ** 4)): fails.append(("variance", vals))
    if abs(F(s["pop_stdev"]) ** 2 - F(s["pop_variance"])) > F(1, 100) * max(1, F(s["pop_stdev"])): fails.append(("stdev^2", vals, s["pop_stdev"], s["pop_variance"]))
check("200 random data sets: mean x count = sum, min <= median <= max, variances are consistent, stdev squared is the variance", not fails, fails[:3])

print(f"\n{sum(results)} passed, {len(results) - sum(results)} failed")
sys.exit(0 if all(results) else 1)

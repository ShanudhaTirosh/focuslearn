"""Validates the semantics of the Dart Rational helpers (packages/core/lib/src/calc/rational.dart) without Dart.
Dart's BigInt `~/` TRUNCATES toward zero while Python's `//` FLOORS; Dart's `%` is Euclidean. A Python port that emulates Dart's
operators exactly is compared with the reference on thousands of values, negatives and very large numbers included."""
import math, os, random, re, sys
from fractions import Fraction as F

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import calc_reference as cr
results = []

def check(name, cond, detail=""):
    results.append(bool(cond)); print(("PASS  " if cond else "FAIL  ") + name + (f"   [{str(detail)[:400]}]" if (detail and not cond) else ""))

def tdiv(a, b):                      # Dart BigInt ~/ : truncate toward zero
    q = abs(a) // abs(b)
    return q if (a < 0) == (b < 0) else -q

def emod(a, b):                      # Dart BigInt % : Euclidean, never negative for b > 0
    return a % abs(b)


class R:                             # port of the Rational class
    def __init__(self, n, d=1):
        assert d != 0
        if d < 0:
            n, d = -n, -d
        g = math.gcd(abs(n), d)
        if g > 1:
            n, d = tdiv(n, g), tdiv(d, g)
        self.n, self.d = n, d
    def __add__(s, o): return R(s.n * o.d + o.n * s.d, s.d * o.d)
    def __sub__(s, o): return R(s.n * o.d - o.n * s.d, s.d * o.d)
    def __mul__(s, o): return R(s.n * o.n, s.d * o.d)
    def __ge__(s, o): return s.n * o.d >= o.n * s.d
    def floor(s): return -tdiv(-s.n + s.d - 1, s.d) if s.n < 0 else tdiv(s.n, s.d)
    def ceil(s): return -tdiv(-s.n, s.d) if s.n < 0 else tdiv(s.n + s.d - 1, s.d)
    def to_fixed(s, scale):
        negative = s.n < 0
        a = abs(s.n) * 10 ** scale
        q = tdiv(a, s.d)
        r = a - q * s.d
        if r * 2 >= s.d:
            q += 1
        t = str(q).rjust(scale + 1, "0")
        out = t if scale == 0 else t[:len(t) - scale] + "." + t[len(t) - scale:]
        return ("-" if negative and q != 0 else "") + out
    def to_trimmed(s, max_scale=10):
        t = s.to_fixed(max_scale)
        if "." in t:
            t = re.sub(r"0+$", "", t, count=1); t = re.sub(r"\.$", "", t, count=1)
        return "0" if t in ("-0", "") else t
    def is_exact(s, max_scale=10): return emod(s.n * 10 ** max_scale, s.d) == 0
    def sqrt_fixed(s, scale):
        n = s * R(10 ** (2 * scale))
        t = integer_sqrt(n.floor())
        if n >= R(t * t + t) + R(1, 4):
            t += 1
        return R(t, 10 ** scale).to_fixed(scale)


def integer_sqrt(n):
    if n < 2:
        return n
    x = 1 << ((n.bit_length() + 1) // 2)
    while True:
        y = tdiv(x + tdiv(n, x), 2)
        if y >= x:
            return x
        x = y


rng = random.Random(20261018)
def rand_frac(big=False):
    n = rng.randint(-10 ** (30 if big else 6), 10 ** (30 if big else 6)); d = rng.randint(1, 10 ** (12 if big else 4))
    return n, d

bad = []
for i in range(4000):
    n, d = rand_frac(big=i % 4 == 0)
    r, f = R(n, d), F(n, d)
    if (r.n, r.d) != (f.numerator, f.denominator): bad.append(("normal form", n, d))
    if r.floor() != math.floor(f) or r.ceil() != math.ceil(f): bad.append(("floor/ceil", n, d, r.floor(), math.floor(f)))
    for scale in (0, 1, 2, 5, 8):
        if r.to_fixed(scale) != cr.fixed(f, scale): bad.append(("to_fixed", n, d, scale, r.to_fixed(scale), cr.fixed(f, scale)))
    if r.to_trimmed() != cr.trimmed(f): bad.append(("to_trimmed", n, d))
    if r.is_exact() != cr.is_exact(f): bad.append(("is_exact", n, d))
check("4000 random rationals (a quarter of them 30 digits, negatives included): normal form, floor, ceil, toFixed (5 scales), toTrimmed and isExact equal the reference", not bad, bad[:3])

bad = []
for i in range(3000):
    n, d = rand_frac(big=i % 5 == 0); f = F(abs(n), d)
    for scale in (0, 2, 4, 8):
        if R(abs(n), d).sqrt_fixed(scale) != cr._sqrt_fixed(f, scale): bad.append(("sqrt_fixed", abs(n), d, scale))
check("3000 random non-negative rationals x 4 scales: sqrtFixed equals the reference (integer Newton square root, exact half-up rounding)", not bad, bad[:3])

bad = [n for n in list(range(0, 2000)) + [rng.randint(0, 10 ** 60) for _ in range(2000)] + [k * k - 1 for k in (10, 10 ** 9, 10 ** 18 + 7)] + [k * k for k in (10, 10 ** 9, 10 ** 18 + 7)] if integer_sqrt(n) != math.isqrt(n)]
check("integerSqrt equals math.isqrt for 0..1999, 2000 random 60-digit numbers, and perfect squares and their predecessors", not bad, bad[:3])

check("the negative-number traps are real: truncating division differs from flooring, so the explicit floor/ceil in Dart matter", tdiv(-7, 2) == -3 and (-7) // 2 == -4 and emod(-7, 2) == 1)
check("the port's floor and ceil of -7/2 are -4 and -3", R(-7, 2).floor() == -4 and R(-7, 2).ceil() == -3)

print(f"\n{sum(results)} passed, {len(results) - sum(results)} failed")
sys.exit(0 if all(results) else 1)

#!/usr/bin/env python3
"""Python REFERENCE implementation of the study calculators (percentage, ratio, profit and loss, interest, break-even,
accounting equation, statistics, unit conversion, standard calculator). Exact rational arithmetic (fractions.Fraction): no floating
point anywhere, so 0.1 + 0.2 is exactly 0.3. Rounding happens ONCE, at the end, half away from zero (the commercial rule).
Inputs are decimal STRINGS. The Dart implementation must reproduce test-vectors/calculators.json exactly."""
import re
from fractions import Fraction as F
from math import gcd, isqrt


class CalcError(ValueError):
    def __init__(self, code):
        super().__init__(code)
        self.code = code


NUM_RE = re.compile(r"-?(0|[1-9][0-9]{0,14})(\.[0-9]{1,8})?")
INT_RE = re.compile(r"(0|[1-9][0-9]{0,8})")
MAX_DIGITS = 2000


# ---------------------------------------------------------------- parsing and formatting
def num(s, nonneg=False, positive=False):
    if not isinstance(s, str) or NUM_RE.fullmatch(s) is None:
        raise CalcError("invalid_number")
    v = F(s)
    if positive and v <= 0:
        raise CalcError("must_be_positive")
    if nonneg and v < 0:
        raise CalcError("negative_not_allowed")
    return v


def integer(s, positive=False):
    if not isinstance(s, str) or INT_RE.fullmatch(s) is None:
        raise CalcError("invalid_number")
    v = int(s)
    if positive and v <= 0:
        raise CalcError("must_be_positive")
    return v


def fixed(x, scale=2):
    """Decimal text with exactly `scale` decimals, half away from zero. Never prints a negative zero."""
    neg = x < 0
    a = abs(x) * 10 ** scale
    q, r = divmod(a.numerator, a.denominator)
    if 2 * r >= a.denominator:
        q += 1
    s = str(q).rjust(scale + 1, "0")
    out = (s[:-scale] + "." + s[-scale:]) if scale else s
    return ("-" if neg and q != 0 else "") + out


def trimmed(x, max_scale=10):
    s = fixed(x, max_scale)
    if "." in s:
        s = s.rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def is_exact(x, max_scale=10):
    return (x * 10 ** max_scale).denominator == 1


def text(s):
    return s  # inputs are shown exactly as the user typed them in the steps


# ---------------------------------------------------------------- percentage
def percent_of(percent, base):
    p, b = num(percent), num(base)
    r = b * p / 100
    return {"result": fixed(r), "formula": "percent_of",
            "steps": ["x = base × percent ÷ 100", f"x = {base} × {percent} ÷ 100", f"x = {fixed(r)}"]}


def percent_what(part, whole):
    a, w = num(part), num(whole)
    if w == 0:
        raise CalcError("division_by_zero")
    r = a / w * 100
    return {"percent": fixed(r), "formula": "percent_what", "steps": ["percent = part ÷ whole × 100", f"percent = {part} ÷ {whole} × 100", f"percent = {fixed(r)}"]}


def percent_change(frm, to):
    a, b = num(frm, nonneg=True), num(to, nonneg=True)
    if a == 0:
        raise CalcError("division_by_zero")
    r = (b - a) / a * 100
    return {"percent": fixed(r), "formula": "percent_change", "steps": ["change = (new − old) ÷ old × 100", f"change = ({to} − {frm}) ÷ {frm} × 100", f"change = {fixed(r)}"]}


def percent_increase(base, percent):
    b, p = num(base), num(percent, nonneg=True)
    r = b * (1 + p / 100)
    return {"result": fixed(r), "formula": "percent_increase", "steps": ["new = base × (1 + percent ÷ 100)", f"new = {base} × (1 + {percent} ÷ 100)", f"new = {fixed(r)}"]}


def percent_decrease(base, percent):
    b, p = num(base), num(percent, nonneg=True)
    if p > 100:
        raise CalcError("percent_over_100")
    r = b * (1 - p / 100)
    return {"result": fixed(r), "formula": "percent_decrease", "steps": ["new = base × (1 − percent ÷ 100)", f"new = {base} × (1 − {percent} ÷ 100)", f"new = {fixed(r)}"]}


# ---------------------------------------------------------------- ratio
def _ratio_ints(parts, decimals_ok):
    if len(parts) < 2:
        raise CalcError("need_two_parts")
    if len(parts) > 10:
        raise CalcError("too_many_parts")
    vals = [num(p, nonneg=True) if decimals_ok else F(integer(p)) for p in parts]
    return vals


def ratio_simplify(parts):
    vals = _ratio_ints(parts, True)
    d = max((len(p.split(".")[1]) if "." in p else 0) for p in parts)
    ints = [int(v * 10 ** d) for v in vals]
    g = 0
    for i in ints:
        g = gcd(g, i)
    if g == 0:
        raise CalcError("all_zero")
    out = [str(i // g) for i in ints]
    return {"parts": out, "formula": "ratio_simplify", "steps": ["divide every part by the greatest common divisor", f"{' : '.join(parts)} = {' : '.join(out)}"]}


def ratio_split(amount, parts):
    a = num(amount, nonneg=True)
    if (a * 100).denominator != 1:
        raise CalcError("too_many_decimals")
    vals = [integer(p) for p in parts] if len(parts) >= 2 else None
    if vals is None:
        raise CalcError("need_two_parts")
    if len(parts) > 10:
        raise CalcError("too_many_parts")
    total = sum(vals)
    if total == 0:
        raise CalcError("all_zero")
    cents = int(a * 100)
    exact = [F(cents * v, total) for v in vals]
    floors = [e.numerator // e.denominator for e in exact]
    left = cents - sum(floors)
    order = sorted(range(len(vals)), key=lambda i: (-(exact[i] - floors[i]), i))   # largest remainder first, ties by position
    for i in order[:left]:
        floors[i] += 1
    shares = [fixed(F(c, 100)) for c in floors]
    return {"shares": shares, "formula": "ratio_split", "steps": ["share = amount × part ÷ sum of parts, rounded down to cents", "the leftover cents go to the largest remainders (ties: earlier part first)", " + ".join(shares) + f" = {fixed(a)}"]}


def proportion(a, b, c):
    x, y, z = num(a), num(b), num(c)
    if x == 0:
        raise CalcError("division_by_zero")
    r = y * z / x
    return {"x": trimmed(r), "formula": "proportion", "steps": ["a : b = c : x, so x = b × c ÷ a", f"x = {b} × {c} ÷ {a}", f"x = {trimmed(r)}"]}


# ---------------------------------------------------------------- profit and loss
def profit_loss(cost, selling):
    c, s = num(cost, positive=True), num(selling, nonneg=True)
    d = s - c
    kind = "profit" if d > 0 else ("loss" if d < 0 else "even")
    on_cost = fixed(abs(d) / c * 100)
    on_sell = fixed(abs(d) / s * 100) if s > 0 else "n/a"
    return {"kind": kind, "amount": fixed(abs(d)), "percent_on_cost": on_cost, "percent_on_selling": on_sell, "formula": "profit_loss",
            "steps": ["Profit or loss = selling price − cost price", f"= {selling} − {cost} = {fixed(d)}",
                      f"Percent on cost = |difference| ÷ cost × 100 = {on_cost}", f"Margin on selling price = |difference| ÷ selling price × 100 = {on_sell}"]}


def selling_from_markup(cost, markup):
    c, m = num(cost, positive=True), num(markup, nonneg=True)
    r = c * (1 + m / 100)
    return {"selling": fixed(r), "formula": "selling_from_markup", "steps": ["selling = cost × (1 + markup ÷ 100)", f"selling = {cost} × (1 + {markup} ÷ 100)", f"selling = {fixed(r)}"]}


def selling_from_margin(cost, margin):
    c, m = num(cost, positive=True), num(margin, nonneg=True)
    if m >= 100:
        raise CalcError("margin_must_be_below_100")
    r = c / (1 - m / 100)
    return {"selling": fixed(r), "formula": "selling_from_margin", "steps": ["selling = cost ÷ (1 − margin ÷ 100)", f"selling = {cost} ÷ (1 − {margin} ÷ 100)", f"selling = {fixed(r)}"]}


# ---------------------------------------------------------------- interest
def simple_interest(principal, rate, years):
    p, r, t = num(principal, nonneg=True), num(rate, nonneg=True), num(years, nonneg=True)
    i = p * r * t / 100
    a = p + i
    return {"interest": fixed(i), "amount": fixed(a), "formula": "simple_interest",
            "steps": ["I = P × r × t ÷ 100", f"I = {principal} × {rate} × {years} ÷ 100", f"I = {fixed(i)}", f"A = P + I = {principal} + {fixed(i)} = {fixed(a)}"]}


def compound_interest(principal, rate, per_year, years):
    p, r, t = num(principal, nonneg=True), num(rate, nonneg=True), num(years, nonneg=True)
    n = integer(per_year, positive=True)
    if n > 365:
        raise CalcError("invalid_frequency")
    periods = n * t
    if periods.denominator != 1:
        raise CalcError("periods_not_integer")
    if periods > 1200:
        raise CalcError("too_many_periods")
    a = p * (1 + r / (100 * n)) ** int(periods)
    return {"amount": fixed(a), "interest": fixed(a - p), "formula": "compound_interest",
            "steps": ["A = P × (1 + r ÷ (100 × n)) ^ (n × t)", f"A = {principal} × (1 + {rate} ÷ (100 × {per_year})) ^ ({per_year} × {years})", f"A = {fixed(a)}",
                      f"I = A − P = {fixed(a)} − {principal} = {fixed(a - p)}"]}


# ---------------------------------------------------------------- break-even and accounting equation
def break_even(fixed_costs, price, variable):
    f, p, v = num(fixed_costs, nonneg=True), num(price, nonneg=True), num(variable, nonneg=True)
    if p <= v:
        raise CalcError("no_break_even")
    cm = p - v
    units = f / cm
    up = -((-units.numerator) // units.denominator)
    rev = units * p
    return {"contribution_margin": fixed(cm), "units": trimmed(units), "units_rounded_up": str(up), "revenue": fixed(rev), "formula": "break_even",
            "steps": ["Contribution margin = price − variable cost", f"= {price} − {variable} = {fixed(cm)}", "Break-even units = fixed costs ÷ contribution margin",
                      f"= {fixed_costs} ÷ {fixed(cm)} = {trimmed(units)}", f"Whole units needed = {up}", f"Break-even revenue = {fixed_costs} ÷ {fixed(cm)} × {price} = {fixed(rev)}"]}


def accounting_equation(assets, liabilities, equity):
    given = {"assets": assets, "liabilities": liabilities, "equity": equity}
    missing = [k for k, v in given.items() if v is None]
    if len(missing) != 1:
        raise CalcError("need_exactly_one_missing")
    a = num(assets, nonneg=True) if assets is not None else None
    l = num(liabilities, nonneg=True) if liabilities is not None else None
    e = num(equity) if equity is not None else None
    m = missing[0]
    if m == "assets":
        v = l + e
        formula = "Assets = Liabilities + Equity"
    elif m == "liabilities":
        v = a - e
        formula = "Liabilities = Assets − Equity"
    else:
        v = a - l
        formula = "Equity = Assets − Liabilities"
    if m != "equity" and v < 0:
        raise CalcError("negative_result")
    return {"missing": m, "value": fixed(v), "formula": "accounting_equation", "steps": ["Assets = Liabilities + Equity", formula, f"{m} = {fixed(v)}"]}


# ---------------------------------------------------------------- statistics
def _sqrt_fixed(x, scale):
    """sqrt of a non-negative rational, rounded half up at `scale` decimals, exactly (integer square roots only)."""
    n = x * 10 ** (2 * scale)
    t = isqrt(n.numerator // n.denominator)
    # round up when sqrt(n) >= t + 1/2, i.e. n >= (t + 1/2)^2 = t^2 + t + 1/4
    if n >= F(t * t + t) + F(1, 4):
        t += 1
    return fixed(F(t, 10 ** scale), scale)


def statistics(values, scale=2):
    if not isinstance(scale, int) or not 0 <= scale <= 8:
        raise CalcError("invalid_scale")
    if len(values) == 0:
        raise CalcError("empty_data")
    if len(values) > 1000:
        raise CalcError("too_many_values")
    xs = [num(v) for v in values]
    n = len(xs)
    total = sum(xs, F(0))
    mean = total / n
    s = sorted(xs)
    median = s[n // 2] if n % 2 else (s[n // 2 - 1] + s[n // 2]) / 2
    counts = {}
    for x in xs:
        counts[x] = counts.get(x, 0) + 1
    top = max(counts.values())
    modes = sorted(k for k, c in counts.items() if c == top) if top > 1 else []
    ss = sum(((x - mean) ** 2 for x in xs), F(0))
    pop_var = ss / n
    out = {"count": str(n), "sum": fixed(total, scale), "mean": fixed(mean, scale), "median": fixed(median, scale), "modes": [trimmed(m) for m in modes],
           "min": fixed(s[0], scale), "max": fixed(s[-1], scale), "range": fixed(s[-1] - s[0], scale),
           "pop_variance": fixed(pop_var, scale), "pop_stdev": _sqrt_fixed(pop_var, scale), "formula": "statistics"}
    if n >= 2:
        sv = ss / (n - 1)
        out["sample_variance"], out["sample_stdev"] = fixed(sv, scale), _sqrt_fixed(sv, scale)
    else:
        out["sample_variance"] = out["sample_stdev"] = "n/a"
    out["steps"] = ["mean = sum ÷ count", f"mean = {fixed(total, scale)} ÷ {n} = {out['mean']}", "variance = sum of (value − mean)² ÷ count (population) or ÷ (count − 1) (sample)", "standard deviation = √variance"]
    return out


# ---------------------------------------------------------------- unit conversion (every factor is an exact decimal)
_U = {
    "length": {"mm": F("0.001"), "cm": F("0.01"), "m": F(1), "km": F(1000), "in": F("0.0254"), "ft": F("0.3048"), "yd": F("0.9144"), "mi": F("1609.344")},
    "mass": {"mg": F("0.000001"), "g": F("0.001"), "kg": F(1), "t": F(1000), "oz": F("0.028349523125"), "lb": F("0.45359237")},
    "volume": {"ml": F("0.001"), "l": F(1), "m3": F(1000), "gal": F("3.785411784"), "qt": F("0.946352946"), "pt": F("0.473176473"), "cup": F("0.2365882365"), "floz": F("0.0295735295625")},
    "area": {"cm2": F("0.0001"), "m2": F(1), "km2": F(1000000), "ha": F(10000), "acre": F("4046.8564224"), "ft2": F("0.09290304")},
    "time": {"s": F(1), "min": F(60), "h": F(3600), "day": F(86400), "week": F(604800)},
    "speed": {"ms": F(1), "kmh": F(5, 18), "mph": F("0.44704"), "kn": F(463, 900)},
}
_TEMP = ("c", "f", "k")


def _to_kelvin(v, u):
    return v + F("273.15") if u == "c" else ((v - 32) * F(5, 9) + F("273.15") if u == "f" else v)


def _from_kelvin(k, u):
    return k - F("273.15") if u == "c" else ((k - F("273.15")) * F(9, 5) + 32 if u == "f" else k)


def convert(value, frm, to):
    v = num(value)
    if frm in _TEMP or to in _TEMP:
        if frm not in _TEMP or to not in _TEMP:
            raise CalcError("unknown_unit" if (frm not in _TEMP and not any(frm in c for c in _U.values())) or (to not in _TEMP and not any(to in c for c in _U.values())) else "incompatible_units")
        k = _to_kelvin(v, frm)
        if k < 0:
            raise CalcError("below_absolute_zero")
        r = _from_kelvin(k, to)
    else:
        cat_f = next((c for c, t in _U.items() if frm in t), None)
        cat_t = next((c for c, t in _U.items() if to in t), None)
        if cat_f is None or cat_t is None:
            raise CalcError("unknown_unit")
        if cat_f != cat_t:
            raise CalcError("incompatible_units")
        r = v * _U[cat_f][frm] / _U[cat_f][to]
    return {"result": trimmed(r), "exact": "true" if is_exact(r) else "false", "formula": "convert",
            "steps": [f"{frm} → {to}", f"{value} {frm} = {trimmed(r)} {to}"]}


# ---------------------------------------------------------------- standard calculator (exact rationals, no functions)
_TOKEN = re.compile(r"[ \t\r\n]*(?:([0-9]+(?:\.[0-9]+)?)|([^ \t\r\n]))")   # ASCII only (Python's \d and \s accept other scripts); group 2 can never be a space


def _tokens(s):
    out, pos = [], 0
    while pos < len(s):
        m = _TOKEN.match(s, pos)
        if m is None:
            break
        pos = m.end()
        if m.group(1) is not None:
            out.append(("n", m.group(1)))
        elif m.group(2) in "+-*/^()%":
            out.append((m.group(2), None))
        else:
            raise CalcError("syntax_error")
    return out


class _Parser:
    def __init__(self, toks):
        self.t, self.i = toks, 0

    def peek(self):
        return self.t[self.i][0] if self.i < len(self.t) else None

    def take(self):
        tok = self.t[self.i]
        self.i += 1
        return tok

    def expr(self):
        v = self.term()
        while self.peek() in ("+", "-"):
            op = self.take()[0]
            r = self.term()
            v = v + r if op == "+" else v - r
        return v

    def term(self):
        v = self.unary()
        while self.peek() in ("*", "/"):
            op = self.take()[0]
            r = self.unary()
            if op == "*":
                v = v * r
            else:
                if r == 0:
                    raise CalcError("division_by_zero")
                v = v / r
            if len(str(abs(v.numerator))) > MAX_DIGITS or len(str(v.denominator)) > MAX_DIGITS:
                raise CalcError("too_large")
        return v

    def unary(self):
        if self.peek() == "-":
            self.take()
            return -self.unary()
        if self.peek() == "+":
            self.take()
            return self.unary()
        return self.power()

    def power(self):
        base = self.postfix()
        if self.peek() == "^":
            self.take()
            ex = self.unary()
            if ex.denominator != 1:
                raise CalcError("non_integer_power")
            e = int(ex)
            if abs(e) > 1000:
                raise CalcError("too_large")
            if base == 0 and e < 0:
                raise CalcError("division_by_zero")
            if abs(base.numerator) > 1 and abs(e) * len(str(abs(base.numerator))) > MAX_DIGITS + 50:
                raise CalcError("too_large")
            r = base ** e
            if len(str(abs(r.numerator))) > MAX_DIGITS or len(str(r.denominator)) > MAX_DIGITS:
                raise CalcError("too_large")
            return r
        return base

    def postfix(self):
        v = self.primary()
        while self.peek() == "%":
            self.take()
            v = v / 100
        return v

    def primary(self):
        if self.peek() == "n":
            raw = self.take()[1]
            whole, _, frac = raw.partition(".")
            if len(whole) > 15 or len(frac) > 10:
                raise CalcError("invalid_number")
            return F(raw)
        if self.peek() == "(":
            self.take()
            v = self.expr()
            if self.peek() != ")":
                raise CalcError("syntax_error")
            self.take()
            return v
        raise CalcError("syntax_error")


def evaluate(expression):
    if len(expression) > 200:
        raise CalcError("too_long")
    if expression.strip(" \t\r\n") == "":
        raise CalcError("empty")
    p = _Parser(_tokens(expression))
    v = p.expr()
    if p.i != len(p.t):
        raise CalcError("syntax_error")
    return {"result": trimmed(v), "exact": "true" if is_exact(v) else "false", "formula": "evaluate", "steps": [expression.strip(" \t\r\n"), f"= {trimmed(v)}"]}

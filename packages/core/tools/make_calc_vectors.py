#!/usr/bin/env python3
"""Writes test-vectors/calculators.json (the published test-vector file the spec asks for).
Every EXPECTED value is written by hand or taken from an independent high-precision computation (Python's decimal module at 60 digits,
cross-checked against known mathematics: 1.01^12 = 1.12682503..., sqrt(32/7) = 2.1380899..., 1 acre = 43,560 square feet), never from the code under test.
Rounding rule everywhere: half away from zero, once, at the end. Run: make_calc_vectors.py [--check]"""
import json, os, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(ROOT, "test-vectors", "calculators.json")
CASES = []

def ok(fn, name, args, out, steps=None):
    c = {"fn": fn, "name": name, "args": args, "out": out}
    if steps:
        c["steps"] = steps
    CASES.append(c)

def err(fn, name, args, code):
    CASES.append({"fn": fn, "name": name, "args": args, "error": code})

# ---- percentage
ok("percent_of", "15% of 2400", ["15", "2400"], {"result": "360.00"}, ["x = base × percent ÷ 100", "x = 2400 × 15 ÷ 100", "x = 360.00"])
ok("percent_of", "12.5% of 80", ["12.5", "80"], {"result": "10.00"})
ok("percent_of", "0% of anything", ["0", "500"], {"result": "0.00"})
ok("percent_of", "100% is the whole", ["100", "33.33"], {"result": "33.33"})
ok("percent_of", "exact half rounds up: 0.125", ["12.5", "1"], {"result": "0.13"})
ok("percent_of", "exact half rounds up: 0.135", ["13.5", "1"], {"result": "0.14"})
ok("percent_of", "exact half rounds up: 0.005", ["0.5", "1"], {"result": "0.01"})
ok("percent_of", "below a half rounds down: 0.004", ["0.4", "1"], {"result": "0.00"})
ok("percent_of", "negative base", ["50", "-250"], {"result": "-125.00"})
ok("percent_of", "negative exact half rounds AWAY from zero: -0.125", ["12.5", "-1"], {"result": "-0.13"})
ok("percent_of", "a tiny negative rounds to 0.00, never -0.00", ["0.4", "-1"], {"result": "0.00"})
for bad, why in [("abc", "letters"), ("1,5", "a comma decimal"), ("010", "a leading zero"), ("1e3", "an exponent"), ("", "empty"), ("1234567890123456", "16 digits"), ("1.123456789", "9 decimals"), ("+5", "a plus sign"), (".5", "no leading digit"), ("5.", "no trailing digits")]:
    err("percent_of", f"invalid number: {why}", [bad, "10"], "invalid_number")
ok("percent_what", "360 of 2400", ["360", "2400"], {"percent": "15.00"})
ok("percent_what", "1 of 3", ["1", "3"], {"percent": "33.33"})
ok("percent_what", "2 of 3", ["2", "3"], {"percent": "66.67"})
ok("percent_what", "0 of 5", ["0", "5"], {"percent": "0.00"})
err("percent_what", "the whole is zero", ["5", "0"], "division_by_zero")
ok("percent_change", "80 to 100", ["80", "100"], {"percent": "25.00"})
ok("percent_change", "100 to 80", ["100", "80"], {"percent": "-20.00"})
ok("percent_change", "3 to 4", ["3", "4"], {"percent": "33.33"})
ok("percent_change", "no change", ["100", "100"], {"percent": "0.00"})
err("percent_change", "from zero", ["0", "5"], "division_by_zero")
err("percent_change", "a negative start", ["-5", "3"], "negative_not_allowed")
ok("percent_increase", "2400 up 15%", ["2400", "15"], {"result": "2760.00"})
ok("percent_increase", "0.505 rounds up", ["0.5", "1"], {"result": "0.51"})
ok("percent_increase", "up 0%", ["100", "0"], {"result": "100.00"})
err("percent_increase", "a negative percent", ["100", "-5"], "negative_not_allowed")
ok("percent_decrease", "2400 down 12.5%", ["2400", "12.5"], {"result": "2100.00"})
ok("percent_decrease", "down 100%", ["2400", "100"], {"result": "0.00"})
ok("percent_decrease", "100 down 33.33%", ["100", "33.33"], {"result": "66.67"})
err("percent_decrease", "more than 100%", ["2400", "100.01"], "percent_over_100")

# ---- ratio
ok("ratio_simplify", "120:80:40", [["120", "80", "40"]], {"parts": ["3", "2", "1"]})
ok("ratio_simplify", "decimals", [["0.5", "1.5"]], {"parts": ["1", "3"]})
ok("ratio_simplify", "two decimals", [["2.50", "1.25"]], {"parts": ["2", "1"]})
ok("ratio_simplify", "already simplest", [["7", "13"]], {"parts": ["7", "13"]})
ok("ratio_simplify", "a zero part", [["0", "5"]], {"parts": ["0", "1"]})
err("ratio_simplify", "all zero", [["0", "0"]], "all_zero")
err("ratio_simplify", "one part", [["5"]], "need_two_parts")
err("ratio_simplify", "eleven parts", [["1"] * 11], "too_many_parts")
err("ratio_simplify", "a negative part", [["-1", "2"]], "negative_not_allowed")
err("ratio_simplify", "not a number", [["a", "2"]], "invalid_number")
ok("ratio_split", "1000 in 2:3", ["1000", ["2", "3"]], {"shares": ["400.00", "600.00"]})
ok("ratio_split", "100 in 1:1:1, the extra cent goes to the first part (equal remainders)", ["100", ["1", "1", "1"]], {"shares": ["33.34", "33.33", "33.33"]})
ok("ratio_split", "10 in 1:1:1", ["10", ["1", "1", "1"]], {"shares": ["3.34", "3.33", "3.33"]})
ok("ratio_split", "100 in 1:2, the extra cent goes to the LARGEST remainder", ["100", ["1", "2"]], {"shares": ["33.33", "66.67"]})
ok("ratio_split", "one cent between two", ["0.01", ["1", "1"]], {"shares": ["0.01", "0.00"]})
ok("ratio_split", "a zero part", ["1000", ["0", "1"]], {"shares": ["0.00", "1000.00"]})
ok("ratio_split", "exact shares", ["100", ["1", "2", "2"]], {"shares": ["20.00", "40.00", "40.00"]})
err("ratio_split", "more than cents", ["100.005", ["1", "1"]], "too_many_decimals")
err("ratio_split", "all parts zero", ["100", ["0", "0"]], "all_zero")
err("ratio_split", "a negative part", ["100", ["1", "-1"]], "invalid_number")
err("ratio_split", "a decimal part", ["100", ["1.5", "2"]], "invalid_number")
err("ratio_split", "one part", ["100", ["1"]], "need_two_parts")
err("ratio_split", "a negative amount", ["-5", ["1", "1"]], "negative_not_allowed")
ok("proportion", "3:4 = 9:x", ["3", "4", "9"], {"x": "12"})
ok("proportion", "7:2 = 3:x", ["7", "2", "3"], {"x": "0.8571428571"})
ok("proportion", "a negative term", ["2", "-3", "4"], {"x": "-6"})
ok("proportion", "c is zero", ["3", "4", "0"], {"x": "0"})
err("proportion", "a is zero", ["0", "4", "9"], "division_by_zero")

# ---- profit and loss
ok("profit_loss", "profit 800 to 1000", ["800", "1000"], {"kind": "profit", "amount": "200.00", "percent_on_cost": "25.00", "percent_on_selling": "20.00"},
   ["Profit or loss = selling price − cost price", "= 1000 − 800 = 200.00", "Percent on cost = |difference| ÷ cost × 100 = 25.00", "Margin on selling price = |difference| ÷ selling price × 100 = 20.00"])
ok("profit_loss", "loss 1000 to 800", ["1000", "800"], {"kind": "loss", "amount": "200.00", "percent_on_cost": "20.00", "percent_on_selling": "25.00"},
   ["Profit or loss = selling price − cost price", "= 800 − 1000 = -200.00", "Percent on cost = |difference| ÷ cost × 100 = 20.00", "Margin on selling price = |difference| ÷ selling price × 100 = 25.00"])
ok("profit_loss", "break even", ["500", "500"], {"kind": "even", "amount": "0.00", "percent_on_cost": "0.00", "percent_on_selling": "0.00"})
ok("profit_loss", "given away: margin on a zero price is undefined", ["1000", "0"], {"kind": "loss", "amount": "1000.00", "percent_on_cost": "100.00", "percent_on_selling": "n/a"})
ok("profit_loss", "3 to 4", ["3", "4"], {"kind": "profit", "amount": "1.00", "percent_on_cost": "33.33", "percent_on_selling": "25.00"})
err("profit_loss", "zero cost", ["0", "5"], "must_be_positive")
err("profit_loss", "negative cost", ["-5", "3"], "must_be_positive")
err("profit_loss", "negative selling price", ["5", "-3"], "negative_not_allowed")
ok("selling_from_markup", "800 with 25% markup", ["800", "25"], {"selling": "1000.00"})
ok("selling_from_markup", "99.99 with 10%", ["99.99", "10"], {"selling": "109.99"})
ok("selling_from_markup", "0% markup", ["100", "0"], {"selling": "100.00"})
err("selling_from_markup", "zero cost", ["0", "10"], "must_be_positive")
ok("selling_from_margin", "800 with 20% margin on the selling price", ["800", "20"], {"selling": "1000.00"})
ok("selling_from_margin", "99% margin", ["100", "99"], {"selling": "10000.00"})
ok("selling_from_margin", "3 with 10% margin", ["3", "10"], {"selling": "3.33"})
ok("selling_from_margin", "0% margin", ["100", "0"], {"selling": "100.00"})
err("selling_from_margin", "100% margin is impossible", ["100", "100"], "margin_must_be_below_100")

# ---- interest
ok("simple_interest", "10000 at 8% for 3 years", ["10000", "8", "3"], {"interest": "2400.00", "amount": "12400.00"},
   ["I = P × r × t ÷ 100", "I = 10000 × 8 × 3 ÷ 100", "I = 2400.00", "A = P + I = 10000 + 2400.00 = 12400.00"])
ok("simple_interest", "fractions of a year", ["5000", "7.5", "2.5"], {"interest": "937.50", "amount": "5937.50"})
ok("simple_interest", "0% interest", ["100", "0", "5"], {"interest": "0.00", "amount": "100.00"})
ok("simple_interest", "cents", ["1234.56", "3.5", "1"], {"interest": "43.21", "amount": "1277.77"})
err("simple_interest", "negative principal", ["-1", "5", "1"], "negative_not_allowed")
ok("compound_interest", "yearly for 3 years", ["10000", "8", "1", "3"], {"amount": "12597.12", "interest": "2597.12"})
ok("compound_interest", "quarterly for 2 years", ["10000", "8", "4", "2"], {"amount": "11716.59", "interest": "1716.59"},
   ["A = P × (1 + r ÷ (100 × n)) ^ (n × t)", "A = 10000 × (1 + 8 ÷ (100 × 4)) ^ (4 × 2)", "A = 11716.59", "I = A − P = 11716.59 − 10000 = 1716.59"])
ok("compound_interest", "monthly for a year (5634.12515... rounds up)", ["5000", "12", "12", "1"], {"amount": "5634.13", "interest": "634.13"})
ok("compound_interest", "half-yearly for 4 years", ["2000", "7.5", "2", "4"], {"amount": "2684.94", "interest": "684.94"})
ok("compound_interest", "monthly for 2 years", ["1500", "3", "12", "2"], {"amount": "1592.64", "interest": "92.64"})
ok("compound_interest", "half a year, twice a year", ["1000", "10", "2", "0.5"], {"amount": "1050.00", "interest": "50.00"})
ok("compound_interest", "cents in the principal", ["250.50", "5", "4", "1"], {"amount": "263.26", "interest": "12.76"})
ok("compound_interest", "0% interest", ["1000", "0", "12", "5"], {"amount": "1000.00", "interest": "0.00"})
err("compound_interest", "periods are not whole", ["1000", "5", "12", "0.4"], "periods_not_integer")
err("compound_interest", "too many periods", ["1000", "5", "12", "101"], "too_many_periods")
err("compound_interest", "more than 365 periods a year", ["1000", "5", "366", "1"], "invalid_frequency")
err("compound_interest", "zero periods a year", ["1000", "5", "0", "1"], "must_be_positive")
err("compound_interest", "a decimal frequency", ["1000", "5", "1.5", "1"], "invalid_number")

# ---- break-even and accounting equation
ok("break_even", "exact", ["50000", "250", "150"], {"contribution_margin": "100.00", "units": "500", "units_rounded_up": "500", "revenue": "125000.00"})
ok("break_even", "a fraction of a unit rounds UP to whole units", ["50001", "250", "150"], {"contribution_margin": "100.00", "units": "500.01", "units_rounded_up": "501", "revenue": "125002.50"},
   ["Contribution margin = price − variable cost", "= 250 − 150 = 100.00", "Break-even units = fixed costs ÷ contribution margin", "= 50001 ÷ 100.00 = 500.01", "Whole units needed = 501", "Break-even revenue = 50001 ÷ 100.00 × 250 = 125002.50"])
ok("break_even", "no fixed costs", ["0", "10", "4"], {"contribution_margin": "6.00", "units": "0", "units_rounded_up": "0", "revenue": "0.00"})
ok("break_even", "1000 fixed", ["1000", "3", "1"], {"contribution_margin": "2.00", "units": "500", "units_rounded_up": "500", "revenue": "1500.00"})
ok("break_even", "a repeating decimal", ["100", "7", "4"], {"contribution_margin": "3.00", "units": "33.3333333333", "units_rounded_up": "34", "revenue": "233.33"})
err("break_even", "price equals variable cost", ["1000", "100", "100"], "no_break_even")
err("break_even", "price below variable cost", ["1000", "90", "100"], "no_break_even")
ok("accounting_equation", "missing equity", ["500000", "200000", None], {"missing": "equity", "value": "300000.00"})
ok("accounting_equation", "missing assets", [None, "200000", "300000"], {"missing": "assets", "value": "500000.00"})
ok("accounting_equation", "missing liabilities", ["500000", None, "300000"], {"missing": "liabilities", "value": "200000.00"})
ok("accounting_equation", "negative equity is allowed", ["100", "150", None], {"missing": "equity", "value": "-50.00"})
ok("accounting_equation", "assets with negative equity", [None, "100", "-30"], {"missing": "assets", "value": "70.00"})
err("accounting_equation", "assets cannot be negative", [None, "10", "-30"], "negative_result")
err("accounting_equation", "liabilities cannot be negative", ["100", None, "150"], "negative_result")
err("accounting_equation", "nothing missing", ["1", "1", "0"], "need_exactly_one_missing")
err("accounting_equation", "two missing", ["1", None, None], "need_exactly_one_missing")

# ---- statistics
ok("statistics", "the classic data set (scale 2)", [["2", "4", "4", "4", "5", "5", "7", "9"], 2],
   {"count": "8", "sum": "40.00", "mean": "5.00", "median": "4.50", "modes": ["4"], "min": "2.00", "max": "9.00", "range": "7.00", "pop_variance": "4.00", "pop_stdev": "2.00", "sample_variance": "4.57", "sample_stdev": "2.14"})
ok("statistics", "the classic data set (scale 4)", [["2", "4", "4", "4", "5", "5", "7", "9"], 4],
   {"sum": "40.0000", "mean": "5.0000", "median": "4.5000", "min": "2.0000", "max": "9.0000", "range": "7.0000", "pop_variance": "4.0000", "pop_stdev": "2.0000", "sample_variance": "4.5714", "sample_stdev": "2.1381"})
ok("statistics", "a second data set", [["10", "12", "23", "23", "16", "23", "21", "16"], 2],
   {"count": "8", "sum": "144.00", "mean": "18.00", "median": "18.50", "modes": ["23"], "min": "10.00", "max": "23.00", "range": "13.00", "pop_variance": "24.00", "pop_stdev": "4.90", "sample_variance": "27.43", "sample_stdev": "5.24"})
ok("statistics", "two modes", [["1", "1", "2", "2", "3"], 2], {"modes": ["1", "2"], "mean": "1.80", "median": "2.00", "pop_variance": "0.56", "pop_stdev": "0.75", "sample_variance": "0.70", "sample_stdev": "0.84"})
ok("statistics", "no mode", [["1", "2", "3"], 2], {"modes": [], "mean": "2.00", "pop_variance": "0.67", "pop_stdev": "0.82", "sample_variance": "1.00", "sample_stdev": "1.00"})
ok("statistics", "order does not matter (odd count median)", [["3", "1", "2"], 2], {"median": "2.00", "min": "1.00", "max": "3.00"})
ok("statistics", "even count median", [["1", "2", "3", "4"], 2], {"median": "2.50", "mean": "2.50"})
ok("statistics", "one value", [["5"], 2], {"count": "1", "mean": "5.00", "median": "5.00", "modes": [], "min": "5.00", "max": "5.00", "range": "0.00", "pop_variance": "0.00", "pop_stdev": "0.00", "sample_variance": "n/a", "sample_stdev": "n/a"})
ok("statistics", "decimals are exact", [["0.1", "0.2", "0.3"], 2], {"sum": "0.60", "mean": "0.20", "median": "0.20", "pop_variance": "0.01", "pop_stdev": "0.08", "sample_variance": "0.01", "sample_stdev": "0.10"})
ok("statistics", "negative values and no negative zero", [["-1", "1"], 2], {"mean": "0.00", "median": "0.00", "min": "-1.00", "max": "1.00", "range": "2.00", "pop_variance": "1.00", "pop_stdev": "1.00", "sample_variance": "2.00", "sample_stdev": "1.41"})
ok("statistics", "scale 0 rounds halves up", [["1", "2"], 0], {"sum": "3", "mean": "2", "median": "2", "min": "1", "max": "2", "range": "1", "pop_variance": "0", "pop_stdev": "1", "sample_variance": "1", "sample_stdev": "1"})
err("statistics", "no data", [[], 2], "empty_data")
err("statistics", "scale above 8", [["1"], 9], "invalid_scale")
err("statistics", "more than 1000 values", [["1"] * 1001, 2], "too_many_values")
err("statistics", "not a number", [["a"], 2], "invalid_number")

# ---- unit conversion
def conv(name, v, a, b, result, exact="true"):
    ok("convert", name, [v, a, b], {"result": result, "exact": exact})
conv("1 mile in km", "1", "mi", "km", "1.609344"); conv("10 inches in cm", "10", "in", "cm", "25.4"); conv("100 cm in m", "100", "cm", "m", "1")
conv("1 km in miles (never exact)", "1", "km", "mi", "0.6213711922", "false"); conv("5 ft in inches", "5", "ft", "in", "60"); conv("1 yard in feet", "1", "yd", "ft", "3")
conv("1 inch in km", "1", "in", "km", "0.0000254"); conv("2.5 km in m", "2.5", "km", "m", "2500"); conv("negative lengths are fine", "-5", "ft", "in", "-60"); conv("zero", "0", "km", "mi", "0"); conv("same unit", "5", "m", "m", "5")
conv("1 lb in kg", "1", "lb", "kg", "0.45359237"); conv("1 kg in lb (never exact)", "1", "kg", "lb", "2.2046226218", "false"); conv("16 oz is 1 lb", "16", "oz", "lb", "1"); conv("1 tonne in kg", "1", "t", "kg", "1000")
conv("1 US gallon in litres", "1", "gal", "l", "3.785411784"); conv("1 litre in ml", "1", "l", "ml", "1000"); conv("1 US cup in ml", "1", "cup", "ml", "236.5882365"); conv("1 m3 in litres", "1", "m3", "l", "1000")
conv("1 acre in hectares: the exact value has 11 decimals, the display rule keeps 10", "1", "acre", "ha", "0.4046856422", "false"); conv("1 hectare in m2", "1", "ha", "m2", "10000"); conv("1 km2 in hectares", "1", "km2", "ha", "100"); conv("1 acre is 43,560 square feet", "1", "acre", "ft2", "43560")
conv("1 day in hours", "1", "day", "h", "24"); conv("90 minutes in hours", "90", "min", "h", "1.5"); conv("1 week in days", "1", "week", "day", "7")
conv("36 km/h in m/s", "36", "kmh", "ms", "10"); conv("1 mph in km/h", "1", "mph", "kmh", "1.609344"); conv("1 knot in km/h", "1", "kn", "kmh", "1.852"); conv("60 mph in m/s", "60", "mph", "ms", "26.8224")
conv("100 C in F", "100", "c", "f", "212"); conv("32 F in C", "32", "f", "c", "0"); conv("98.6 F in C", "98.6", "f", "c", "37"); conv("0 K in C", "0", "k", "c", "-273.15"); conv("0 C in K", "0", "c", "k", "273.15")
conv("-40 is the same in C and F", "-40", "c", "f", "-40"); conv("absolute zero in F gives 0 K", "-459.67", "f", "k", "0")
err("convert", "below absolute zero (C)", ["-273.16", "c", "k"], "below_absolute_zero"); err("convert", "below absolute zero (K)", ["-0.01", "k", "c"], "below_absolute_zero")
err("convert", "mass to length", ["1", "kg", "m"], "incompatible_units"); err("convert", "temperature to length", ["1", "c", "m"], "incompatible_units")
err("convert", "unknown unit", ["1", "furlong", "m"], "unknown_unit"); err("convert", "unknown target", ["1", "m", "furlong"], "unknown_unit"); err("convert", "not a number", ["x", "m", "km"], "invalid_number")

# ---- standard calculator (exact rationals)
def ev(name, expr, result, exact="true"):
    ok("evaluate", name, [expr], {"result": result, "exact": exact})
ev("0.1 + 0.2 is exactly 0.3", "0.1+0.2", "0.3"); ev("one third", "1/3", "0.3333333333", "false"); ev("two thirds", "2/3", "0.6666666667", "false")
ev("1/3*3 is exactly 1", "1/3*3", "1"); ev("0.1*3 is exactly 0.3", "0.1*3", "0.3"); ev("brackets", "(2+3)*4", "20"); ev("power", "2^10", "1024")
ev("unary minus binds weaker than a power", "-3^2", "-9"); ev("brackets around a negative", "(-2)^2", "4"); ev("-2^2", "-2^2", "-4"); ev("powers associate to the right", "2^3^2", "512"); ev("negative exponent", "2^-1", "0.5")
ev("a negative factor", "2*-3", "-6"); ev("double minus", "--3", "3"); ev("left to right subtraction", " 7 - 2 - 1 ", "4"); ev("left to right division", "8/4/2", "1"); ev("decimal times integer", "1.5*4", "6"); ev("exact division", "10/4", "2.5")
ev("percent of a number", "200*10%", "20"); ev("a percent alone", "50%", "0.5"); ev("percent is only a divide by 100", "100+10%", "100.1"); ev("small percent", "0.5%", "0.005"); ev("double percent", "5%%", "0.0005"); ev("negative percent", "-50%", "-0.5")
ev("large product", "1000000*1000000", "1000000000000"); ev("ten decimals are kept", "0.0000000001", "0.0000000001"); ev("trailing zero", "3.0", "3"); ev("nested brackets", "(((((1)))))", "1"); ev("zero to the zero is 1", "0^0", "1"); ev("surrounding spaces", " 7 ", "7"); ev("tabs and newlines count as spaces", "\t1 +\n2\r", "3")
for expr, code in [("5/0", "division_by_zero"), ("0^-1", "division_by_zero"), ("2^0.5", "non_integer_power"), ("1+", "syntax_error"), ("(1", "syntax_error"), ("1)", "syntax_error"), ("", "empty"), ("   ", "empty"),
                   ("1 2", "syntax_error"), ("1e3", "syntax_error"), ("abc", "syntax_error"), ("()", "syntax_error"), ("*2", "syntax_error"), ("2**3", "syntax_error"), ("1,5", "syntax_error"), ("\u0663+\u0663", "syntax_error"), ("1\u00a0+2", "syntax_error"), ("\u00a0", "syntax_error"),
                   ("2^1001", "too_large"), ("999999999999999^200", "too_large"), ("1" * 201, "too_long"), ("0.00000000001", "invalid_number"), ("99999999999999999999", "invalid_number")]:
    err("evaluate", f"error: {expr[:30]!r}", [expr], code)


def main(argv):
    text = json.dumps({"rounding": "half away from zero, once, at the end", "cases": CASES}, indent=1, ensure_ascii=False, sort_keys=True) + "\n"
    if "--check" in argv:
        good = os.path.exists(OUT) and open(OUT, encoding="utf-8").read() == text
        print("OK    calculator vectors are up to date" if good else "FAIL  test-vectors/calculators.json is out of date: run make_calc_vectors.py")
        return 0 if good else 1
    open(OUT, "w", encoding="utf-8").write(text)
    print("wrote", os.path.relpath(OUT, ROOT), "-", len(CASES), "cases")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

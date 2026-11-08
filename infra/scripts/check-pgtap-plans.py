#!/usr/bin/env python3
"""Static checks for pgTAP test files (no database needed).

Usage: check-pgtap-plans.py [DIR] [--fix]     default DIR: backend/supabase/tests
For every *.test.sql:
  - starts with `begin;` and ends with `rollback;` (a test must never leave data behind)
  - exactly one `select plan(N);` with a literal integer, and `select * from finish();`
  - N equals the number of assertion statements in the file
  - assertions that cannot be counted statically (`select ok(...) from generate_series(...)`, loops) are rejected
--fix rewrites N to the counted number (use it while writing a test, review the diff, never in CI).
"""
import importlib.util
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("lint_migrations", os.path.join(HERE, "lint-migrations.py"))
lint = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(lint)

EXPLICIT = {
    "ok", "is", "isnt", "matches", "imatches", "doesnt_match", "doesnt_imatch", "alike", "ialike", "unalike", "unialike",
    "cmp_ok", "isa_ok", "pass", "fail", "lives_ok", "throws_ok", "throws_like", "throws_ilike", "throws_matching",
    "throws_imatching", "performs_ok", "performs_within", "results_eq", "results_ne", "set_eq", "set_ne", "set_has",
    "set_hasnt", "bag_eq", "bag_ne", "bag_has", "bag_hasnt", "row_eq",
}
FAMILY = re.compile(r"^(has|hasnt|col|is|isnt|can|cannot|index|trigger|function|volatility|policy|policies|table|schema|sequence|view|domain|enum|type|language|opclasses|extensions|roles|users|groups|tablespaces|materialized)_\w+$")
CALL = re.compile(r"^select\s+([a-z_][a-z0-9_]*)\s*\(", re.I)


def assertion_name(masked):
    m = CALL.match(masked)
    if not m:
        return None
    n = m.group(1).lower()
    return n if (n in EXPLICIT or FAMILY.match(n)) else None


def top_level_from(masked):
    """True if the keyword FROM appears outside every parenthesis."""
    depth = 0
    for m in re.finditer(r"[()]|\bfrom\b", masked, re.I):
        t = m.group(0)
        if t == "(":
            depth += 1
        elif t == ")":
            depth -= 1
        elif depth == 0:
            return True
    return False


def check_file(path, fix=False):
    text = open(path, encoding="utf-8").read()
    stmts = lint.tokenize(text)
    problems = []
    name = os.path.basename(path)
    low = [re.sub(r"\s+", " ", s.masked.lower()) for s in stmts]
    if not low or low[0] != "begin":
        problems.append("must start with `begin;`")
    if not low or low[-1] != "rollback":
        problems.append("must end with `rollback;`")
    plans = [(i, re.fullmatch(r"select plan\( ?(\d+) ?\)", l)) for i, l in enumerate(low) if l.startswith("select plan")]
    if len(plans) != 1 or plans[0][1] is None:
        problems.append("needs exactly one `select plan(N);` with a literal integer")
    if not any(re.fullmatch(r"select \* from finish\( ?\)", l) for l in low):
        problems.append("needs `select * from finish();`")
    count = 0
    for s, l in zip(stmts, low):
        n = assertion_name(s.masked)
        if n is None:
            continue
        if top_level_from(s.masked):
            problems.append(f"line {s.line}: assertion `{n}` uses FROM at top level, so it cannot be counted statically")
        count += 1
    declared = int(plans[0][1].group(1)) if len(plans) == 1 and plans[0][1] else None
    if declared is not None and declared != count:
        if fix:
            new = re.sub(r"select\s+plan\s*\(\s*\d+\s*\)", f"select plan({count})", text, count=1, flags=re.I)
            open(path, "w", encoding="utf-8").write(new)
            print(f"{name}: plan {declared} -> {count} (fixed)")
        else:
            problems.append(f"plan says {declared} but the file contains {count} assertion(s)")
    return name, count, declared, problems


def main(argv):
    fix = "--fix" in argv
    args = [a for a in argv[1:] if a != "--fix"]
    d = args[0] if args else os.path.join(HERE, "..", "..", "backend", "supabase", "tests")
    if not os.path.isdir(d):
        print(f"no such directory: {d}", file=sys.stderr)
        return 2
    files = sorted(f for f in os.listdir(d) if f.endswith(".test.sql"))
    bad = 0
    for f in files:
        name, count, declared, problems = check_file(os.path.join(d, f), fix)
        for p in problems:
            print(f"{name}: {p}")
        bad += len(problems)
        if not problems:
            print(f"{name}: ok ({count} assertions)")
    print(f"{len(files)} test file(s) checked, {bad} problem(s)")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

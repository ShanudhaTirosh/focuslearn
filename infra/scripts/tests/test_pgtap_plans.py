"""Offline tests for check-pgtap-plans.py."""
import importlib.util, os, shutil, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("chk", os.path.join(HERE, "..", "check-pgtap-plans.py"))
chk = importlib.util.module_from_spec(spec); spec.loader.exec_module(chk)
results = []
tmp = tempfile.mkdtemp()

def check(name, cond, detail=""):
    results.append(bool(cond)); print(("PASS  " if cond else "FAIL  ") + name + (f"   [{detail}]" if (detail and not cond) else ""))

def probe(body, fix=False):
    p = os.path.join(tmp, "t.test.sql"); open(p, "w").write(body)
    return chk.check_file(p, fix)

WRAP = "begin;\nselect plan({n});\n{body}\nselect * from finish();\nrollback;\n"
ok2 = "select ok(true, 'a');\nselect is(1, 1, 'b');"
name, count, declared, problems = probe(WRAP.format(n=2, body=ok2))
check("a correct plan passes and counts 2", problems == [] and count == 2, str(problems))
_, count, _, problems = probe(WRAP.format(n=3, body=ok2))
check("a plan that is too high fails", any("plan says 3" in p for p in problems))
_, _, _, problems = probe(WRAP.format(n=1, body=ok2))
check("a plan that is too low fails", any("plan says 1" in p for p in problems))
_, count, _, problems = probe(WRAP.format(n=1, body="select ok(\n  not exists (select 1 from pg_class where relname = 'x'),\n  'multi-line'\n);"))
check("a multi-line assertion with a subquery counts once", count == 1 and problems == [], str(problems))
_, count, _, problems = probe(WRAP.format(n=1, body="-- select ok(true, 'in a comment');\nselect ok(true, 'select ok(false) in a string');\nselect set_config('a','b',true);"))
check("comments, strings and non-assertion selects are not counted", count == 1 and problems == [], f"{count} {problems}")
_, count, _, problems = probe(WRAP.format(n=4, body="select has_table('public', 'x', 'm');\nselect throws_ok($$ select 1 $$, '42501', null, 'm');\nselect is_empty($$ select 1 where false $$, 'm');\nselect lives_ok($$ select 1 $$, 'm');"))
check("has_*, throws_ok, is_empty and lives_ok are recognised", count == 4 and problems == [], f"{count} {problems}")
_, _, _, problems = probe(WRAP.format(n=1, body="select ok(true, 'x') from generate_series(1, 3);"))
check("an assertion with a top-level FROM is rejected", any("cannot be counted" in p for p in problems))
_, _, _, problems = probe("select plan(1);\nselect ok(true,'x');\nselect * from finish();\n")
check("missing begin/rollback is rejected", any("begin" in p for p in problems) and any("rollback" in p for p in problems))
_, _, _, problems = probe("begin;\nselect ok(true,'x');\nselect * from finish();\nrollback;\n")
check("missing plan is rejected", any("plan" in p for p in problems))
_, _, _, problems = probe("begin;\nselect plan(1);\nselect plan(1);\nselect ok(true,'x');\nselect * from finish();\nrollback;\n")
check("two plans are rejected", any("exactly one" in p for p in problems))
_, _, _, problems = probe("begin;\nselect plan(1);\nselect ok(true,'x');\nrollback;\n")
check("missing finish() is rejected", any("finish" in p for p in problems))
p = os.path.join(tmp, "t.test.sql"); probe(WRAP.format(n=9, body=ok2), fix=True)
check("--fix rewrites the plan to the counted number", "select plan(2);" in open(p).read())
real = os.path.join(HERE, "..", "..", "..", "backend", "supabase", "tests")
bad = [chk.check_file(os.path.join(real, f))[3] for f in sorted(os.listdir(real)) if f.endswith(".test.sql")]
check("every real test file in the repo passes", all(b == [] for b in bad), str(bad))
shutil.rmtree(tmp)
print(f"\n{sum(results)} passed, {len(results) - sum(results)} failed")
sys.exit(0 if all(results) else 1)

"""Offline tests for lint-migrations.py: every rule fires, every escape works, and look-alike SQL does not cause false positives."""
import importlib.util, os, shutil, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("lint", os.path.join(HERE, "..", "lint-migrations.py"))
lint = importlib.util.module_from_spec(spec); spec.loader.exec_module(lint)
results = []
FN = "20261016000001_test.sql"

def check(name, cond, detail=""):
    results.append(bool(cond)); print(("PASS  " if cond else "FAIL  ") + name + (f"   [{detail}]" if (detail and not cond) else ""))

def rules(sql, fn=FN):
    return sorted({p[2] for p in lint.lint_text(fn, sql)})

GOOD_TABLE = """
create table public.notes (id uuid primary key, owner_id uuid not null, body text);
alter table public.notes enable row level security;
alter table public.notes force row level security;
"""
check("a table with enable + force RLS is clean", rules(GOOD_TABLE) == [])
check("missing RLS is reported for both enable and force", rules("create table public.t (id int);") == ["RLS-ENABLE", "RLS-FORCE"])
check("enable without force reports RLS-FORCE only", rules("create table public.t (id int);\nalter table public.t enable row level security;") == ["RLS-FORCE"])
check("unqualified table name is treated as public", rules("create table t (id int);") == ["RLS-ENABLE", "RLS-FORCE"])
check("quoted and spaced names match their alter statements", rules('create table "public" . "Notes" (id int);\nalter table public."notes" enable row level security;\nalter table public.notes force row level security;') == [])
check("`if not exists` and unlogged tables are still checked", rules("create unlogged table if not exists public.t (id int);") == ["RLS-ENABLE", "RLS-FORCE"])
check("tables in other schemas are not required to have RLS", rules("create table private.t (id int);") == [])
check("temporary tables are ignored", rules("create temp table t (id int);") == [])
check("RLS statements for a DIFFERENT table do not satisfy the rule", rules("create table public.a (id int);\nalter table public.b enable row level security;\nalter table public.b force row level security;") == ["RLS-ENABLE", "RLS-FORCE"])
check("disabling RLS is always rejected", "RLS-DISABLE" in rules("alter table public.t disable row level security;"))
check("un-forcing RLS is always rejected", "RLS-DISABLE" in rules("alter table public.t no force row level security;"))

check("definer function with empty search_path in private is clean", rules("create function private.f() returns int language sql security definer set search_path = '' as $$ select 1 $$;") == [])
check("definer function without search_path fails DEFINER-PATH", "DEFINER-PATH" in rules("create function private.f() returns int language sql security definer as $$ select 1 $$;"))
check("definer function in public fails DEFINER-PUBLIC", "DEFINER-PUBLIC" in rules("create function public.f() returns int language sql security definer set search_path = '' as $$ select 1 $$;"))
check("unqualified definer function counts as public", "DEFINER-PUBLIC" in rules("create function f() returns int language sql security definer set search_path = '' as $$ select 1 $$;"))
check("definer-public-ok escape is accepted", "DEFINER-PUBLIC" not in rules("-- definer-public-ok: RPC used by the app, checks auth.uid() itself\ncreate function public.f() returns int language sql security definer set search_path = '' as $$ select 1 $$;"))
check("invoker function in public is fine", rules("create function public.f() returns int language sql as $$ select 1 $$;") == [])
check("'security definer' text inside a function BODY is not a false positive", rules("create function public.f() returns text language sql as $$ select 'security definer without path' $$;") == [])
check("'set search_path' inside a body does not satisfy the rule", "DEFINER-PATH" in rules("create function private.f() returns int language plpgsql security definer as $$ begin perform set_config('x','y',false); /* set search_path */ return 1; end $$;"))

check("grant to anon fails", "GRANT-ANON" in rules("grant select on public.t to anon;"))
check("grant to anon with escape passes", "GRANT-ANON" not in rules("-- anon-ok: published formulas are public reading material\ngrant select on public.t to anon;"))
check("grant among several roles still catches anon", "GRANT-ANON" in rules("grant select on public.t to authenticated, anon;"))
check("grant to authenticated only is fine", rules("grant select, insert on public.t to authenticated;") == [])
check("revoke from anon is fine", rules("revoke all on public.t from anon;") == [])
check("policy for anon fails", "GRANT-ANON" in rules("create policy p on public.t for select to anon using (published);"))
check("grant all to authenticated fails", "GRANT-ALL" in rules("grant all on public.t to authenticated;"))
check("grant all privileges to service_role is allowed", rules("grant all privileges on public.t to service_role;") == [])
check("grant all escape accepted", "GRANT-ALL" not in rules("-- grant-all-ok: temporary admin tool\ngrant all on public.t to authenticated;"))
check("grant to public fails", "GRANT-PUBLIC" in rules("grant execute on function private.f() to public;"))
check("alter default privileges granting to anon fails", "GRANT-ANON" in rules("alter default privileges in schema public grant select on tables to anon;"))

check("policy using (true) fails", "POLICY-OPEN" in rules("create policy p on public.t for select to authenticated using (true);"))
check("policy using ( true ) with odd spacing fails", "POLICY-OPEN" in rules("create policy p on public.t for select to authenticated using ( true );"))
check("policy-open escape accepted", "POLICY-OPEN" not in rules("-- policy-open-ok: every signed-in student may read published formulas\ncreate policy p on public.t for select to authenticated using (true);"))
check("policy with a real condition is fine", rules("create policy p on public.t for select to authenticated using (owner_id = (select auth.uid()));") == [])

check("drop table fails", "DESTRUCTIVE" in rules("drop table public.t;"))
check("truncate fails", "DESTRUCTIVE" in rules("truncate public.t;"))
check("drop schema fails", "DESTRUCTIVE" in rules("drop schema private cascade;"))
check("destructive escape accepted", "DESTRUCTIVE" not in rules("-- destructive-ok: table was created by mistake in the previous migration, empty\ndrop table public.t;"))
check("drop policy and drop function are allowed", rules("drop policy if exists p on public.t;\ndrop function if exists private.f();") == [])
check("begin and commit fail", rules("begin;\nselect 1;\ncommit;") == ["TXN-CONTROL"])

check("keywords inside comments are ignored", rules("-- create table public.t (id int);\n/* grant all on x to anon; drop table y; */\nselect 1;") == [])
check("keywords inside string literals are ignored", rules("select 'create table public.t (id int); grant select to anon';") == [])
check("semicolons inside dollar-quoted bodies do not split statements", rules("create function private.f() returns void language plpgsql set search_path = '' as $fn$ begin create temp table x (i int); drop table x; end; $fn$;") == [])
check("a comment separated by a blank statement does not leak its escape to the next one", "GRANT-ANON" in rules("-- anon-ok: first\ngrant select on public.a to anon;\ngrant select on public.b to anon;"))

problems = lint.lint_text(FN, "select 1;\n\ncreate table public.t (id int);\n")
check("line numbers point at the statement", problems and problems[0][1] == 3, str(problems))

check("good file name accepted", rules("select 1;", "20261016000000_baseline.sql") == [])
check("bad file names rejected", all("NAME" in rules("select 1;", n) for n in ("baseline.sql", "2026_baseline.sql", "20261016000000_Bad Name.sql", "20261016000000-x.sql")))

tmp = tempfile.mkdtemp()
try:
    for n in ("20261016000000_a.sql", "20261016000000_b.sql"):
        open(os.path.join(tmp, n), "w").write("select 1;\n")
    check("duplicate timestamps rejected", any("already used" in p[3] for p in lint.lint_dir(tmp)))
finally:
    shutil.rmtree(tmp)

real = os.path.join(HERE, "..", "..", "..", "backend", "supabase", "migrations")
check("the real migrations directory is clean", lint.lint_dir(real) == [], str(lint.lint_dir(real)))

print(f"\n{sum(results)} passed, {len(results) - sum(results)} failed")
sys.exit(0 if all(results) else 1)

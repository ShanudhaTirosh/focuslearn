"""Offline tests for migrate.sh and run-pgtap.sh using a stand-in `docker` that plays the role of psql.
Proves the runner logic (ordering, checksums, transactions, stop-on-failure, lint gate, TAP judging).
Does NOT prove real PostgreSQL behaviour of the SQL itself: that is what run-pgtap.sh does against a real database."""
import hashlib, os, shutil, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.abspath(os.path.join(HERE, ".."))
INFRA = os.path.abspath(os.path.join(SCRIPTS, ".."))
results = []

def check(name, cond, detail=""):
    results.append(bool(cond)); print(("PASS  " if cond else "FAIL  ") + name + (f"   [{detail}]" if (detail and not cond) else ""))

SHIM = r'''#!/usr/bin/env bash
echo "$*" >> "$FAKE_DIR/docker.log"
sql=""; file_mode=0; args=("$@")
for ((i=0;i<${#args[@]};i++)); do
  [ "${args[i]}" = "-c" ] && sql="${args[i+1]}"
  [ "${args[i]}" = "-f" ] && file_mode=1
done
if [ -n "$sql" ]; then
  case "$sql" in
    *"create schema if not exists supabase_migrations"*) exit 0;;
    *"select version from supabase_migrations.schema_migrations"*) [ -f "$FAKE_DIR/applied.txt" ] && cat "$FAKE_DIR/applied.txt"; exit 0;;
    *"focuslearn_checksums"*) [ -f "$FAKE_DIR/sums.txt" ] && cat "$FAKE_DIR/sums.txt"; exit 0;;
  esac
  exit 0
fi
if [ "$file_mode" = 1 ]; then
  if [ -n "${FAKE_TAP_FILE:-}" ]; then cat > /dev/null; cat "$FAKE_TAP_FILE"; exit "${FAKE_PSQL_RC:-0}"; fi
  n=$(ls "$FAKE_DIR"/apply-*.sql 2>/dev/null | wc -l); out="$FAKE_DIR/apply-$((n+1)).sql"
  cat > "$out"
  if [ -n "${FAKE_FAIL_ON:-}" ] && grep -q "$FAKE_FAIL_ON" "$out"; then echo "ERROR: boom" >&2; exit 3; fi
  exit 0
fi
exit 0
'''

def build(name):
    root = os.path.join(tmp, name)
    for d in ("infra/scripts", "infra/docker/stack", "backend/supabase/migrations", "backend/supabase/tests", "bin"):
        os.makedirs(os.path.join(root, d))
    for f in ("migrate.sh", "run-pgtap.sh", "lint-migrations.py"):
        shutil.copy(os.path.join(SCRIPTS, f), os.path.join(root, "infra/scripts", f))
    shutil.copy(os.path.join(INFRA, "docker", "lib.sh"), os.path.join(root, "infra/docker/lib.sh"))
    open(os.path.join(root, "infra/docker/stack/.env"), "w").write("POSTGRES_PASSWORD=pg-secret-value\n")
    p = os.path.join(root, "bin/docker"); open(p, "w").write(SHIM); os.chmod(p, 0o755)
    return root

def mig(root, name, sql="select 1;\n"):
    p = os.path.join(root, "backend/supabase/migrations", name); open(p, "w").write(sql); return hashlib.sha256(sql.encode()).hexdigest()

def run(root, script, *args, **env):
    e = dict(os.environ); e["PATH"] = os.path.join(root, "bin") + os.pathsep + e["PATH"]; e["FAKE_DIR"] = root; e.update({k: str(v) for k, v in env.items()})
    return subprocess.run(["bash", os.path.join(root, "infra/scripts", script), *args], capture_output=True, text=True, env=e, timeout=60)

def applies(root):
    return sorted(f for f in os.listdir(root) if f.startswith("apply-"))

tmp = tempfile.mkdtemp(prefix="dbrun-")
try:
    # ---------------------------------------------------------------- migrate.sh
    r1 = build("fresh"); h1 = mig(r1, "20261016000000_baseline.sql", "create schema if not exists private;\n"); h2 = mig(r1, "20261017000000_second.sql")
    r = run(r1, "migrate.sh")
    check("fresh database: both migrations applied", r.returncode == 0 and len(applies(r1)) == 2, r.stderr + r.stdout)
    a1 = open(os.path.join(r1, "apply-1.sql")).read(); a2 = open(os.path.join(r1, "apply-2.sql")).read()
    check("applied in timestamp order", "create schema if not exists private" in a1 and "20261017000000" in a2)
    check("each file runs inside begin ... commit", a1.startswith("begin;") and a1.rstrip().endswith("commit;") and a2.startswith("begin;"))
    check("version, name and sha256 are recorded in the same transaction", "values ('20261016000000', 'baseline')" in a1 and h1 in a1 and h2 in a2)
    check("database password never on a command line", "pg-secret-value" not in open(os.path.join(r1, "docker.log")).read())

    r2 = build("partial"); h1 = mig(r2, "20261016000000_baseline.sql"); mig(r2, "20261017000000_second.sql")
    open(os.path.join(r2, "applied.txt"), "w").write("20261016000000\n"); open(os.path.join(r2, "sums.txt"), "w").write(f"20261016000000 {h1}\n")
    r = run(r2, "migrate.sh")
    check("already-applied migration is skipped", r.returncode == 0 and len(applies(r2)) == 1 and "20261017000000" in open(os.path.join(r2, "apply-1.sql")).read())

    r3 = build("uptodate"); h1 = mig(r3, "20261016000000_baseline.sql")
    open(os.path.join(r3, "applied.txt"), "w").write("20261016000000\n"); open(os.path.join(r3, "sums.txt"), "w").write(f"20261016000000 {h1}\n")
    r = run(r3, "migrate.sh")
    check("nothing pending: reports up to date, applies nothing", r.returncode == 0 and "up to date" in r.stderr + r.stdout and applies(r3) == [])

    r4 = build("edited"); mig(r4, "20261016000000_baseline.sql", "select 'edited after applying';\n"); mig(r4, "20261017000000_second.sql")
    open(os.path.join(r4, "applied.txt"), "w").write("20261016000000\n"); open(os.path.join(r4, "sums.txt"), "w").write("20261016000000 " + "0" * 64 + "\n")
    r = run(r4, "migrate.sh")
    check("an applied migration that was edited is refused, and NOTHING is applied", r.returncode != 0 and applies(r4) == [] and "changed after it was applied" in r.stderr, r.stderr)

    r5 = build("order"); mig(r5, "20261016000000_a.sql"); mig(r5, "20261017000000_b.sql"); mig(r5, "20261018000000_c.sql")
    open(os.path.join(r5, "applied.txt"), "w").write("20261016000000\n20261018000000\n")
    open(os.path.join(r5, "sums.txt"), "w").write("")
    r = run(r5, "migrate.sh")
    check("a pending migration older than the newest applied one is refused", r.returncode != 0 and applies(r5) == [] and "older than the newest applied" in r.stderr, r.stderr)
    r = run(r5, "migrate.sh", "--allow-out-of-order")
    check("--allow-out-of-order overrides the refusal", r.returncode == 0 and len(applies(r5)) == 1)

    r6 = build("fail"); mig(r6, "20261016000000_a.sql", "select 1;\n"); mig(r6, "20261017000000_b.sql", "select 'BOOM';\n"); mig(r6, "20261018000000_c.sql", "select 3;\n")
    r = run(r6, "migrate.sh", FAKE_FAIL_ON="BOOM")
    check("failure stops the run: later migrations are not attempted", r.returncode != 0 and len(applies(r6)) == 2 and "FAILED and was rolled back" in r.stderr, r.stderr)

    r7 = build("lint"); mig(r7, "20261016000000_bad.sql", "create table public.t (id int);\n")
    r = run(r7, "migrate.sh")
    check("a lint failure blocks everything (fail closed)", r.returncode != 0 and applies(r7) == [] and "lint failed" in r.stderr and "RLS-ENABLE" in r.stdout, r.stdout + r.stderr)
    r8 = build("txn"); mig(r8, "20261016000000_txn.sql", "begin;\nselect 1;\ncommit;\n")
    r = run(r8, "migrate.sh")
    check("a migration with its own begin/commit is blocked by the lint gate", r.returncode != 0 and applies(r8) == [] and "TXN-CONTROL" in r.stdout)

    r9 = build("dry"); mig(r9, "20261016000000_a.sql")
    r = run(r9, "migrate.sh", "--dry-run")
    check("--dry-run lists pending and applies nothing", r.returncode == 0 and applies(r9) == [] and "20261016000000_a.sql" in r.stderr + r.stdout and "dry run" in r.stderr + r.stdout)

    r10 = build("remote"); h = mig(r10, "20261017000000_b.sql")
    open(os.path.join(r10, "applied.txt"), "w").write("20261016000000\n"); open(os.path.join(r10, "sums.txt"), "w").write("")
    r = run(r10, "migrate.sh", "--dry-run")
    check("version applied in the database but missing locally only warns", r.returncode == 0 and "has no file here" in r.stderr + r.stdout, r.stderr + r.stdout)
    check("unknown argument rejected", run(r10, "migrate.sh", "--nope").returncode != 0)

    # ---------------------------------------------------------------- run-pgtap.sh
    def tap(root, text, rc=0):
        p = os.path.join(root, "tap.txt"); open(p, "w").write(text)
        open(os.path.join(root, "backend/supabase/tests/000_x.test.sql"), "w").write("select 1;\n")
        return run(root, "run-pgtap.sh", FAKE_TAP_FILE=p, FAKE_PSQL_RC=rc)
    t = build("tap_ok"); r = tap(t, "1..3\nok 1 - a\nok 2 - b\nok 3 - c\n")
    check("pgTAP: all assertions ok -> exit 0", r.returncode == 0 and "PASS  3 assertion" in r.stdout, r.stdout)
    t = build("tap_not_ok"); r = tap(t, "1..2\nok 1 - a\nnot ok 2 - b\n# Failed test 2\n")
    check("pgTAP: a 'not ok' -> exit 1", r.returncode == 1 and "1 failing" in r.stdout and "not ok 2 - b" in r.stdout)
    t = build("tap_plan"); r = tap(t, "1..4\nok 1 - a\nok 2 - b\nok 3 - c\n")
    check("pgTAP: fewer assertions than planned -> exit 1", r.returncode == 1 and "plan says 4" in r.stdout)
    t = build("tap_err"); r = tap(t, "psql:stdin:5: ERROR:  something broke\n", rc=3)
    check("pgTAP: psql error -> exit 1", r.returncode == 1 and "psql exited with 3" in r.stdout)
    t = build("tap_noplan"); r = tap(t, "ok 1 - a\n")
    check("pgTAP: output without a plan -> exit 1", r.returncode == 1 and "no TAP plan" in r.stdout)
    t = build("tap_none"); r = run(t, "run-pgtap.sh")
    check("pgTAP: no test files -> exit 2", r.returncode == 2)
    t = build("tap_pw"); tap(t, "1..1\nok 1 - a\n")
    log = open(os.path.join(t, "docker.log")).read()
    check("pgTAP: database password never on a command line (and docker was really invoked)", log.strip() != "" and "pg-secret-value" not in log)
finally:
    shutil.rmtree(tmp, ignore_errors=True)

print(f"\n{sum(results)} passed, {len(results) - sum(results)} failed")
sys.exit(0 if all(results) else 1)

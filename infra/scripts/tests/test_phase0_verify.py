"""Offline tests for phase0-verify.sh. Every check script is replaced by a stand-in whose output and exit code the test controls."""
import os, shutil, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.abspath(os.path.join(HERE, ".."))
INFRA = os.path.abspath(os.path.join(SCRIPTS, ".."))
results = []

def check(name, cond, detail=""):
    results.append(bool(cond)); print(("PASS  " if cond else "FAIL  ") + name + (f"   [{detail}]" if (detail and not cond) else ""))

SH = '#!/usr/bin/env bash\necho "$*" > "$CTL/{id}.args"\n[ -f "$CTL/{id}.out" ] && cat "$CTL/{id}.out"\nexit $(cat "$CTL/{id}.rc" 2>/dev/null || echo 0)\n'
PY = '#!/usr/bin/env python3\nimport os, sys\nc = os.environ["CTL"]\nopen(c + "/{id}.args", "w").write(" ".join(sys.argv[1:]))\np = c + "/{id}.out"\nif os.path.exists(p): sys.stdout.write(open(p).read())\nrc = c + "/{id}.rc"\nsys.exit(int(open(rc).read()) if os.path.exists(rc) else 0)\n'
STUBS = {  # id -> (relative path, kind)
    "tests": ("infra/scripts/tests/run-all.sh", SH), "lint": ("infra/scripts/lint-migrations.py", PY), "audit": ("infra/scripts/audit-host.sh", SH),
    "health": ("infra/scripts/healthcheck.sh", SH), "exposure": ("infra/scripts/check-exposure.sh", SH), "migrations": ("infra/scripts/migrate.sh", SH),
    "pgtap": ("infra/scripts/run-pgtap.sh", SH), "edge": ("infra/scripts/verify-edge.sh", SH), "emaildns": ("infra/scripts/check-email-dns.sh", SH),
    "heartbeat": ("infra/scripts/heartbeat.sh", SH), "smtp": ("infra/scripts/send-test-email.py", PY), "r2cli": ("infra/backup/r2_cli.py", PY),
    "drill": ("infra/backup/verify-restore.sh", SH), "r2": ("infra/cloudflare/r2-spike/r2_spike.py", PY),
}
tmp = tempfile.mkdtemp(prefix="p0-")

def build(name, stack=True, overlay="FOCUSLEARN_MODE=local\n", backup_env=False, cf_env=False):
    root = os.path.join(tmp, name); ctl = os.path.join(root, "ctl"); os.makedirs(ctl)
    os.makedirs(os.path.join(root, "infra/docker")); os.makedirs(os.path.join(root, "infra/scripts"))
    shutil.copy(os.path.join(SCRIPTS, "phase0-verify.sh"), os.path.join(root, "infra/scripts/phase0-verify.sh"))
    shutil.copy(os.path.join(INFRA, "docker/lib.sh"), os.path.join(root, "infra/docker/lib.sh"))
    open(os.path.join(root, "infra/docker/UPSTREAM_VERSION"), "w").write("self-hosted/v0.8.2\n")
    open(os.path.join(root, "infra/docker/.env"), "w").write(overlay)
    if stack: os.makedirs(os.path.join(root, "infra/docker/stack"))
    for sid, (rel, tpl) in STUBS.items():
        p = os.path.join(root, rel); os.makedirs(os.path.dirname(p), exist_ok=True); open(p, "w").write(tpl.replace("{id}", sid)); os.chmod(p, 0o755)
    if backup_env: open(os.path.join(root, "infra/backup/.env"), "w").write("X=1\n")
    if cf_env: open(os.path.join(root, "infra/cloudflare/.env"), "w").write("X=1\n")
    return root, ctl

def run(root, ctl, *args, **env):
    e = dict(os.environ); e["CTL"] = ctl
    for k in ("P0_EMAIL_DOMAIN", "P0_DKIM_SELECTORS", "P0_TEST_EMAIL", "P0_AGE_IDENTITY"): e.pop(k, None)
    e.update(env)
    return subprocess.run(["bash", os.path.join(root, "infra/scripts/phase0-verify.sh"), *args], capture_output=True, text=True, env=e, timeout=120)

def put(ctl, sid, out=None, rc=None):
    if out is not None: open(os.path.join(ctl, sid + ".out"), "w").write(out)
    if rc is not None: open(os.path.join(ctl, sid + ".rc"), "w").write(str(rc))

try:
    root, ctl = build("allpass")
    r = run(root, ctl)
    out = r.stdout
    check("everything healthy: exit 0 and the markers are present", r.returncode == 0 and "===== FOCUSLEARN PHASE 0 REPORT" in out and "===== END =====" in out, out[-500:])
    check("core steps PASS", all(f"PASS  {t}" in out for t in ("offline test suites", "migration lint", "stack health", "port exposure", "migrations (dry run)", "pgTAP security tests")), out)
    check("optional steps are SKIPped with a reason", "SKIP  public edge - FOCUSLEARN_MODE is not 'public'" in out and "SKIP  email DNS - set P0_EMAIL_DOMAIN" in out and "SKIP  backup in R2 - infra/backup/.env missing" in out and "SKIP  heartbeat ping - HEARTBEAT_URL empty" in out and "SKIP  restore drill - set P0_AGE_IDENTITY" in out, out)
    check("the header reports OS, RAM, Docker and disk encryption", all(k in out for k in ("OS: ", "RAM: ", "Docker: ", "Disk encryption in use: ", "Upstream pin: self-hosted/v0.8.2", "Mode: local")), out[:600])
    check("summary line counts passes and skips", "0 failed" in out and "skipped" in out)

    put(ctl, "health", out="FAIL  containers not healthy:\n  supabase-db (exited/)\nOK    disk 40% used\n", rc=1)
    r = run(root, ctl)
    check("a failing step: exit 1 and the report names it", r.returncode == 1 and "FAIL  stack health" in r.stdout and "1 failed" in r.stdout, r.stdout[-400:])
    check("failing step details are shown indented", "| FAIL  containers not healthy:" in r.stdout and "|   supabase-db (exited/)" in r.stdout, r.stdout)
    check("passing lines of a failing step are not dumped", "disk 40% used" not in r.stdout)

    put(ctl, "health", out="something odd happened\nbad thing\n", rc=3)
    r = run(root, ctl)
    check("a failure without FAIL lines shows the last lines of output", "| bad thing" in r.stdout and "exit 3" in r.stdout)

    put(ctl, "health", out="OK    all good\n", rc=0)
    put(ctl, "audit", out="WARN  one\nWARN  two\nOK    fine\n", rc=0)
    r = run(root, ctl)
    check("warnings are counted on a passing step", "[2 warning(s)]" in r.stdout and "1 with warnings" in r.stdout and r.returncode == 0, r.stdout)

    put(ctl, "audit", out="OK x\n", rc=0)
    put(ctl, "health", out="FAIL  token abcdefghijklmnopqrstuvwxyz0123456789ABCD sent to student@example.org\n", rc=1)
    r = run(root, ctl)
    check("long tokens and e-mail addresses are redacted", "[redacted]" in r.stdout and "[email]" in r.stdout and "abcdefghijklmnopqrstuvwxyz0123456789" not in r.stdout and "student@example.org" not in r.stdout, r.stdout)

    root2, ctl2 = build("nostack", stack=False)
    r = run(root2, ctl2)
    check("no stack: stack steps are skipped, not failed", r.returncode == 0 and r.stdout.count("stack not set up") == 4 and "FAIL" not in r.stdout, r.stdout)

    root3, ctl3 = build("public", overlay="FOCUSLEARN_MODE=public\nHEARTBEAT_URL=https://hc.example/ping/x\n")
    r = run(root3, ctl3)
    check("public mode runs the edge check and the heartbeat", "PASS  public edge" in r.stdout and "PASS  heartbeat ping" in r.stdout, r.stdout)
    put(ctl3, "edge", out="FAIL  studio unauthenticated returned '200 '\n", rc=1)
    r = run(root3, ctl3)
    check("an edge failure fails the report", r.returncode == 1 and "FAIL  public edge" in r.stdout and "studio unauthenticated" in r.stdout)

    root4, ctl4 = build("opts", backup_env=True, cf_env=True)
    put(ctl4, "r2cli", out="daily/20261015T210000Z/db.dump.age\t10\tx\ndaily/20261015T210000Z/manifest.json\t5\tx\ndaily/20261016T210000Z/manifest.json\t5\tx\n")
    r = run(root4, ctl4, P0_EMAIL_DOMAIN="eduapp.example.com", P0_DKIM_SELECTORS="sel1 sel2", P0_TEST_EMAIL="me@example.org", P0_AGE_IDENTITY="/tmp/id.txt")
    check("backup step counts complete sets (manifests)", "PASS  backup in R2 (complete set present)" in r.stdout and "2 complete daily set(s)" in r.stdout, r.stdout)
    check("email DNS gets the domain and one --dkim per selector", open(os.path.join(ctl4, "emaildns.args")).read().strip() == "eduapp.example.com --dkim sel1 --dkim sel2")
    check("test e-mail and drill receive their inputs", "--to me@example.org" in open(os.path.join(ctl4, "smtp.args")).read() and "--identity /tmp/id.txt" in open(os.path.join(ctl4, "drill.args")).read())
    check("R2 spike runs when its env file exists", "PASS  R2 spike" in r.stdout)
    put(ctl4, "r2cli", out="")
    r = run(root4, ctl4)
    check("no complete backup set fails the backup step", r.returncode == 1 and "FAIL  backup in R2" in r.stdout, r.stdout)

    r = run(root, ctl, "--only", "lint")
    check("--only runs just the chosen step", "PASS  migration lint" in r.stdout and "stack health" not in r.stdout and "SKIP" not in r.stdout, r.stdout)
    check("--list prints every id", run(root, ctl, "--list").stdout.split() == "tests lint audit health exposure migrations pgtap edge emaildns backup r2 heartbeat smtp drill".split())
    check("unknown argument exits 2", run(root, ctl, "--nope").returncode == 2)
finally:
    shutil.rmtree(tmp, ignore_errors=True)

print(f"\n{sum(results)} passed, {len(results) - sum(results)} failed")
sys.exit(0 if all(results) else 1)

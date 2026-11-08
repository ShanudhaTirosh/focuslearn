"""Offline tests for the backup tooling. No Docker, Postgres, age or network needed.

Real code under test: r2_cli.py (against a stub S3 server), bk_tools.py, retention, systemd unit rendering.
Orchestration under test with STAND-IN programs: backup.sh and verify-restore.sh run against fake `docker` and `age`
commands. That proves ordering, failure handling and that plaintext never reaches disk or R2. It does NOT prove real
pg_dump, pg_restore or age behaviour: that is what the real restore drill is for.
"""
import base64, copy, datetime, hashlib, http.server, importlib.util, json, os, re, shutil, socketserver, stat, subprocess, sys, tempfile, threading, urllib.parse

HERE = os.path.dirname(os.path.abspath(__file__))
BK = os.path.abspath(os.path.join(HERE, ".."))
INFRA = os.path.abspath(os.path.join(BK, ".."))
results = []


def check(name, cond, detail=""):
    results.append(bool(cond))
    print(("PASS  " if cond else "FAIL  ") + name + (f"   [{detail}]" if (detail and not cond) else ""))


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m


r2cli = load("r2_cli", os.path.join(BK, "r2_cli.py"))
bkt = load("bk_tools", os.path.join(BK, "bk_tools.py"))
UTC = datetime.timezone.utc

# ------------------------------------------------------------------ stub S3 (path style, bucket "testbucket")
STORE = {}
PINGS = []
class S3(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def _auth_ok(self): return self.headers.get("Authorization", "").startswith("AWS4-HMAC-SHA256 Credential=TESTKEY/")
    def _key(self):
        p = urllib.parse.urlparse(self.path); parts = urllib.parse.unquote(p.path).lstrip("/").split("/", 1)
        return (parts[1] if len(parts) > 1 else ""), urllib.parse.parse_qs(p.query)
    def do_PUT(self):
        key, _ = self._key(); n = int(self.headers.get("Content-Length", 0)); body = self.rfile.read(n)
        if not self._auth_ok() or self.headers.get("x-amz-content-sha256") != hashlib.sha256(body).hexdigest():
            self.send_response(403); self.end_headers(); return
        STORE[key] = (body, self.headers.get("x-amz-meta-sha256", "")); self.send_response(200); self.send_header("Content-Length", "0"); self.end_headers()
    def do_GET(self):
        if self.path.startswith("/ping/"):
            PINGS.append(self.path); self.send_response(200); self.send_header("Content-Length", "0"); self.end_headers(); return
        key, q = self._key()
        if not self._auth_ok(): self.send_response(403); self.end_headers(); return
        if not key:  # list, 2 keys per page
            pre = q.get("prefix", [""])[0]; keys = sorted(k for k in STORE if k.startswith(pre))
            start = int(q.get("continuation-token", ["0"])[0]); page = keys[start:start + 2]; more = start + 2 < len(keys)
            xml = '<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/"><IsTruncated>%s</IsTruncated>%s%s</ListBucketResult>' % (
                str(more).lower(), "".join(f"<Contents><Key>{k}</Key><Size>{len(STORE[k][0])}</Size><LastModified>2026-01-01T00:00:00Z</LastModified></Contents>" for k in page),
                f"<NextContinuationToken>{start + 2}</NextContinuationToken>" if more else "")
            b = xml.encode(); self.send_response(200); self.send_header("Content-Length", str(len(b))); self.end_headers(); self.wfile.write(b); return
        if key not in STORE: self.send_response(404); self.end_headers(); return
        body, meta = STORE[key]
        if key.startswith("corrupt/"): body = b"X" + body[1:]
        self.send_response(200); self.send_header("Content-Length", str(len(body))); self.send_header("x-amz-meta-sha256", meta); self.end_headers(); self.wfile.write(body)
    def do_HEAD(self):
        key, _ = self._key()
        if key not in STORE: self.send_response(404); self.end_headers(); return
        self.send_response(200); self.send_header("Content-Length", str(len(STORE[key][0]))); self.end_headers()
    def do_DELETE(self):
        key, _ = self._key(); STORE.pop(key, None); self.send_response(204); self.end_headers()

srv = socketserver.ThreadingTCPServer(("127.0.0.1", 0), S3); srv.daemon_threads = True
threading.Thread(target=srv.serve_forever, daemon=True).start()
ENDPOINT = f"http://127.0.0.1:{srv.server_address[1]}"
CFGTXT = f"R2_ENDPOINT={ENDPOINT}\nR2_BACKUP_BUCKET=testbucket\nR2_BACKUP_KEY_ID=TESTKEY\nR2_BACKUP_SECRET=testsecret\n"

tmp = tempfile.mkdtemp(prefix="bk-test-")
try:
    # ---------------------------------------------------------------- retention (pure)
    now = datetime.datetime(2026, 10, 15, 12, 0, tzinfo=UTC)
    mk = lambda days: "daily/" + (now - datetime.timedelta(days=days)).strftime("%Y%m%dT%H%M%SZ") + "/db.dump.age"
    keys = [mk(d) for d in (1, 5, 13, 14, 20, 60)]
    check("retention: expires sets >= 14 days, keeps newest 3", sorted(r2cli.expired_keys(keys, now, 14, 3)) == sorted([mk(14), mk(20), mk(60)]))
    old = [mk(d) for d in (100, 200, 300, 400)]
    check("retention: stopped backups never prune the newest 3 sets", r2cli.expired_keys(old, now, 14, 3) == [mk(400)])
    check("retention: keys without a timestamp are never returned", r2cli.expired_keys(["daily/notes.txt"], now, 0, 0) == [])
    both = [mk(30) , mk(30).replace("db.dump", "manifest").replace(".age", ".json")]
    check("retention: all objects of an expired set go together", len(r2cli.expired_keys(both + [mk(1), mk(2), mk(3)], now, 14, 3)) == 2)

    # ---------------------------------------------------------------- r2_cli against the stub
    cfgfile = os.path.join(tmp, "r2.env"); open(cfgfile, "w").write(CFGTXT)
    cli = lambda *a: subprocess.run([sys.executable, os.path.join(BK, "r2_cli.py"), "--config", cfgfile, *a], capture_output=True, text=True)
    payload = os.urandom(300000); src = os.path.join(tmp, "src.bin"); open(src, "wb").write(payload)
    r = cli("put", src, "daily/20260101T000000Z/db.dump.age")
    check("put succeeds and stub accepted signed headers + payload hash", r.returncode == 0 and "daily/20260101T000000Z/db.dump.age" in STORE, r.stderr)
    dst = os.path.join(tmp, "dst.bin"); r = cli("get", "daily/20260101T000000Z/db.dump.age", dst)
    check("get round-trips identical bytes and verifies metadata", r.returncode == 0 and open(dst, "rb").read() == payload and "verified" in r.stdout, r.stderr)
    check("downloaded file mode is 600", stat.S_IMODE(os.stat(dst).st_mode) == 0o600)
    STORE["corrupt/x"] = (payload, hashlib.sha256(payload).hexdigest())
    bad = os.path.join(tmp, "bad.bin"); r = cli("get", "corrupt/x", bad)
    check("corrupted download is detected and the file removed", r.returncode != 0 and not os.path.exists(bad))
    for d in ("20260102", "20260103", "20260104"): STORE[f"daily/{d}T000000Z/manifest.json"] = (b"{}", "")
    r = cli("list", "daily/")
    check("list follows pagination (4 keys, 2 per page)", len([l for l in r.stdout.splitlines() if l]) == 4, r.stdout)
    r = cli("delete", "daily/20260104T000000Z/manifest.json")
    check("delete removes the object", r.returncode == 0 and "daily/20260104T000000Z/manifest.json" not in STORE)
    r = cli("prune"); check("prune is a dry run by default", "dry run" in r.stdout and "daily/20260101T000000Z/db.dump.age" in STORE)
    r = cli("prune", "--apply", "--daily-days", "1")
    check("prune --apply keeps the newest 3 sets even when all are expired", r.returncode == 0 and len([k for k in STORE if k.startswith("daily/")]) == 3, r.stdout)

    # ---------------------------------------------------------------- bk_tools
    files = {}
    for n, c in (("db", b"A" * 100), ("sec", b"B" * 50)):
        files[n] = os.path.join(tmp, n + ".bin"); open(files[n], "wb").write(c)
    before = {"pg_version": "15.8", "public_tables_without_rls": 0, "row_counts": {"public.notes": 10, "auth.users": 5}}
    after = {"pg_version": "15.8", "public_tables_without_rls": 0, "row_counts": {"public.notes": 12, "auth.users": 5}}
    man = bkt.build_manifest("20261015T210000Z", files["db"], files["sec"], before, after, "self-hosted/v0.8.2")
    check("manifest records sha256 and size", man["db"]["sha256"] == hashlib.sha256(b"A" * 100).hexdigest() and man["db"]["bytes"] == 100)
    check("check_files passes when names and hashes match", bkt.check_files(man, tmp) == [])
    open(files["db"], "ab").write(b"!"); check("check_files catches a changed file", len(bkt.check_files(man, tmp)) == 1)
    ok, _ = bkt.compare(man, {"pg_version": "15.8", "public_tables_without_rls": 0, "row_counts": {"public.notes": 11, "auth.users": 5}})
    check("compare: count between before and after passes", ok)
    ok, lines = bkt.compare(man, {"pg_version": "15.8", "public_tables_without_rls": 0, "row_counts": {"public.notes": 3, "auth.users": 5}})
    check("compare: lost rows fail", (not ok) and any("public.notes" in l and l.startswith("FAIL") for l in lines))
    ok, _ = bkt.compare(man, {"pg_version": "15.8", "public_tables_without_rls": 0, "row_counts": {"auth.users": 5}})
    check("compare: a missing table fails", not ok)
    ok, _ = bkt.compare(man, {"pg_version": "15.8", "public_tables_without_rls": 1, "row_counts": {"public.notes": 11, "auth.users": 5}})
    check("compare: a public table without RLS fails (security regression)", not ok)
    ok, lines = bkt.compare(man, {"pg_version": "16.1", "public_tables_without_rls": 0, "row_counts": {"public.notes": 11, "auth.users": 5, "public.extra": 1}})
    check("compare: version change and extra table only warn", ok and sum(l.startswith("WARN") for l in lines) == 2)

    secret_a, secret_b = "SUPERSECRETJWT-abcdef", "prod-db-password-xyz"
    cfgj = {"services": {"db": {
        "image": "supabase/postgres:15.8.1.060", "container_name": "supabase-db", "restart": "unless-stopped",
        "ports": ["5432:5432"], "depends_on": {"vector": {"condition": "service_healthy"}}, "networks": ["default"],
        "command": ["postgres", "-c", "config_file=/etc/postgresql/postgresql.conf"],
        "environment": {"POSTGRES_PASSWORD": secret_b, "JWT_SECRET": secret_a, "ANON_KEY": "anon-" + secret_a, "JWT_EXP": "3600", "POSTGRES_DB": "postgres"},
        "volumes": [{"type": "bind", "source": "/srv/stack/volumes/db/data", "target": "/var/lib/postgresql/data"},
                    {"type": "bind", "source": "/srv/stack/volumes/db/roles.sql", "target": "/docker-entrypoint-initdb.d/init-scripts/99-roles.sql", "read_only": True},
                    {"type": "volume", "source": "db-config", "target": "/etc/postgresql-custom"}]}}}
    iso = bkt.isolate(cfgj); blob = json.dumps(iso); s = iso["services"]["db"]
    check("isolate: production secrets never appear in the output", secret_a not in blob and secret_b not in blob)
    check("isolate: no ports, no dependencies, fixed container name", "ports" not in s and "depends_on" not in s and s["container_name"] == "focuslearn-restore-db")
    check("isolate: data directory moves to a fresh named volume", {"type": "volume", "source": "drill-pgdata", "target": "/var/lib/postgresql/data"} in s["volumes"] and "drill-pgdata" in iso["volumes"])
    check("isolate: init-script mounts and image are preserved", any(v.get("target", "").endswith("99-roles.sql") for v in s["volumes"]) and s["image"] == "supabase/postgres:15.8.1.060")
    check("isolate: non-secret settings kept, secret-like settings replaced", s["environment"]["JWT_EXP"] == "3600" and s["environment"]["POSTGRES_PASSWORD"] == bkt.DRILL_PASSWORD)
    check("isolate: named volumes get drill- prefix", any(v.get("source") == "drill-db-config" for v in s["volumes"]))

    # ---------------------------------------------------------------- orchestration with stand-in programs
    def build_tree(name):
        root = os.path.join(tmp, name); os.makedirs(os.path.join(root, "infra", "backup")); os.makedirs(os.path.join(root, "infra", "cloudflare", "r2-spike"))
        os.makedirs(os.path.join(root, "infra", "docker", "stack", "cloudflared")); os.makedirs(os.path.join(root, "bin"))
        for f in ("backup.sh", "verify-restore.sh", "r2_cli.py", "bk_tools.py", "stats.sql"): shutil.copy(os.path.join(BK, f), os.path.join(root, "infra", "backup", f))
        shutil.copy(os.path.join(INFRA, "cloudflare", "r2-spike", "r2_spike.py"), os.path.join(root, "infra", "cloudflare", "r2-spike"))
        shutil.copy(os.path.join(INFRA, "docker", "lib.sh"), os.path.join(root, "infra", "docker"))
        w = lambda rel, txt: open(os.path.join(root, rel), "w").write(txt)
        w("infra/docker/UPSTREAM_VERSION", "self-hosted/v0.8.2\n"); w("infra/docker/.env", "FOCUSLEARN_MODE=local\n")
        w("infra/docker/stack/.env", "POSTGRES_PASSWORD=pg-secret-value\nJWT_SECRET=jwt-secret-value\n"); w("infra/docker/stack/cloudflared/abc.json", '{"TunnelSecret":"tunnel-secret-value"}')
        w("infra/backup/.env", CFGTXT + "BACKUP_AGE_RECIPIENT=age1testrecipient\nMIN_DUMP_BYTES=1000\n" + f"BACKUP_PING_URL={ENDPOINT}/ping/bk\n")
        w("bin/docker", '''#!/usr/bin/env bash
echo "$*" >> "$FAKE_DIR/docker.log"
case "$*" in
 *"config --format json"*) cat "$FAKE_COMPOSE_JSON"; exit 0;;
 *pg_dump*) [ "${FAKE_PGDUMP_FAIL:-0}" = 1 ] && { echo "pg_dump: error: boom" >&2; exit 1; }; for i in $(seq 1 3000); do printf 'FAKEDUMP'; done; exit 0;;
 *focuslearn-restore-db*psql*) cat > /dev/null; cat "$FAKE_RESTORED_STATS"; exit 0;;
 *psql*) cat > /dev/null; cat "$FAKE_STATS"; exit 0;;
 *pg_restore*) cat > "$FAKE_DIR/restore.stdin"; echo "pg_restore: error: could not execute query: role exists" >&2; exit 1;;
 *) exit 0;;
esac
''')
        w("bin/age", '''#!/usr/bin/env python3
import sys, base64
a = sys.argv[1:]
def idfile_rec(p): return open(p).read().strip().replace("ID-FOR:", "")
if "-d" in a:
    ident = a[a.index("-i") + 1]; src = a[-1]
    raw = open(src, "rb").read().split(b"\\n", 2)
    if raw[0] != b"FAKEAGE1" or raw[1].decode() != idfile_rec(ident): sys.stderr.write("age: error: no identity matched\\n"); sys.exit(1)
    sys.stdout.buffer.write(base64.b64decode(raw[2])); sys.exit(0)
rec = a[a.index("-r") + 1]; out = a[a.index("-o") + 1]
data = sys.stdin.buffer.read()
open(out, "wb").write(b"FAKEAGE1\\n" + rec.encode() + b"\\n" + base64.b64encode(data))
''')
        for b in ("docker", "age"): os.chmod(os.path.join(root, "bin", b), 0o755)
        return root

    def run(root, script, *args, **env):
        e = dict(os.environ); e["PATH"] = os.path.join(root, "bin") + os.pathsep + e["PATH"]; e["FAKE_DIR"] = root; e["BACKUP_DOW_OVERRIDE"] = "3"
        e["FAKE_STATS"] = os.path.join(root, "stats.json"); e["FAKE_RESTORED_STATS"] = os.path.join(root, "restored.json"); e["FAKE_COMPOSE_JSON"] = os.path.join(root, "compose.json")
        e.update({k: str(v) for k, v in env.items()})
        return subprocess.run(["bash", os.path.join(root, "infra", "backup", script), *args], capture_output=True, text=True, env=e, timeout=120)

    stats = {"pg_version": "15.8", "public_tables_without_rls": 0, "row_counts": {"public.notes": 7, "auth.users": 3}}
    def seed(root, restored=None):
        json.dump(stats, open(os.path.join(root, "stats.json"), "w")); json.dump(restored or stats, open(os.path.join(root, "restored.json"), "w")); json.dump(cfgj, open(os.path.join(root, "compose.json"), "w"))

    STORE.clear(); root = build_tree("ok"); seed(root)
    r = run(root, "backup.sh", BACKUP_TS_OVERRIDE="20261015T210000Z")
    check("backup.sh succeeds", r.returncode == 0, r.stderr[-300:])
    check("success pings the monitor exactly once, without /fail", PINGS == ["/ping/bk"], str(PINGS))
    ks = sorted(STORE)
    check("uploads the full set, manifest last in the set", ks == ["daily/20261015T210000Z/db.dump.age", "daily/20261015T210000Z/manifest.json", "daily/20261015T210000Z/secrets.tar.age"], str(ks))
    man = json.loads(STORE["daily/20261015T210000Z/manifest.json"][0])
    check("manifest hash equals the uploaded object hash", man["db"]["sha256"] == hashlib.sha256(STORE["daily/20261015T210000Z/db.dump.age"][0]).hexdigest())
    ondisk = b"".join(open(os.path.join(dp, f), "rb").read() for dp, _, fs in os.walk(os.path.join(root, "infra", "backup", "out")) for f in fs)
    check("plaintext dump never written to disk or uploaded", b"FAKEDUMP" not in ondisk and all(b"FAKEDUMP" not in v[0] for v in STORE.values()))
    check("secrets bundle uploaded encrypted (no tunnel secret in clear)", b"tunnel-secret-value" not in STORE["daily/20261015T210000Z/secrets.tar.age"][0] and b"pg-secret-value" not in STORE["daily/20261015T210000Z/secrets.tar.age"][0])
    check("last-success written with an epoch time", re.fullmatch(r"\d{10}", open(os.path.join(root, "infra/backup/out/last-success")).read().strip()) is not None)
    check("database password forwarded without appearing on a command line", "pg-secret-value" not in open(os.path.join(root, "docker.log")).read())
    check("output directory is private (700)", stat.S_IMODE(os.stat(os.path.join(root, "infra/backup/out")).st_mode) == 0o700)

    check("no weekly copy is written on a weekday (the weekday is pinned, so this never depends on the calendar)", not any(k.startswith("weekly/") for k in STORE), str(sorted(STORE)))
    r = run(root, "backup.sh", BACKUP_TS_OVERRIDE="20261016T210000Z", BACKUP_FORCE_WEEKLY=1)
    check("weekly copy is written when forced", any(k.startswith("weekly/20261016T210000Z/") for k in STORE))
    STORE.clear(); rs = build_tree("sunday"); seed(rs)
    r = run(rs, "backup.sh", BACKUP_TS_OVERRIDE="20261018T210000Z", BACKUP_DOW_OVERRIDE="7")
    check("on a Sunday the weekly copy is written with all three objects", sorted(k for k in STORE if k.startswith("weekly/")) == ["weekly/20261018T210000Z/db.dump.age", "weekly/20261018T210000Z/manifest.json", "weekly/20261018T210000Z/secrets.tar.age"], str(sorted(STORE)))
    STORE.clear()
    for d in ("20261017", "20261018", "20261019"): run(root, "backup.sh", BACKUP_TS_OVERRIDE=f"{d}T210000Z")
    sets = [d for d in os.listdir(os.path.join(root, "infra/backup/out")) if re.fullmatch(r"\d{8}T\d{6}Z", d)]
    check("only the newest 3 sets are kept locally", len(sets) == 3 and "20261015T210000Z" not in sets, str(sets))

    STORE.clear(); root2 = build_tree("fail"); seed(root2)
    PINGS.clear()
    r = run(root2, "backup.sh", BACKUP_TS_OVERRIDE="20261020T210000Z", FAKE_PGDUMP_FAIL=1)
    check("failed backup sends the /fail signal and not the success ping", PINGS == ["/ping/bk/fail"], str(PINGS))
    out2 = os.path.join(root2, "infra/backup/out")
    check("failed pg_dump: non-zero exit, nothing uploaded", r.returncode != 0 and STORE == {}, r.stderr[-200:])
    check("failed pg_dump: no partial files and no last-success", not os.path.exists(os.path.join(out2, "20261020T210000Z")) and not os.path.exists(os.path.join(out2, "last-success")))

    STORE.clear(); root3 = build_tree("small"); seed(root3)
    r = run(root3, "backup.sh", BACKUP_TS_OVERRIDE="20261021T210000Z", FAKE_PGDUMP_FAIL=0)
    open(os.path.join(root3, "infra/backup/.env"), "a").write("MIN_DUMP_BYTES=99999999\n")
    STORE.clear(); r = run(root3, "backup.sh", BACKUP_TS_OVERRIDE="20261022T210000Z")
    check("dump below the minimum size is refused and not uploaded", r.returncode != 0 and STORE == {} and "refusing" in r.stderr, r.stderr[-200:])

    # ---------------------------------------------------------------- monitor URL handling
    STORE.clear(); PINGS.clear(); rb = build_tree("badping"); seed(rb)
    open(os.path.join(rb, "infra/backup/.env"), "a").write("BACKUP_PING_URL=http://example.com/x\n")
    r = run(rb, "backup.sh", BACKUP_TS_OVERRIDE="20261023T210000Z")
    check("a non-https monitor URL is rejected before anything runs", r.returncode != 0 and "must start with https" in r.stderr and STORE == {} and PINGS == [], r.stderr[-200:])
    STORE.clear(); PINGS.clear(); ru = build_tree("deadping"); seed(ru)
    open(os.path.join(ru, "infra/backup/.env"), "a").write("BACKUP_PING_URL=http://127.0.0.1:1/ping/x\n")
    r = run(ru, "backup.sh", BACKUP_TS_OVERRIDE="20261024T210000Z")
    check("an unreachable monitor warns but does not fail the backup", r.returncode == 0 and "could not reach the backup monitor" in r.stdout + r.stderr and len(STORE) == 3, r.stdout[-200:] + r.stderr[-200:])
    check("the monitor URL is never printed", "ping/x" not in r.stdout + r.stderr)
    STORE.clear(); PINGS.clear(); rn = build_tree("noping"); seed(rn)
    open(os.path.join(rn, "infra/backup/.env"), "a").write("BACKUP_PING_URL=\n")
    r = run(rn, "backup.sh", BACKUP_TS_OVERRIDE="20261025T210000Z")
    check("with no monitor URL the backup works and pings nothing", r.returncode == 0 and PINGS == [])

    # ---------------------------------------------------------------- restore drill
    STORE.clear(); root4 = build_tree("drill"); seed(root4)
    run(root4, "backup.sh", BACKUP_TS_OVERRIDE="20261015T210000Z")
    ident = os.path.join(root4, "identity.txt"); open(ident, "w").write("ID-FOR:age1testrecipient\n")
    r = run(root4, "verify-restore.sh", "--identity", ident)
    check("drill: PASS when the restored database matches the manifest", r.returncode == 0 and "RESULT: PASS" in r.stdout, r.stdout[-400:] + r.stderr[-300:])
    check("drill: decrypted bytes reached pg_restore", open(os.path.join(root4, "restore.stdin"), "rb").read() == b"FAKEDUMP" * 3000)
    check("drill: pg_restore errors are reported, not hidden", "error line" in r.stdout and "role exists" in r.stdout)
    check("drill: temp directory with downloaded files removed", not [d for d in os.listdir(os.path.join(root4, "infra/backup/out")) if d.startswith("drill-")])
    check("drill: isolated container is torn down", "down -v" in open(os.path.join(root4, "docker.log")).read())
    check("drill: production password never appears on any docker command line", "pg-secret-value" not in open(os.path.join(root4, "docker.log")).read())

    seed(root4, restored={"pg_version": "15.8", "public_tables_without_rls": 0, "row_counts": {"public.notes": 1, "auth.users": 3}})
    r = run(root4, "verify-restore.sh", "--identity", ident)
    check("drill: FAIL (exit 1) when rows are missing after restore", r.returncode == 1 and "RESULT: FAIL" in r.stdout)

    seed(root4); wrong = os.path.join(root4, "wrong.txt"); open(wrong, "w").write("ID-FOR:age1someoneelse\n")
    r = run(root4, "verify-restore.sh", "--identity", wrong)
    check("drill: wrong identity stops early with a clear error", r.returncode != 0 and "cannot decrypt" in r.stderr, r.stderr[-200:])

    STORE.clear(); root5 = build_tree("tamper"); seed(root5); run(root5, "backup.sh", BACKUP_TS_OVERRIDE="20261015T210000Z")
    k = "daily/20261015T210000Z/db.dump.age"; b, m = STORE[k]; STORE[k] = (b[:-5] + b"AAAAA", hashlib.sha256(b[:-5] + b"AAAAA").hexdigest())
    ident5 = os.path.join(root5, "id.txt"); open(ident5, "w").write("ID-FOR:age1testrecipient\n")
    r = run(root5, "verify-restore.sh", "--identity", ident5)
    check("drill: an object altered in R2 (even with fixed metadata) is rejected by the manifest", r.returncode != 0 and "do not match the manifest" in (r.stdout + r.stderr), r.stdout[-300:] + r.stderr[-300:])

    # ---------------------------------------------------------------- systemd units
    out = os.path.join(tmp, "units")
    r = subprocess.run(["bash", os.path.join(BK, "install-timer.sh"), "--print-only", out], capture_output=True, text=True)
    check("install-timer --print-only renders both units", r.returncode == 0 and os.path.exists(os.path.join(out, "focuslearn-backup.timer")), r.stderr)
    txt = open(os.path.join(out, "focuslearn-backup.service")).read()
    check("rendered unit has no unresolved placeholders", "@" not in txt)
    if shutil.which("systemd-analyze"):
        v = subprocess.run(["systemd-analyze", "verify", os.path.join(out, "focuslearn-backup.service"), os.path.join(out, "focuslearn-backup.timer")], capture_output=True, text=True)
        problems = [l for l in (v.stdout + v.stderr).splitlines() if l.strip() and "focuslearn-backup" in l and "docker.service" not in l]
        check("systemd-analyze verify finds no problems in the units", not problems, "\n".join(problems))
        t = subprocess.run(["systemd-analyze", "calendar", "*-*-* 21:00:00 UTC"], capture_output=True, text=True)
        check("OnCalendar expression parses (next run at 21:00 UTC)", t.returncode == 0 and "21:00:00" in t.stdout, t.stderr)
finally:
    srv.shutdown(); shutil.rmtree(tmp, ignore_errors=True)

print(f"\n{sum(results)} passed, {len(results) - sum(results)} failed")
sys.exit(0 if all(results) else 1)

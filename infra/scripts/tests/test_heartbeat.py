"""Offline tests for heartbeat.sh and its timer units. A local HTTP server plays the external monitor."""
import http.server, os, shutil, socketserver, subprocess, sys, tempfile, threading

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.abspath(os.path.join(HERE, ".."))
INFRA = os.path.abspath(os.path.join(SCRIPTS, ".."))
results, hits = [], []

def check(name, cond, detail=""):
    results.append(bool(cond)); print(("PASS  " if cond else "FAIL  ") + name + (f"   [{detail}]" if (detail and not cond) else ""))

class Mon(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def _rec(self, body=b""):
        hits.append((self.command, self.path, body))
        code = 404 if self.path.startswith("/ping/missing") else 200
        self.send_response(code); self.send_header("Content-Length", "0"); self.end_headers()
    def do_GET(self): self._rec()
    def do_POST(self): self._rec(self.rfile.read(int(self.headers.get("Content-Length", 0))))

srv = socketserver.ThreadingTCPServer(("127.0.0.1", 0), Mon); srv.daemon_threads = True
threading.Thread(target=srv.serve_forever, daemon=True).start()
BASE = f"http://127.0.0.1:{srv.server_address[1]}"

tmp = tempfile.mkdtemp(prefix="hb-")
try:
    root = os.path.join(tmp, "repo"); os.makedirs(os.path.join(root, "infra/scripts")); os.makedirs(os.path.join(root, "infra/docker"))
    shutil.copy(os.path.join(SCRIPTS, "heartbeat.sh"), os.path.join(root, "infra/scripts/heartbeat.sh"))
    shutil.copy(os.path.join(INFRA, "docker/lib.sh"), os.path.join(root, "infra/docker/lib.sh"))
    def setenv(url): open(os.path.join(root, "infra/docker/.env"), "w").write(f"FOCUSLEARN_MODE=local\nHEARTBEAT_URL={url}\n")
    def fake_hc(code, text=""):
        p = os.path.join(tmp, "hc.sh"); open(p, "w").write(f"#!/usr/bin/env bash\nprintf '%s' '{text}'\nexit {code}\n"); os.chmod(p, 0o755); return p
    def run(hc):
        hits.clear(); e = dict(os.environ); e["HEARTBEAT_HEALTHCHECK"] = hc
        return subprocess.run(["bash", os.path.join(root, "infra/scripts/heartbeat.sh")], capture_output=True, text=True, env=e, timeout=60)

    setenv(f"{BASE}/ping/abc")
    r = run(fake_hc(0))
    check("healthy: exit 0 and a plain GET to the ping URL", r.returncode == 0 and hits == [("GET", "/ping/abc", b"")], str(hits) + r.stderr)

    r = run(fake_hc(1, "FAIL  disk 91% used (limit 85%)"))
    check("unhealthy: exit 1 and a POST to <url>/fail", r.returncode == 1 and len(hits) == 1 and hits[0][0] == "POST" and hits[0][1] == "/ping/abc/fail", str(hits) + r.stderr)
    check("unhealthy: the body carries the failing line", hits and b"disk 91%" in hits[0][2])

    r = run(fake_hc(1, "x" * 5000))
    check("the failure body is truncated to 500 bytes", hits and len(hits[0][2]) == 500, str([len(h[2]) for h in hits]))

    setenv(f"{BASE}/ping/abc/")
    r = run(fake_hc(1, "FAIL  x"))
    check("a trailing slash in the URL does not produce //fail", hits and hits[0][1] == "/ping/abc/fail", str(hits))

    setenv(f"{BASE}/ping/missing-secret-token")
    r = run(fake_hc(0))
    check("monitor answers 404: exit 1, and the secret URL is not printed", r.returncode == 1 and "missing-secret-token" not in r.stdout + r.stderr, r.stdout + r.stderr)

    setenv("http://127.0.0.1:1/ping/very-secret-path")
    r = run(fake_hc(0))
    check("monitor unreachable: exit 1, and the secret URL is not printed", r.returncode == 1 and "very-secret-path" not in r.stdout + r.stderr, r.stdout + r.stderr)

    setenv("")
    r = run(fake_hc(0))
    check("empty HEARTBEAT_URL: exit 2 and nothing is sent", r.returncode == 2 and hits == [])
    setenv("http://example.com/ping/abc")
    r = run(fake_hc(0))
    check("plain http to a remote host is refused (exit 2, nothing sent)", r.returncode == 2 and "https://" in r.stderr and hits == [])
    setenv("ftp://example.com/x")
    check("other schemes are refused", run(fake_hc(0)).returncode == 2)

    out = os.path.join(tmp, "units")
    r = subprocess.run(["bash", os.path.join(SCRIPTS, "install-heartbeat.sh"), "--print-only", out], capture_output=True, text=True)
    check("install-heartbeat --print-only renders both units without placeholders", r.returncode == 0 and "@" not in open(os.path.join(out, "focuslearn-heartbeat.service")).read(), r.stderr)
    if shutil.which("systemd-analyze"):
        v = subprocess.run(["systemd-analyze", "verify", os.path.join(out, "focuslearn-heartbeat.service"), os.path.join(out, "focuslearn-heartbeat.timer")], capture_output=True, text=True)
        problems = [l for l in (v.stdout + v.stderr).splitlines() if "focuslearn-heartbeat" in l and "docker.service" not in l]
        check("systemd-analyze verify finds no problems in the heartbeat units", not problems, "\n".join(problems))
    # the installer must refuse while HEARTBEAT_URL is empty (run against the REAL repo files, which ship an empty value)
    real_env = os.path.join(INFRA, "docker/.env")
    if not os.path.exists(real_env):
        r = subprocess.run(["bash", os.path.join(SCRIPTS, "install-heartbeat.sh")], capture_output=True, text=True)
        check("installer refuses to install while HEARTBEAT_URL is empty", r.returncode == 1 and "HEARTBEAT_URL" in r.stderr, r.stderr)
    else:
        print("SKIP  installer-refusal test (a real infra/docker/.env exists here)")
finally:
    srv.shutdown(); shutil.rmtree(tmp, ignore_errors=True)

print(f"\n{sum(results)} passed, {len(results) - sum(results)} failed")
sys.exit(0 if all(results) else 1)

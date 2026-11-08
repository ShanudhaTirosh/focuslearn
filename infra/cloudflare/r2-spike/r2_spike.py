#!/usr/bin/env python3
"""FocusLearn R2 spike (Phase 0.6). Python standard library only. No third-party packages.

Purpose: prove, against YOUR real R2 buckets, the behaviours the file design (ADR-002) depends on.
Run:   python3 infra/cloudflare/r2-spike/r2_spike.py --selftest     # offline: checks the SigV4 signer against the AWS test vector
       python3 infra/cloudflare/r2-spike/r2_spike.py                # online: needs credentials (see infra/cloudflare/.env.example)

This is a throwaway verification tool. Production signing happens in Edge Functions (Phase 4).
It never prints secrets. All spike objects live under spike/<random>/ and are deleted at the end.
"""
import datetime
import hashlib
import hmac
import json
import os
import secrets
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

EMPTY_SHA = hashlib.sha256(b"").hexdigest()
UNSIGNED = "UNSIGNED-PAYLOAD"


# ---------------------------------------------------------------- SigV4 primitives
def _sha(data):
    return hashlib.sha256(data if isinstance(data, bytes) else data.encode()).hexdigest()


def _hmac(key, msg):
    return hmac.new(key, msg.encode(), hashlib.sha256).digest()


def signing_key(secret, datestamp, region, service="s3"):
    k = _hmac(("AWS4" + secret).encode(), datestamp)
    k = _hmac(k, region)
    k = _hmac(k, service)
    return _hmac(k, "aws4_request")


def enc(s):
    return urllib.parse.quote(s, safe="-_.~")


def enc_path(p):
    return urllib.parse.quote(p, safe="/-_.~")


def canonical_query(params):
    return "&".join(f"{enc(k)}={enc(str(v))}" for k, v in sorted(params.items()))


def presign(method, host, path, key_id, secret, region, expires, now=None,
            signed_headers=None, extra_query=None, service="s3"):
    """Return a presigned URL (query-string SigV4, UNSIGNED-PAYLOAD)."""
    t = now or datetime.datetime.now(datetime.timezone.utc)
    amz = t.strftime("%Y%m%dT%H%M%SZ")
    day = t.strftime("%Y%m%d")
    scope = f"{day}/{region}/{service}/aws4_request"
    headers = {"host": host}
    headers.update({k.lower(): v for k, v in (signed_headers or {}).items()})
    names = ";".join(sorted(headers))
    q = {
        "X-Amz-Algorithm": "AWS4-HMAC-SHA256",
        "X-Amz-Credential": f"{key_id}/{scope}",
        "X-Amz-Date": amz,
        "X-Amz-Expires": str(expires),
        "X-Amz-SignedHeaders": names,
    }
    q.update(extra_query or {})
    cq = canonical_query(q)
    ch = "".join(f"{k}:{headers[k].strip()}\n" for k in sorted(headers))
    creq = "\n".join([method, enc_path(path), cq, ch, names, UNSIGNED])
    sts = "\n".join(["AWS4-HMAC-SHA256", amz, scope, _sha(creq)])
    sig = hmac.new(signing_key(secret, day, region, service), sts.encode(), hashlib.sha256).hexdigest()
    return f"https://{host}{enc_path(path)}?{cq}&X-Amz-Signature={sig}"


def sign_request(method, host, path, key_id, secret, region, extra_headers=None,
                 payload_hash=EMPTY_SHA, now=None, query="", service="s3"):
    """Return headers (incl. Authorization) for a header-signed request."""
    t = now or datetime.datetime.now(datetime.timezone.utc)
    amz = t.strftime("%Y%m%dT%H%M%SZ")
    day = t.strftime("%Y%m%d")
    scope = f"{day}/{region}/{service}/aws4_request"
    headers = {"host": host, "x-amz-content-sha256": payload_hash, "x-amz-date": amz}
    headers.update({k.lower(): v for k, v in (extra_headers or {}).items()})
    names = ";".join(sorted(headers))
    ch = "".join(f"{k}:{headers[k].strip()}\n" for k in sorted(headers))
    creq = "\n".join([method, enc_path(path), query, ch, names, payload_hash])
    sts = "\n".join(["AWS4-HMAC-SHA256", amz, scope, _sha(creq)])
    sig = hmac.new(signing_key(secret, day, region, service), sts.encode(), hashlib.sha256).hexdigest()
    out = {k: v for k, v in headers.items() if k != "host"}
    out["Authorization"] = (f"AWS4-HMAC-SHA256 Credential={key_id}/{scope}, "
                            f"SignedHeaders={names}, Signature={sig}")
    return out


# ---------------------------------------------------------------- selftest (offline)
def selftest():
    """AWS documentation example: presigned GET for examplebucket/test.txt (signature published by AWS)."""
    now = datetime.datetime(2013, 5, 24, 0, 0, 0, tzinfo=datetime.timezone.utc)
    url = presign("GET", "examplebucket.s3.amazonaws.com", "/test.txt",
                  "AKIAIOSFODNN7EXAMPLE", "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
                  "us-east-1", 86400, now=now)
    want = "aeeed9bbccd4d02ee5c0109b86d86835f995330da4c265957d157751f604d404"
    ok = url.endswith("X-Amz-Signature=" + want)
    print(("PASS " if ok else "FAIL ") + "SigV4 presign matches the AWS documentation test vector")
    # AWS documentation example: header-signed GET with a Range header.
    h = sign_request("GET", "examplebucket.s3.amazonaws.com", "/test.txt",
                     "AKIAIOSFODNN7EXAMPLE", "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
                     "us-east-1", {"range": "bytes=0-9"}, EMPTY_SHA, now=now)
    want2 = "f0e8bdb87c964420e857bd35b5d6ed310bd44f0170aba48dd91039c6036bdb41"
    ok2 = h["Authorization"].endswith("Signature=" + want2)
    print(("PASS " if ok2 else "FAIL ") + "SigV4 header signing matches the AWS documentation test vector")
    return 0 if (ok and ok2) else 1


# ---------------------------------------------------------------- HTTP helper
def http(method, url, headers=None, data=None, timeout=60):
    req = urllib.request.Request(url, data=data, method=method, headers=headers or {})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, {k.lower(): v for k, v in r.headers.items()}, r.read()
    except urllib.error.HTTPError as e:
        return e.code, {k.lower(): v for k, v in e.headers.items()}, e.read()
    except Exception as e:  # network error
        return 0, {}, str(e).encode()


def load_cfg():
    path = os.path.join(os.path.dirname(__file__), "..", ".env")
    cfg = {}
    if os.path.exists(path):
        for line in open(path, encoding="utf-8"):
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                cfg[k.strip()] = v.strip().strip('"')
    for k in list(os.environ):
        if k.startswith("R2_") or k.startswith("SPIKE_"):
            cfg[k] = os.environ[k]
    return cfg


# ---------------------------------------------------------------- online spike
class Spike:
    def __init__(self, cfg):
        self.acct = cfg["R2_ACCOUNT_ID"]
        self.host = f"{self.acct}.r2.cloudflarestorage.com"
        self.priv = cfg.get("R2_PRIVATE_BUCKET", "focuslearn-private")
        self.bak = cfg.get("R2_BACKUP_BUCKET", "focuslearn-backups")
        self.kid, self.sec = cfg["R2_PRIVATE_KEY_ID"], cfg["R2_PRIVATE_SECRET"]
        self.bkid, self.bsec = cfg.get("R2_BACKUP_KEY_ID"), cfg.get("R2_BACKUP_SECRET")
        self.origin = cfg.get("SPIKE_ALLOWED_ORIGIN", "https://eduapp-admin.shanutechx.com")
        self.prefix = f"spike/{secrets.token_hex(6)}/"
        self.results, self.A, self.B = [], 0, 0

    def check(self, name, ok, detail=""):
        self.results.append(bool(ok))
        print(("PASS " if ok else "FAIL ") + name + (f"   [{detail}]" if detail else ""))

    @staticmethod
    def info(name, detail):
        print("INFO " + name + f"   [{detail}]")

    def url_path(self, bucket, key):
        return f"/{bucket}/{key}"

    def signed(self, method, bucket, key, extra=None, kid=None, sec=None, payload=EMPTY_SHA):
        h = sign_request(method, self.host, self.url_path(bucket, key), kid or self.kid,
                         sec or self.sec, "auto", extra, payload)
        return http(method, f"https://{self.host}{enc_path(self.url_path(bucket, key))}", h)

    def run(self):
        body = os.urandom(1024)
        pend, final = self.prefix + "pending/a.bin", self.prefix + "objects/a.bin"
        path = self.url_path(self.priv, pend)

        # 1. presigned PUT with signed content-type and content-length
        u = presign("PUT", self.host, path, self.kid, self.sec, "auto", 60,
                    signed_headers={"content-type": "text/plain", "content-length": str(len(body))})
        s, _, _ = http("PUT", u, {"Content-Type": "text/plain", "Content-Length": str(len(body))}, body)
        self.A += 1
        self.check("presigned PUT (signed content-type + content-length) accepted", s == 200, f"HTTP {s}")

        # 2. wrong content-type must fail
        u2 = presign("PUT", self.host, self.url_path(self.priv, self.prefix + "pending/b.bin"), self.kid, self.sec,
                     "auto", 60, signed_headers={"content-type": "text/plain"})
        s, _, _ = http("PUT", u2, {"Content-Type": "application/x-evil"}, body)
        self.check("presigned PUT with a different content-type is rejected", s in (400, 403), f"HTTP {s}")

        # 3. is the signed content-length enforced? (decides how we cap upload size)
        u3 = presign("PUT", self.host, self.url_path(self.priv, self.prefix + "pending/c.bin"), self.kid, self.sec,
                     "auto", 60, signed_headers={"content-type": "text/plain", "content-length": "1024"})
        big = os.urandom(2048)
        s, _, _ = http("PUT", u3, {"Content-Type": "text/plain", "Content-Length": str(len(big))}, big)
        if s in (400, 403):
            self.info("size cap via signed content-length", f"ENFORCED (HTTP {s}). Presign with the declared size.")
        else:
            self.info("size cap via signed content-length", f"NOT enforced (HTTP {s}). Rely on confirm-step HEAD check, "
                      "delete oversize objects, and the pending/ lifecycle rule.")
            self.signed("DELETE", self.priv, self.prefix + "pending/c.bin")

        # 4. presigned GET returns the same bytes
        g = presign("GET", self.host, path, self.kid, self.sec, "auto", 60)
        s, _, data = http("GET", g)
        self.B += 1
        self.check("presigned GET returns identical bytes", s == 200 and data == body, f"HTTP {s}")

        # 5. ranged GET for MIME sniffing (first 16 bytes) works with a presigned URL
        s, h, data = http("GET", g, {"Range": "bytes=0-15"})
        self.B += 1
        self.check("ranged GET (bytes=0-15) returns 16 bytes", s == 206 and data == body[:16], f"HTTP {s}")

        # 6. response-content-disposition override (used for download file names)
        g2 = presign("GET", self.host, path, self.kid, self.sec, "auto", 60,
                     extra_query={"response-content-disposition": 'attachment; filename="notes.txt"'})
        s, h, _ = http("GET", g2)
        self.B += 1
        self.check("response-content-disposition override honoured",
                   s == 200 and "attachment" in h.get("content-disposition", ""), f"HTTP {s}")

        # 7. expiry is enforced
        g3 = presign("GET", self.host, path, self.kid, self.sec, "auto", 1)
        time.sleep(3)
        s, _, _ = http("GET", g3)
        self.B += 1
        self.check("expired presigned URL is rejected", s in (400, 403), f"HTTP {s}")

        # 8. anonymous access to a private bucket is denied
        s, _, _ = http("GET", f"https://{self.host}{path}")
        self.B += 1
        self.check("anonymous GET on private bucket denied", s in (401, 403), f"HTTP {s}")

        # 9. HEAD returns size (confirm step)
        s, h, _ = self.signed("HEAD", self.priv, pend)
        self.B += 1
        self.check("HEAD returns content-length", s == 200 and h.get("content-length") == str(len(body)), f"HTTP {s}")

        # 10. copy pending -> objects, delete pending
        cs = urllib.parse.quote(f"/{self.priv}/{pend}", safe="/-_.~")
        s, _, _ = self.signed("PUT", self.priv, final, {"x-amz-copy-source": cs})
        self.A += 1
        self.check("server-side CopyObject pending -> objects", s == 200, f"HTTP {s}")
        s, _, _ = self.signed("DELETE", self.priv, pend)
        self.check("DeleteObject pending", s in (200, 204), f"HTTP {s}")
        s, _, _ = self.signed("HEAD", self.priv, pend)
        self.B += 1
        self.check("pending object is gone", s == 404, f"HTTP {s}")

        # 11. token scoping (least privilege)
        if self.bkid and self.bsec:
            s, _, _ = self.signed("HEAD", self.priv, final, kid=self.bkid, sec=self.bsec)
            self.check("backup token cannot read the private bucket", s in (401, 403), f"HTTP {s}")
            s, _, _ = self.signed("PUT", self.bak, self.prefix + "token-probe", kid=self.kid, sec=self.sec,
                                  payload=_sha(b""))
            self.check("private token cannot write the backups bucket", s in (401, 403), f"HTTP {s}")
            s, _, _ = self.signed("PUT", self.bak, self.prefix + "ok.bin", kid=self.bkid, sec=self.bsec)
            self.A += 1
            self.check("backup token can write the backups bucket", s == 200, f"HTTP {s}")
            self.signed("DELETE", self.bak, self.prefix + "ok.bin", kid=self.bkid, sec=self.bsec)
        else:
            self.info("token scoping", "SKIPPED (set R2_BACKUP_KEY_ID and R2_BACKUP_SECRET to test)")

        # 12. CORS preflight
        for origin, want in ((self.origin, True), ("https://evil.example", False)):
            s, h, _ = http("OPTIONS", f"https://{self.host}{path}", {
                "Origin": origin, "Access-Control-Request-Method": "PUT",
                "Access-Control-Request-Headers": "content-type"})
            allowed = h.get("access-control-allow-origin") in (origin, "*")
            self.check(f"CORS preflight {'allows' if want else 'denies'} {origin}",
                       (allowed == want), f"HTTP {s}")

        # 13. upload speed from this machine (informational: this is the student-side experience proxy)
        big = os.urandom(5 * 1024 * 1024)
        uu = presign("PUT", self.host, self.url_path(self.priv, self.prefix + "pending/speed.bin"), self.kid,
                     self.sec, "auto", 120, signed_headers={"content-type": "application/octet-stream",
                                                            "content-length": str(len(big))})
        t0 = time.time()
        s, _, _ = http("PUT", uu, {"Content-Type": "application/octet-stream", "Content-Length": str(len(big))},
                       big, timeout=300)
        dt = max(time.time() - t0, 0.001)
        self.A += 1
        self.check("5 MiB presigned upload succeeds", s == 200, f"HTTP {s}")
        self.info("upload speed from this machine", f"{len(big) / 1048576 / dt:.2f} MiB/s ({dt:.1f}s)")

        # cleanup (DeleteObject is a free operation)
        for k in (final, self.prefix + "pending/speed.bin", self.prefix + "pending/b.bin", self.prefix + "pending/c.bin"):
            self.signed("DELETE", self.priv, k)
        self.info("operations used by this run (approx.)", f"Class A: {self.A}, Class B: {self.B}")
        ok = all(self.results)
        print(f"\n{sum(self.results)} passed, {len(self.results) - sum(self.results)} failed")
        return 0 if ok else 1


def main():
    if "--selftest" in sys.argv:
        return selftest()
    cfg = load_cfg()
    need = ["R2_ACCOUNT_ID", "R2_PRIVATE_KEY_ID", "R2_PRIVATE_SECRET"]
    missing = [k for k in need if not cfg.get(k)]
    if missing:
        print("Missing: " + ", ".join(missing) + ". Copy infra/cloudflare/.env.example to infra/cloudflare/.env", file=sys.stderr)
        return 2
    return Spike(cfg).run()


if __name__ == "__main__":
    sys.exit(main())

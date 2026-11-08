#!/usr/bin/env python3
"""Minimal R2 client for the backup job. Standard library only. Reuses the SigV4 signer tested in r2_spike.py.

Usage: r2_cli.py [--config FILE] put FILE KEY | get KEY FILE | list PREFIX | delete KEY | prune [--daily-days N] [--weekly-days N] [--keep-min N] [--apply]
Config: environment variables or infra/backup/.env (environment wins): R2_ACCOUNT_ID, R2_BACKUP_BUCKET, R2_BACKUP_KEY_ID, R2_BACKUP_SECRET.
R2_ENDPOINT overrides the endpoint (used by the offline tests). Never prints secrets.
"""
import argparse
import datetime
import hashlib
import importlib.util
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("r2_spike", os.path.join(HERE, "..", "cloudflare", "r2-spike", "r2_spike.py"))
sp = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(sp)

TS_RE = re.compile(r"(\d{8}T\d{6}Z)")
UTC = datetime.timezone.utc


# ---------------------------------------------------------------- retention (pure)
def parse_ts(key):
    m = TS_RE.search(key)
    if not m:
        return None
    return datetime.datetime.strptime(m.group(1), "%Y%m%dT%H%M%SZ").replace(tzinfo=UTC)


def expired_keys(keys, now, days, keep_min):
    """Keys whose backup set is at least `days` old. The newest `keep_min` sets are NEVER returned,
    so a stopped backup job cannot lead to every backup being pruned. Keys without a timestamp are never returned."""
    sets = {}
    for k in keys:
        t = parse_ts(k)
        if t:
            sets.setdefault(t, []).append(k)
    ordered = sorted(sets, reverse=True)
    protected = set(ordered[:keep_min])
    out = []
    for t in ordered:
        if t not in protected and now - t >= datetime.timedelta(days=days):
            out.extend(sorted(sets[t]))
    return out


# ---------------------------------------------------------------- client
def read_env_file(path):
    cfg = {}
    if path and os.path.exists(path):
        for line in open(path, encoding="utf-8"):
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                cfg[k.strip()] = v.strip().strip('"')
    return cfg


class R2:
    def __init__(self, cfg):
        for k in ("R2_BACKUP_KEY_ID", "R2_BACKUP_SECRET"):
            if not cfg.get(k):
                raise SystemExit(f"missing {k}")
        ep = cfg.get("R2_ENDPOINT") or f"https://{cfg.get('R2_ACCOUNT_ID', '')}.r2.cloudflarestorage.com"
        if "R2_ENDPOINT" not in cfg and not cfg.get("R2_ACCOUNT_ID"):
            raise SystemExit("missing R2_ACCOUNT_ID")
        u = urllib.parse.urlparse(ep)
        self.scheme, self.host = u.scheme, u.netloc
        self.bucket = cfg.get("R2_BACKUP_BUCKET") or "focuslearn-backups"
        self.kid, self.sec = cfg["R2_BACKUP_KEY_ID"], cfg["R2_BACKUP_SECRET"]

    def req(self, method, key="", params=None, extra=None, body=None, payload=sp.EMPTY_SHA, length=None):
        path = f"/{self.bucket}" + (f"/{key}" if key else "")
        qs = sp.canonical_query(params) if params else ""
        h = sp.sign_request(method, self.host, path, self.kid, self.sec, "auto", extra, payload, query=qs)
        if length is not None:
            h["Content-Length"] = str(length)
        url = f"{self.scheme}://{self.host}{sp.enc_path(path)}" + (f"?{qs}" if qs else "")
        return urllib.request.urlopen(urllib.request.Request(url, data=body, method=method, headers=h), timeout=300)

    def put(self, file, key):
        h = hashlib.sha256()
        size = 0
        with open(file, "rb") as fh:
            for chunk in iter(lambda: fh.read(1 << 20), b""):
                h.update(chunk)
                size += len(chunk)
        digest = h.hexdigest()
        with open(file, "rb") as fh:
            self.req("PUT", key, extra={"x-amz-meta-sha256": digest}, body=fh, payload=digest, length=size).read()
        with self.req("HEAD", key) as r:
            remote = int(r.headers.get("Content-Length", -1))
        if remote != size:
            raise SystemExit(f"size mismatch after upload: local {size}, remote {remote}")
        return size, digest

    def get(self, key, file):
        h = hashlib.sha256()
        with self.req("GET", key) as r, open(file, "wb") as out:
            meta = r.headers.get("x-amz-meta-sha256")
            for chunk in iter(lambda: r.read(1 << 20), b""):
                h.update(chunk)
                out.write(chunk)
        os.chmod(file, 0o600)
        if meta and meta != h.hexdigest():
            os.unlink(file)
            raise SystemExit(f"checksum mismatch for {key}: object is corrupt or was altered")
        return h.hexdigest(), bool(meta)

    def list(self, prefix):
        out, token = [], None
        while True:
            p = {"list-type": "2", "prefix": prefix}
            if token:
                p["continuation-token"] = token
            with self.req("GET", "", p) as r:
                root = ET.fromstring(r.read())
            ns = root.tag.split("}")[0] + "}" if root.tag.startswith("{") else ""
            for c in root.findall(f"{ns}Contents"):
                out.append((c.findtext(f"{ns}Key"), int(c.findtext(f"{ns}Size") or 0), c.findtext(f"{ns}LastModified") or ""))
            if (root.findtext(f"{ns}IsTruncated") or "false").lower() == "true":
                token = root.findtext(f"{ns}NextContinuationToken")
            else:
                return out

    def delete(self, key):
        self.req("DELETE", key).read()


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", default=os.path.join(HERE, ".env"))
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("put"); p.add_argument("file"); p.add_argument("key")
    p = sub.add_parser("get"); p.add_argument("key"); p.add_argument("file")
    p = sub.add_parser("list"); p.add_argument("prefix")
    p = sub.add_parser("delete"); p.add_argument("key")
    p = sub.add_parser("prune")
    p.add_argument("--daily-days", type=int, default=14)
    p.add_argument("--weekly-days", type=int, default=56)
    p.add_argument("--keep-min", type=int, default=3)
    p.add_argument("--apply", action="store_true")
    a = ap.parse_args(argv)

    cfg = read_env_file(a.config)
    cfg.update({k: v for k, v in os.environ.items() if k.startswith("R2_")})
    c = R2(cfg)
    try:
        if a.cmd == "put":
            size, digest = c.put(a.file, a.key)
            print(f"OK    put {a.key} ({size} bytes, sha256 {digest[:12]}...)")
        elif a.cmd == "get":
            digest, verified = c.get(a.key, a.file)
            print(f"OK    get {a.key} (sha256 {digest[:12]}..., {'verified against object metadata' if verified else 'no metadata to verify'})")
        elif a.cmd == "list":
            for k, s, m in c.list(a.prefix):
                print(f"{k}\t{s}\t{m}")
        elif a.cmd == "delete":
            c.delete(a.key)
            print(f"OK    deleted {a.key}")
        elif a.cmd == "prune":
            now = datetime.datetime.now(UTC)
            total = 0
            for prefix, days in (("daily/", a.daily_days), ("weekly/", a.weekly_days)):
                keys = [k for k, _, _ in c.list(prefix)]
                for k in expired_keys(keys, now, days, a.keep_min):
                    total += 1
                    if a.apply:
                        c.delete(k)
                    print(f"{'DELETED' if a.apply else 'WOULD DELETE'}  {k}")
            print(f"{total} object(s) {'deleted' if a.apply else 'would be deleted (dry run: add --apply)'}")
    except urllib.error.HTTPError as e:
        print(f"FAIL  HTTP {e.code} on {a.cmd}", file=sys.stderr)
        return 1
    except urllib.error.URLError as e:
        print(f"FAIL  network error: {e.reason}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Backup helper tools (standard library only).

  bk_tools.py manifest --ts TS --db FILE --secrets FILE --before JSON --after JSON --upstream REF   (prints manifest JSON)
  bk_tools.py check-files --manifest FILE --dir DIR                                                 (verifies sizes and sha256)
  bk_tools.py compare --manifest FILE --restored JSON                                               (PASS/FAIL on restored stats)
  bk_tools.py isolate --in CONFIG_JSON --out COMPOSE_JSON                                           (isolated, secret-free copy of the db service)
"""
import argparse
import copy
import hashlib
import json
import os
import re
import sys

DRILL_PASSWORD = "drill-only-not-a-secret"
DRILL_REDACTED = "drill-redacted-value-0123456789abcdef0123"
SECRET_KEY_RE = re.compile(r"(PASSWORD|SECRET|TOKEN|KEY)", re.I)
PGDATA = "/var/lib/postgresql/data"
KEEP_KEYS = ("image", "command", "entrypoint", "environment", "healthcheck", "volumes", "user", "working_dir", "shm_size")


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def file_info(path):
    return {"file": os.path.basename(path), "bytes": os.path.getsize(path), "sha256": sha256_file(path)}


def build_manifest(ts, db, secrets, before, after, upstream):
    return {
        "format": 1,
        "timestamp": ts,
        "upstream": upstream,
        "pg_version": after.get("pg_version"),
        "db": file_info(db),
        "secrets": file_info(secrets),
        "stats_before": before,
        "stats_after": after,
    }


def check_files(manifest, directory):
    problems = []
    for part in ("db", "secrets"):
        info = manifest[part]
        path = os.path.join(directory, info["file"])
        if not os.path.exists(path):
            problems.append(f"{info['file']}: missing")
        elif os.path.getsize(path) != info["bytes"]:
            problems.append(f"{info['file']}: size {os.path.getsize(path)} != manifest {info['bytes']}")
        elif sha256_file(path) != info["sha256"]:
            problems.append(f"{info['file']}: sha256 does not match manifest")
    return problems


def compare(manifest, restored):
    """Return (ok, lines). Row counts may legitimately change while the dump runs, so a restored count passes
    if it lies between the counts taken just before and just after the dump."""
    lines, ok = [], True
    before = manifest["stats_before"].get("row_counts", {})
    after = manifest["stats_after"].get("row_counts", {})
    got = restored.get("row_counts", {})
    names = sorted(set(before) | set(after))
    for t in names:
        vals = [v for v in (before.get(t), after.get(t)) if v is not None]
        lo, hi = min(vals), max(vals)
        if t not in got:
            ok = False
            lines.append(f"FAIL  table {t} missing after restore")
        elif lo <= got[t] <= hi:
            lines.append(f"OK    {t}: {got[t]} rows")
        else:
            ok = False
            lines.append(f"FAIL  {t}: restored {got[t]} rows, expected {lo}" + (f" to {hi}" if hi != lo else ""))
    for t in sorted(set(got) - set(names)):
        lines.append(f"WARN  {t}: present after restore but not in the manifest")
    if restored.get("public_tables_without_rls", 0) != 0:
        ok = False
        lines.append(f"FAIL  {restored['public_tables_without_rls']} public table(s) without row level security after restore")
    else:
        lines.append("OK    every public table has row level security enabled")
    mv, rv = str(manifest.get("pg_version", "")), str(restored.get("pg_version", ""))
    if mv.split(".")[0] != rv.split(".")[0]:
        lines.append(f"WARN  Postgres major version differs: backup {mv or '?'}, restore {rv or '?'}")
    if not names:
        lines.append("WARN  manifest has no tables: the row-count check proves nothing")
    return ok, lines


def isolate(config):
    """Build a compose document with only the db service, isolated from production:
    no ports, no dependencies, fixed container name, fresh data volume, and every secret-looking
    environment value replaced by a throwaway literal. Production secrets never reach the output."""
    db = config["services"]["db"]
    svc = {k: copy.deepcopy(db[k]) for k in KEEP_KEYS if k in db}
    svc["container_name"] = "focuslearn-restore-db"
    svc["restart"] = "no"

    env = svc.get("environment") or {}
    if isinstance(env, list):
        env = dict(e.split("=", 1) if "=" in e else (e, "") for e in env)
    clean = {}
    for k, v in env.items():
        if k == "POSTGRES_PASSWORD":
            clean[k] = DRILL_PASSWORD
        elif SECRET_KEY_RE.search(k):
            clean[k] = DRILL_REDACTED
        else:
            clean[k] = v
    svc["environment"] = clean

    volumes, top = [], {}
    for v in svc.get("volumes", []):
        if isinstance(v, dict) and v.get("target") == PGDATA:
            volumes.append({"type": "volume", "source": "drill-pgdata", "target": PGDATA})
            top["drill-pgdata"] = {}
        elif isinstance(v, dict) and v.get("type") == "volume":
            name = "drill-" + str(v.get("source", "vol"))
            volumes.append({"type": "volume", "source": name, "target": v["target"]})
            top[name] = {}
        else:
            volumes.append(v)  # read-only bind mounts of init scripts keep their absolute paths
    svc["volumes"] = volumes
    return {"services": {"db": svc}, "volumes": top}


def main(argv=None):
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("manifest")
    for n in ("ts", "db", "secrets", "before", "after", "upstream"):
        p.add_argument("--" + n, required=True)
    p = sub.add_parser("check-files"); p.add_argument("--manifest", required=True); p.add_argument("--dir", required=True)
    p = sub.add_parser("compare"); p.add_argument("--manifest", required=True); p.add_argument("--restored", required=True)
    p = sub.add_parser("isolate"); p.add_argument("--in", dest="inp", required=True); p.add_argument("--out", required=True)
    a = ap.parse_args(argv)

    load = lambda path: json.load(open(path, encoding="utf-8"))
    if a.cmd == "manifest":
        print(json.dumps(build_manifest(a.ts, a.db, a.secrets, load(a.before), load(a.after), a.upstream.strip()), indent=2, sort_keys=True))
        return 0
    if a.cmd == "check-files":
        problems = check_files(load(a.manifest), a.dir)
        for p_ in problems:
            print("FAIL  " + p_)
        if not problems:
            print("OK    file sizes and sha256 match the manifest")
        return 1 if problems else 0
    if a.cmd == "compare":
        ok, lines = compare(load(a.manifest), load(a.restored))
        print("\n".join(lines))
        print("RESULT: " + ("PASS" if ok else "FAIL"))
        return 0 if ok else 1
    if a.cmd == "isolate":
        out = isolate(load(a.inp))
        fd = os.open(a.out, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w") as fh:
            json.dump(out, fh, indent=2)
        return 0


if __name__ == "__main__":
    sys.exit(main())

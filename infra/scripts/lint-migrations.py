#!/usr/bin/env python3
"""Static safety linter for SQL migrations. Standard library only; needs no database.

Usage: lint-migrations.py [DIR]      (default: backend/supabase/migrations)   exit 1 if any problem is found.

Rules (an escape comment goes directly before the statement and must give a reason):
  NAME           file name is YYYYMMDDHHMMSS_snake_case.sql, timestamps unique
  RLS-ENABLE     every `create table` in public needs `alter table ... enable row level security` in the same file
  RLS-FORCE      ... and `force row level security`
  RLS-DISABLE    disabling or un-forcing row level security is never allowed
  DEFINER-PATH   every SECURITY DEFINER function must `set search_path`
  DEFINER-PUBLIC SECURITY DEFINER functions belong in schema private (escape: -- definer-public-ok: reason)
  GRANT-ANON     granting anything to anon, or a policy for anon (escape: -- anon-ok: reason)
  GRANT-ALL      `grant all` to roles other than service_role or postgres (escape: -- grant-all-ok: reason)
  GRANT-PUBLIC   granting to PUBLIC (escape: -- public-ok: reason)
  POLICY-OPEN    a policy with using (true) or with check (true) (escape: -- policy-open-ok: reason)
  DESTRUCTIVE    drop table, drop schema, truncate (escape: -- destructive-ok: reason)
  TXN-CONTROL    begin, commit, rollback (the runner wraps each file in a transaction)
"""
import os
import re
import sys

NAME_RE = re.compile(r"^(\d{14})_[a-z0-9_]+\.sql$")
IDENT = r'(?:"[^"]+"|[A-Za-z_][\w$]*)'
QNAME = rf"(?P<name>{IDENT}(?:\s*\.\s*{IDENT})?)"
SAFE_GRANT_ROLES = {"service_role", "postgres", "supabase_admin"}


class Stmt:
    def __init__(self, line, code, masked, comments):
        self.line, self.code, self.masked, self.comments = line, code, masked, comments


def tokenize(text):
    """Split SQL into statements. Comments are removed, string and dollar-quote contents are masked (spaces) in `masked`."""
    out, i, n, line = [], 0, len(text), 1
    code, masked, comments, start = [], [], [], None

    def flush():
        nonlocal code, masked, comments, start
        c = "".join(code).strip()
        if c:
            out.append(Stmt(start or 1, c, "".join(masked).strip(), " ".join(comments)))
        code, masked, comments, start = [], [], [], None

    def emit(raw, mask, ln):
        nonlocal start
        if start is None and raw.strip():
            start = ln
        code.append(raw)
        masked.append(mask)

    while i < n:
        c = text[i]
        if text.startswith("--", i):
            j = text.find("\n", i)
            j = n if j == -1 else j
            comments.append(text[i + 2:j])
            i = j
            continue
        if text.startswith("/*", i):
            j = text.find("*/", i + 2)
            j = n if j == -1 else j + 2
            comments.append(text[i + 2:max(j - 2, i + 2)])
            line += text.count("\n", i, j)
            emit(" ", " ", line)
            i = j
            continue
        if c == "'":
            j = i + 1
            while j < n:
                if text[j] == "'":
                    if j + 1 < n and text[j + 1] == "'":
                        j += 2
                        continue
                    break
                j += 1
            seg = text[i:j + 1]
            emit(seg, "''", line)
            line += seg.count("\n")
            i = j + 1
            continue
        if c == '"':
            j = text.find('"', i + 1)
            j = n - 1 if j == -1 else j
            seg = text[i:j + 1]
            emit(seg, seg, line)
            line += seg.count("\n")
            i = j + 1
            continue
        if c == "$" and (i == 0 or not (text[i - 1].isalnum() or text[i - 1] == "_")):
            m = re.match(r"\$([A-Za-z_]\w*)?\$", text[i:])
            if m:
                tag = m.group(0)
                j = text.find(tag, i + len(tag))
                j = n if j == -1 else j + len(tag)
                seg = text[i:j]
                emit(seg, tag + " " + tag, line)
                line += seg.count("\n")
                i = j
                continue
        if c == ";":
            flush()
            i += 1
            continue
        if c == "\n":
            line += 1
        emit(c, c, line)
        i += 1
    flush()
    return out


def norm_name(raw, default_schema="public"):
    parts = [p.strip().strip('"').lower() for p in re.split(r"\s*\.\s*", raw.strip())]
    return (parts[0], parts[1]) if len(parts) == 2 else (default_schema, parts[0])


def lint_text(filename, text):
    problems = []

    def add(line, rule, msg):
        problems.append((filename, line, rule, msg))

    m = NAME_RE.match(filename)
    if not m:
        add(1, "NAME", "file name must look like 20261016000000_short_description.sql")
    stmts = tokenize(text)
    created, rls = {}, {}
    for s in stmts:
        low = re.sub(r"\s+", " ", s.masked.lower())
        com = s.comments.lower()

        t = re.match(rf"^create (?:(?:global |local )?(?:temp|temporary) |unlogged )?table (?:if not exists )?{QNAME}", low, re.I)
        if t and not re.match(r"^create (?:global |local )?(?:temp|temporary) ", low):
            sch, nm = norm_name(t.group("name"))
            if sch == "public":
                created[nm] = s.line
        a = re.match(rf"^alter table (?:only )?(?:if exists )?{QNAME} (enable|force|disable|no force) row level security", low)
        if a:
            sch, nm = norm_name(a.group("name"))
            rls.setdefault((sch, nm), []).append(a.group(2))
            if a.group(2) in ("disable", "no force"):
                add(s.line, "RLS-DISABLE", f"`{a.group(2)} row level security` on {sch}.{nm} is not allowed")

        f = re.match(rf"^create (?:or replace )?function {QNAME}", low)
        if f and re.search(r"\bsecurity definer\b", low):
            sch, nm = norm_name(f.group("name"))
            if not re.search(r"\bset search_path\b", low):
                add(s.line, "DEFINER-PATH", f"SECURITY DEFINER function {sch}.{nm} must `set search_path = ''` (or an explicit list)")
            if sch == "public" and "definer-public-ok:" not in com:
                add(s.line, "DEFINER-PUBLIC", f"SECURITY DEFINER function {sch}.{nm} is exposed through the API: put it in schema private, or add `-- definer-public-ok: reason`")

        if low.startswith("grant ") or re.match(r"^alter default privileges .* grant ", low):
            tail = re.split(r"\bto\b", low, maxsplit=1)[-1] if re.search(r"\bto\b", low) else ""
            roles = {r.strip() for r in re.sub(r"\bwith grant option\b|\bgranted by .*", "", tail).split(",")}
            if "anon" in roles and "anon-ok:" not in com:
                add(s.line, "GRANT-ANON", "grant to anon needs a preceding `-- anon-ok: reason` comment")
            if "public" in roles and "public-ok:" not in com:
                add(s.line, "GRANT-PUBLIC", "grant to PUBLIC needs a preceding `-- public-ok: reason` comment")
            if re.match(r"^(grant|alter default privileges .* grant) all\b", low) and (roles - SAFE_GRANT_ROLES) and "grant-all-ok:" not in com:
                add(s.line, "GRANT-ALL", "`grant all` to " + ", ".join(sorted(roles - SAFE_GRANT_ROLES)) + ": grant only what the policies need, or add `-- grant-all-ok: reason`")

        if low.startswith("create policy"):
            if re.search(r"\bto\b[^()]*\banon\b", low) and "anon-ok:" not in com:
                add(s.line, "GRANT-ANON", "policy for anon needs a preceding `-- anon-ok: reason` comment")
            if re.search(r"\b(using|with check) \( ?true ?\)", low) and "policy-open-ok:" not in com:
                add(s.line, "POLICY-OPEN", "policy that allows every row: add `-- policy-open-ok: reason` if intended")

        if re.match(r"^(drop (table|schema)|truncate)\b", low) and "destructive-ok:" not in com:
            add(s.line, "DESTRUCTIVE", "destructive statement needs a preceding `-- destructive-ok: reason` comment")
        if re.match(r"^(begin|commit|rollback|start transaction|end)\b", low):
            add(s.line, "TXN-CONTROL", "do not use transaction control: the runner wraps each file in a transaction")

    for nm, ln in sorted(created.items(), key=lambda kv: kv[1]):
        acts = rls.get(("public", nm), [])
        if "enable" not in acts:
            add(ln, "RLS-ENABLE", f"table public.{nm} has no `alter table public.{nm} enable row level security` in this file")
        if "force" not in acts:
            add(ln, "RLS-FORCE", f"table public.{nm} has no `alter table public.{nm} force row level security` in this file")
    return problems


def lint_dir(directory):
    problems, seen = [], {}
    for fn in sorted(os.listdir(directory)):
        if not fn.endswith(".sql"):
            continue
        with open(os.path.join(directory, fn), encoding="utf-8") as fh:
            problems += lint_text(fn, fh.read())
        m = NAME_RE.match(fn)
        if m:
            if m.group(1) in seen:
                problems.append((fn, 1, "NAME", f"timestamp {m.group(1)} already used by {seen[m.group(1)]}"))
            seen[m.group(1)] = fn
    return problems


def main(argv):
    here = os.path.dirname(os.path.abspath(__file__))
    d = argv[1] if len(argv) > 1 else os.path.join(here, "..", "..", "backend", "supabase", "migrations")
    if not os.path.isdir(d):
        print(f"no such directory: {d}", file=sys.stderr)
        return 2
    problems = lint_dir(d)
    for fn, line, rule, msg in problems:
        print(f"{fn}:{line}: [{rule}] {msg}")
    n = len([f for f in os.listdir(d) if f.endswith('.sql')])
    print(f"{n} migration file(s) checked, {len(problems)} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

#!/usr/bin/env python3
"""Static consistency checks for the Dart code. Standard library only. It does NOT compile anything and finds no type errors:
it catches cross-file mistakes a compiler would catch late, and enforces project rules.

Usage: check-dart-consistency.py [REPO_ROOT]      exit 1 if any problem; WARN lines never fail.
Rules
  DELIMS         (), [] and {} balance in every .dart file (comments and strings ignored)
  IMPORT         every import/export resolves: dart: libs, declared packages, files that exist
  TOKEN          LightTokens/DarkTokens/Spacing/Radii/Sizes/TypeScale members and context.colors.<name> exist in tokens.g.dart
  RAWCOLOR       no Color(0x...), Colors.x or Color.fromARGB in app or design-system lib code (use tokens)
  L10N-KEY       every l10n.<name> used in the app exists in app_en.arb
  ARB            valid JSON, placeholders have metadata, no metadata without a message, si/ta contain no unknown keys
  HARDCODED      no user-visible string literals in Text(...), labelText:, hintText:, tooltip:, ... in app code (escape: // l10n-ok)
  PLACEHOLDER    no UnimplementedError / "implement here"
  PROVIDER       every <name>Provider that is used is declared
  ROUTE          every Routes.<name> that is used is declared
  TESTS          every package with code has at least one *_test.dart
"""
import json
import os
import re
import sys

SDK_PACKAGES = {"flutter", "flutter_test", "flutter_localizations", "flutter_lints"}


# ---------------------------------------------------------------- Dart lexing helpers
def _skip_block_comment(t, i):
    depth, n = 0, len(t)
    while i < n:
        if t.startswith("/*", i):
            depth += 1
            i += 2
        elif t.startswith("*/", i):
            depth -= 1
            i += 2
            if depth == 0:
                return i
        else:
            i += 1
    return n


def _skip_string(t, i):
    """t[i] is the first quote (or the r of a raw string). Returns the index just after the string."""
    n = len(t)
    raw = False
    if t[i] == "r" and i + 1 < n and t[i + 1] in "'\"":
        raw = True
        i += 1
    q = t[i]
    triple = t.startswith(q * 3, i)
    i += 3 if triple else 1
    while i < n:
        c = t[i]
        if not raw and c == "\\":
            i += 2
            continue
        if not raw and c == "$" and i + 1 < n and t[i + 1] == "{":
            depth, i = 1, i + 2
            while i < n and depth:
                if t[i] in "'\"":
                    i = _skip_string(t, i)
                    continue
                depth += t[i] == "{"
                depth -= t[i] == "}"
                i += 1
            continue
        if triple and t.startswith(q * 3, i):
            return i + 3
        if not triple and c == q:
            return i + 1
        if not triple and c == "\n":
            return i
        i += 1
    return n


def strip_code(t, blank_strings=True):
    """Return the text with comments removed and (optionally) string contents blanked. Line structure is preserved."""
    out, i, n = [], 0, len(t)
    while i < n:
        if t.startswith("//", i):
            j = t.find("\n", i)
            i = n if j == -1 else j
        elif t.startswith("/*", i):
            j = _skip_block_comment(t, i)
            out.append("\n" * t.count("\n", i, j))
            i = j
        elif t[i] in "'\"" or (t[i] == "r" and i + 1 < n and t[i + 1] in "'\"" and (i == 0 or not (t[i - 1].isalnum() or t[i - 1] == "_"))):
            j = _skip_string(t, i)
            seg = t[i:j]
            out.append("''" + "\n" * seg.count("\n") if blank_strings else seg)
            i = j
        else:
            out.append(t[i])
            i += 1
    return "".join(out)


def line_of(text, pos):
    return text.count("\n", 0, pos) + 1


# ---------------------------------------------------------------- repository model
def parse_pubspec(path):
    name, section, deps, pathdeps, cur = None, None, set(), {}, None
    for raw in open(path, encoding="utf-8"):
        line = raw.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        indent = len(line) - len(line.lstrip())
        body = line.split("#")[0].strip()
        if indent == 0:
            key = body.split(":")[0]
            section = key
            if key == "name":
                name = body.split(":", 1)[1].strip()
            cur = None
        elif section in ("dependencies", "dev_dependencies"):
            if indent == 2:
                cur = body.split(":")[0]
                deps.add(cur)
            elif indent >= 4 and cur and body.startswith("path:"):
                pathdeps[cur] = os.path.normpath(os.path.join(os.path.dirname(path), body.split(":", 1)[1].strip()))
    return {"name": name, "deps": deps, "pathdeps": pathdeps, "dir": os.path.dirname(path)}


def find_packages(root):
    pk = []
    for base in ("packages", "apps"):
        d = os.path.join(root, base)
        if os.path.isdir(d):
            for e in sorted(os.listdir(d)):
                p = os.path.join(d, e, "pubspec.yaml")
                if os.path.exists(p):
                    pk.append(parse_pubspec(p))
    return pk


def dart_files(pkg, sub):
    base = os.path.join(pkg["dir"], sub)
    out = []
    for dp, dn, fn in os.walk(base):
        dn[:] = [d for d in dn if d != "generated"]
        out += [os.path.join(dp, f) for f in fn if f.endswith(".dart")]
    return sorted(out)


def tokens_info(root):
    p = os.path.join(root, "packages/design_system/lib/src/tokens.g.dart")
    if not os.path.exists(p):
        return None
    t = open(p, encoding="utf-8").read()
    info = {}
    for cls in ("LightTokens", "DarkTokens", "Spacing", "Radii", "Sizes", "TypeScale"):
        m = re.search(r"abstract final class %s \{(.*?)\n\}" % cls, t, re.S)
        info[cls] = set(re.findall(r"static const \w+ (\w+) =", m.group(1))) if m else set()
    m = re.search(r"class AppColors \{(.*?)\n\}", t, re.S)
    info["AppColors"] = set(re.findall(r"final Color (\w+);", m.group(1))) if m else set()
    return info


# ---------------------------------------------------------------- the checks
def check(root):
    problems, warns = [], []

    def P(path, line, rule, msg):
        problems.append(f"{os.path.relpath(path, root)}:{line}: [{rule}] {msg}")

    pkgs = find_packages(root)
    by_name = {p["name"]: p for p in pkgs}
    tk = tokens_info(root)
    arb_keys, arb_path = None, None
    for p in pkgs:
        cand = os.path.join(p["dir"], "lib/l10n/app_en.arb")
        if os.path.exists(cand):
            arb_path = cand

    # ---- ARB
    if arb_path:
        try:
            en = json.load(open(arb_path, encoding="utf-8"))
        except ValueError as e:
            P(arb_path, 1, "ARB", f"invalid JSON: {e}")
            en = {}
        arb_keys = {k for k in en if not k.startswith("@")}
        for k in arb_keys:
            ph = set(re.findall(r"\{(\w+)\}", str(en[k])))
            meta = en.get("@" + k, {}).get("placeholders", {}) if isinstance(en.get("@" + k), dict) else {}
            if ph and set(meta) != ph:
                P(arb_path, 1, "ARB", f"'{k}' uses placeholders {sorted(ph)} but its @{k} metadata declares {sorted(meta)}")
        for k in en:
            if k.startswith("@") and not k.startswith("@@") and k[1:] not in en:
                P(arb_path, 1, "ARB", f"'{k}' has metadata but no message '{k[1:]}'")
        for loc in ("si", "ta"):
            lp = os.path.join(os.path.dirname(arb_path), f"app_{loc}.arb")
            if os.path.exists(lp):
                try:
                    other = json.load(open(lp, encoding="utf-8"))
                except ValueError as e:
                    P(lp, 1, "ARB", f"invalid JSON: {e}")
                    continue
                unknown = [k for k in other if not k.startswith("@") and k not in en]
                if unknown:
                    P(lp, 1, "ARB", f"keys not in app_en.arb: {unknown[:5]}")
                missing = len(arb_keys) - len([k for k in other if not k.startswith("@") and k in en])
                warns.append(f"INFO  {loc}: {missing} of {len(arb_keys)} strings are untranslated (needs a native-speaker review)")

    declared_providers, used_providers = set(), {}
    routes_declared, used_routes = set(), []
    used_l10n = set()

    for pkg in pkgs:
        is_app = os.path.basename(os.path.dirname(pkg["dir"])) == "apps"
        lib = dart_files(pkg, "lib")
        tests = dart_files(pkg, "test")
        if lib and not any(f.endswith("_test.dart") for f in tests):
            P(pkg["dir"], 1, "TESTS", f"package '{pkg['name']}' has code but no *_test.dart")
        for path in lib + tests:
            text = open(path, encoding="utf-8").read()
            code = strip_code(text)                       # comments and strings removed
            nostr = strip_code(text, blank_strings=False) # comments removed, strings kept
            in_lib = path in lib
            is_tokens = path.endswith("tokens.g.dart")

            # DELIMS
            stack, pairs = [], {")": "(", "]": "[", "}": "{"}
            for idx, ch in enumerate(code):
                if ch in "([{":
                    stack.append((ch, idx))
                elif ch in ")]}":
                    if not stack or stack[-1][0] != pairs[ch]:
                        P(path, line_of(code, idx), "DELIMS", f"unmatched '{ch}'")
                        stack = []
                        break
                    stack.pop()
            if stack:
                P(path, line_of(code, stack[-1][1]), "DELIMS", f"'{stack[-1][0]}' is never closed")

            # IMPORT
            for m in re.finditer(r"""^\s*(?:import|export)\s+'([^']+)'""", nostr, re.M):
                target, ln = m.group(1), line_of(nostr, m.start())
                if target.startswith("dart:"):
                    continue
                if target.startswith("package:"):
                    name, rest = target[len("package:"):].split("/", 1)
                    if name != pkg["name"] and name not in pkg["deps"]:
                        P(path, ln, "IMPORT", f"package '{name}' is not declared in {pkg['name']}/pubspec.yaml")
                        continue
                    owner = by_name.get(name)
                    if owner and "l10n/generated/" not in rest and not os.path.exists(os.path.join(owner["dir"], "lib", rest)):
                        P(path, ln, "IMPORT", f"'{target}' does not exist")
                else:
                    resolved = os.path.normpath(os.path.join(os.path.dirname(path), target))
                    if "l10n/generated/" not in resolved.replace(os.sep, "/") and not os.path.exists(resolved):
                        P(path, ln, "IMPORT", f"'{target}' does not exist")

            # PLACEHOLDER
            for m in re.finditer(r"UnimplementedError\(|implement here", nostr, re.I):
                P(path, line_of(nostr, m.start()), "PLACEHOLDER", "unfinished code")

            if not is_tokens and tk:
                # TOKEN
                for cls in ("LightTokens", "DarkTokens", "Spacing", "Radii", "Sizes", "TypeScale"):
                    for m in re.finditer(r"\b%s\.(\w+)" % cls, code):
                        if m.group(1) not in tk[cls]:
                            P(path, line_of(code, m.start()), "TOKEN", f"{cls}.{m.group(1)} does not exist in tokens.g.dart")
                for m in re.finditer(r"\bcontext\.colors\.(\w+)", code):
                    if m.group(1) not in tk["AppColors"]:
                        P(path, line_of(code, m.start()), "TOKEN", f"context.colors.{m.group(1)} is not a colour token")
                for v in set(re.findall(r"\bfinal (\w+) = context\.colors;", code)):
                    for m in re.finditer(r"\b%s\.(\w+)" % re.escape(v), code):
                        if m.group(1) not in tk["AppColors"]:
                            P(path, line_of(code, m.start()), "TOKEN", f"{v}.{m.group(1)} is not a colour token")

            # RAWCOLOR (library code of apps and the design system, not generated tokens)
            if in_lib and not is_tokens and (is_app or pkg["name"] == "focuslearn_design_system"):
                for m in re.finditer(r"\bColor\(\s*0x|\bColors\.(?!transparent\b)\w+|\bColor\.from(?:ARGB|RGBO)\b", code):
                    P(path, line_of(code, m.start()), "RAWCOLOR", "use a design token (context.colors.*), not a raw colour")

            if is_app and in_lib:
                # L10N-KEY
                for m in re.finditer(r"\bl10n\.(\w+)", code):
                    used_l10n.add(m.group(1))
                    if arb_keys is not None and m.group(1) not in arb_keys and m.group(1) != "localeName":
                        P(path, line_of(code, m.start()), "L10N-KEY", f"l10n.{m.group(1)} is not in app_en.arb")
                # HARDCODED
                lines = nostr.split("\n")
                orig = text.split("\n")
                for i, ln in enumerate(lines):
                    if "l10n-ok" in orig[i]:
                        continue
                    if re.search(r"\bText\(\s*(?:const\s+)?['\"][^'\"]*[A-Za-z]", ln) or re.search(r"\b(?:labelText|hintText|tooltip|semanticLabel|semanticsLabel|helperText|errorText)\s*:\s*['\"][^'\"]*[A-Za-z]", ln):
                        P(path, i + 1, "HARDCODED", "user-visible text must come from l10n (add `// l10n-ok` only for non-UI text)")
                # providers and routes
                for m in re.finditer(r"\bfinal\s+([a-z]\w*Provider)\s*=", code):
                    declared_providers.add(m.group(1))
                for m in re.finditer(r"\b([a-z]\w*Provider)\b", code):
                    decl = re.match(r"final\s+%s\s*=" % re.escape(m.group(1)), code[max(0, m.start() - 6):m.start() + len(m.group(1)) + 3])
                    used_providers.setdefault(m.group(1), []).append((path, line_of(code, m.start())))
                for m in re.finditer(r"\bstatic const (?:String|Set<String>) (\w+)", code):
                    if "class Routes" in code:
                        routes_declared.add(m.group(1))
                for m in re.finditer(r"\bRoutes\.(\w+)", code):
                    used_routes.append((path, line_of(code, m.start()), m.group(1)))

    for name, uses in used_providers.items():
        if name not in declared_providers:
            for path, ln in uses[:3]:
                P(path, ln, "PROVIDER", f"{name} is used but never declared")
    for name in sorted(declared_providers):
        if len(used_providers.get(name, [])) < 2:
            warns.append(f"WARN  provider {name} is declared but never used")
    for path, ln, name in used_routes:
        if name not in routes_declared:
            P(path, ln, "ROUTE", f"Routes.{name} is not declared")
    if arb_keys is not None:
        for k in sorted(arb_keys - used_l10n):
            warns.append(f"WARN  l10n key '{k}' is never used")
    return problems, warns


def main(argv):
    root = os.path.abspath(argv[1]) if len(argv) > 1 else os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    problems, warns = check(root)
    for w in warns:
        print(w)
    for p in problems:
        print("FAIL  " + p)
    n = sum(len(__import__("glob").glob(os.path.join(root, d, "**", "*.dart"), recursive=True)) for d in ("apps", "packages"))
    print(f"{n} Dart file(s) scanned, {len(problems)} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

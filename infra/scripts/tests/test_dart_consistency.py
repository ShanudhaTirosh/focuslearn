"""Tests for check-dart-consistency.py: every rule must fire on a broken fixture and stay quiet on valid look-alikes."""
import importlib.util, json, os, shutil, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
spec = importlib.util.spec_from_file_location("dc", os.path.join(HERE, "..", "check-dart-consistency.py"))
dc = importlib.util.module_from_spec(spec); spec.loader.exec_module(dc)
results = []

def check(name, cond, detail=""):
    results.append(bool(cond)); print(("PASS  " if cond else "FAIL  ") + name + (f"   [{str(detail)[:400]}]" if (detail and not cond) else ""))

TOKENS = open(os.path.join(REPO, "packages/design_system/lib/src/tokens.g.dart"), encoding="utf-8").read()
tmp = tempfile.mkdtemp(prefix="dc-")
counter = [0]

def fixture(files=None, arb=None, si=None, extra_deps=(), with_test=True):
    counter[0] += 1
    root = os.path.join(tmp, f"r{counter[0]}")
    def w(rel, text):
        p = os.path.join(root, rel); os.makedirs(os.path.dirname(p), exist_ok=True); open(p, "w", encoding="utf-8").write(text)
    w("packages/design_system/pubspec.yaml", "name: focuslearn_design_system\ndependencies:\n  flutter:\n    sdk: flutter\n")
    w("packages/design_system/lib/src/tokens.g.dart", TOKENS)
    w("packages/design_system/lib/focuslearn_design_system.dart", "export 'src/tokens.g.dart';\n")
    w("packages/design_system/test/a_test.dart", "void main() {}\n")
    deps = "".join(f"  {d}:\n    sdk: flutter\n" for d in extra_deps)
    w("apps/mobile/pubspec.yaml", "name: app\ndependencies:\n  flutter:\n    sdk: flutter\n  focuslearn_design_system:\n    path: ../../packages/design_system\n" + deps)
    w("apps/mobile/lib/l10n/app_en.arb", json.dumps(arb if arb is not None else {"@@locale": "en", "hello": "Hello", "greet": "Hi {name}", "@greet": {"placeholders": {"name": {"type": "String"}}}}))
    if si is not None:
        w("apps/mobile/lib/l10n/app_si.arb", json.dumps(si))
    w("apps/mobile/lib/routes.dart", "abstract final class Routes {\n  static const String home = '/';\n}\n")
    if with_test:
        w("apps/mobile/test/a_test.dart", "void main() {}\n")
    for rel, text in (files or {}).items():
        w(rel, text)
    return root

def run(**kw):
    problems, warns = dc.check(fixture(**kw))
    return problems, warns

def has(problems, rule, needle=""):
    return any(f"[{rule}]" in p and needle in p for p in problems)

GOOD = "import 'package:flutter/widgets.dart';\nimport 'routes.dart';\nvoid f(dynamic l10n, dynamic context) {\n  final a = l10n.hello;\n  final b = Routes.home;\n}\n"
ok_deps = ("flutter",)
p, w = run(files={"apps/mobile/lib/a.dart": GOOD})
check("a valid fixture has no problems", p == [], p)

# DELIMS and lexing
for name, body, expect_ok in [
    ("an unmatched closing parenthesis", "void f() { g()); }", False),
    ("a never-closed brace", "void f() {", False),
    ("braces inside a string and a comment are ignored", "void f() { var s = '{ ( [ ' ; // } ) ]\n var t = \"}\"; /* { */ }", True),
    ("nested block comments", "/* a /* b */ { still comment */ void f() {}", True),
    ("interpolation containing nested quotes", "void f(Map m) { var s = '${m['k']} and ${m[\"j\"]}'; }", True),
    ("raw strings and triple-quoted strings", "void f() { var r = r'\\{'; var t = '''}\n{'''; var u = \"\"\"(\"\"\"; }", True),
    ("an escaped quote inside a string", "void f() { var s = 'it\\'s {'; }", True),
]:
    p, _ = run(files={"apps/mobile/lib/a.dart": body})
    check(f"DELIMS: {name}", (p == []) if expect_ok else has(p, "DELIMS"), p)

# IMPORT
p, _ = run(files={"apps/mobile/lib/a.dart": "import 'package:http/http.dart';\n"})
check("IMPORT: an undeclared package is reported", has(p, "IMPORT", "'http' is not declared"), p)
p, _ = run(files={"apps/mobile/lib/a.dart": "import 'missing.dart';\n"})
check("IMPORT: a relative import of a missing file is reported", has(p, "IMPORT", "does not exist"), p)
p, _ = run(files={"apps/mobile/lib/a.dart": "import 'package:focuslearn_design_system/nope.dart';\n"})
check("IMPORT: a workspace package file that does not exist is reported", has(p, "IMPORT", "does not exist"), p)
p, _ = run(files={"apps/mobile/lib/a.dart": "import 'dart:async';\nimport 'package:flutter/material.dart';\nimport 'package:focuslearn_design_system/focuslearn_design_system.dart';\nimport 'l10n/generated/app_localizations.dart';\n"})
check("IMPORT: dart: libs, declared packages, workspace files and the generated l10n file are accepted", p == [], p)
p, _ = run(files={"apps/mobile/lib/a.dart": "export 'package:nope/x.dart';\n"})
check("IMPORT: exports are checked too", has(p, "IMPORT"), p)

# TOKEN
for body, needle in [("final x = Spacing.huge;", "Spacing.huge"), ("final x = LightTokens.nope;", "LightTokens.nope"), ("final x = context.colors.nope;", "context.colors.nope"),
                     ("void f(c) { final colors = context.colors; final y = colors.nope; }", "colors.nope"), ("final x = TypeScale.nope;", "TypeScale.nope"), ("final x = Radii.xxl;", "Radii.xxl")]:
    p, _ = run(files={"apps/mobile/lib/a.dart": body + "\n"})
    check(f"TOKEN: {needle} is reported", has(p, "TOKEN", needle), p)
p, _ = run(files={"apps/mobile/lib/a.dart": "final x = Spacing.lg; final y = context.colors.primary; final z = Radii.md; final c = LightTokens.text; final t = TypeScale.body;\nfinal d = context.colors.errorText;\n"})
check("TOKEN: real token names are accepted", p == [], p)

# RAWCOLOR
for body in ("final c = Color(0xFF112233);", "final c = Colors.red;", "final c = Color.fromARGB(255, 1, 2, 3);"):
    p, _ = run(files={"apps/mobile/lib/a.dart": body + "\n"})
    check(f"RAWCOLOR: `{body[:28]}` is reported", has(p, "RAWCOLOR"), p)
p, _ = run(files={"apps/mobile/lib/a.dart": "final c = Colors.transparent;\n", "apps/mobile/test/b_test.dart": "final c = Color(0xFF112233);\n"})
check("RAWCOLOR: Colors.transparent and colours in tests are allowed", p == [], p)

# L10N and HARDCODED
p, _ = run(files={"apps/mobile/lib/a.dart": "void f(dynamic l10n) { l10n.missingKey; }\n"})
check("L10N-KEY: an unknown key is reported", has(p, "L10N-KEY", "missingKey"), p)
for body in ("Text('Hello')", "Text(\"Sign in\")", "Text(const 'x')", "labelText: 'Email'", "tooltip: \"Back\"", "hintText: 'Search'"):
    p, _ = run(files={"apps/mobile/lib/a.dart": "final w = [" + body + "];\n"})
    check(f"HARDCODED: `{body}` is reported", has(p, "HARDCODED"), p)
p, _ = run(files={"apps/mobile/lib/a.dart": "final a = Text(l10n.hello);\nfinal b = Text('');\nfinal c = Text(' ');\nfinal d = Text('12');\nfinal e = Text('Debug') ; // l10n-ok\n// Text('in a comment')\n"})
check("HARDCODED: l10n calls, empty and numeric text, the escape comment and comments are accepted", p == [], p)

# ARB
p, _ = run(arb={"@@locale": "en", "greet": "Hi {name}"})
check("ARB: a placeholder without metadata is reported", has(p, "ARB", "placeholders"), p)
p, _ = run(arb={"@@locale": "en", "hello": "Hello", "@orphan": {}})
check("ARB: metadata without a message is reported", has(p, "ARB", "no message"), p)
p, _ = run(si={"@@locale": "si", "notInEnglish": "x"})
check("ARB: a translation key that does not exist in English is reported", has(p, "ARB", "not in app_en.arb"), p)
p, w = run(si={"@@locale": "si"})
check("ARB: untranslated strings are reported as INFO only", p == [] and any("untranslated" in x for x in w), (p, w))
p, w = run(files={"apps/mobile/lib/a.dart": "void f(dynamic l10n) { l10n.hello; }\n"}, arb={"@@locale": "en", "hello": "Hello", "unusedKey": "x"})
check("ARB: an unused key is a WARN, not a failure", p == [] and any("unusedKey" in x for x in w), (p, w))

# PLACEHOLDER, PROVIDER, ROUTE, TESTS
p, _ = run(files={"apps/mobile/lib/a.dart": "void f() { throw UnimplementedError(); }\n"})
check("PLACEHOLDER: UnimplementedError is reported", has(p, "PLACEHOLDER"), p)
p, _ = run(files={"apps/mobile/lib/a.dart": "void f(ref) { ref.watch(ghostProvider); }\n"})
check("PROVIDER: a provider that is used but never declared is reported", has(p, "PROVIDER", "ghostProvider"), p)
p, _ = run(files={"apps/mobile/lib/a.dart": "final realProvider = Provider((ref) => 1);\nvoid f(ref) { ref.watch(realProvider); }\n"})
check("PROVIDER: a declared and used provider is accepted", p == [], p)
p, w = run(files={"apps/mobile/lib/a.dart": "final lonelyProvider = Provider((ref) => 1);\n"})
check("PROVIDER: a declared but unused provider is a WARN", p == [] and any("lonelyProvider" in x for x in w), (p, w))
p, _ = run(files={"apps/mobile/lib/a.dart": "final r = Routes.nowhere;\n"})
check("ROUTE: an undeclared route constant is reported", has(p, "ROUTE", "nowhere"), p)
p, _ = run(with_test=False)
check("TESTS: a package with code and no tests is reported", has(p, "TESTS"), p)

# the real repository
problems, warns = dc.check(REPO)
check("the real repository has no problems", problems == [], problems)
real_dart = sum(len([f for f in fs if f.endswith(".dart")]) for dp, _, fs in os.walk(REPO))
check("the real repository contains the expected Dart code (at least 30 files)", real_dart >= 30, real_dart)

shutil.rmtree(tmp)
print(f"\n{sum(results)} passed, {len(results) - sum(results)} failed")
sys.exit(0 if all(results) else 1)

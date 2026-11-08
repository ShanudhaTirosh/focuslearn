"""Offline tests for generate_tokens.py: contrast maths, validation, determinism and drift detection."""
import copy, importlib.util, json, os, shutil, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("gen", os.path.join(HERE, "generate_tokens.py"))
gen = importlib.util.module_from_spec(spec); spec.loader.exec_module(gen)
tokens = json.load(open(os.path.join(HERE, "..", "tokens", "tokens.json")))
results = []

def check(name, cond, detail=""):
    results.append(bool(cond)); print(("PASS  " if cond else "FAIL  ") + name + (f"   [{detail}]" if (detail and not cond) else ""))

check("contrast: black on white is 21:1", abs(gen.contrast("#000000", "#FFFFFF") - 21.0) < 0.01)
check("contrast: identical colours are 1:1", abs(gen.contrast("#336699", "#336699") - 1.0) < 1e-9)
check("contrast is symmetric", abs(gen.contrast("#123456", "#ABCDEF") - gen.contrast("#ABCDEF", "#123456")) < 1e-12)
check("contrast: #767676 on white is the well-known AA threshold (4.54)", abs(gen.contrast("#767676", "#FFFFFF") - 4.54) < 0.01)
check("contrast: #777777 on white is just below AA (4.48)", gen.contrast("#777777", "#FFFFFF") < 4.5)
check("spec primary blue on white is 5.17", abs(gen.contrast("#2563EB", "#FFFFFF") - 5.17) < 0.01)

check("the shipped tokens validate with no problems", gen.validate(tokens) == [], str(gen.validate(tokens)))
check("light and dark define the same colour names", set(tokens["colors"]["light"]) == set(tokens["colors"]["dark"]))
check("the spec palette is present unchanged (primary, secondary, text, muted, surface, border, success, warning)",
      all(tokens["colors"]["light"][k] == v for k, v in {"primary": "#2563EB", "secondary": "#3B82F6", "text": "#111827", "textMuted": "#64748B", "surface": "#F8FAFC", "border": "#E2E8F0", "success": "#16A34A", "warning": "#F59E0B", "background": "#FFFFFF"}.items()))
check("spacing scale is increasing", list(tokens["spacing"].values()) == sorted(tokens["spacing"].values()))
check("minimum touch target is at least 48", tokens["sizes"]["minTouchTarget"] >= 48)
check("body text is at least 16 and no style is below 12", tokens["type"]["body"]["size"] >= 16 and min(v["size"] for v in tokens["type"].values()) >= 12)

bad = copy.deepcopy(tokens); bad["colors"]["light"]["textMuted"] = "#AAAAAA"
p = gen.validate(bad)
check("lowering a colour below its minimum is reported with theme, pair and ratio", any("light: textMuted on background" in x and ":1, needs 4.5" in x for x in p), str(p))
bad = copy.deepcopy(tokens); bad["colors"]["dark"]["primary"] = "#1E3A8A"
check("a dark-theme failure is reported too", any(x.startswith("dark: primary on background") for x in gen.validate(bad)))
bad = copy.deepcopy(tokens); bad["colors"]["light"]["primary"] = "blue"
check("a non-hex colour is rejected", any("not a #RRGGBB" in x for x in gen.validate(bad)))
bad = copy.deepcopy(tokens); del bad["colors"]["dark"]["info"]
check("a colour missing from one theme is rejected", any("different colour names" in x for x in gen.validate(bad)))
bad = copy.deepcopy(tokens); bad["pairs"].append({"fg": "nope", "bg": "background", "min": 4.5, "use": "x"})
check("a pair naming an unknown colour is rejected", any("unknown colour" in x for x in gen.validate(bad)))
bad = copy.deepcopy(tokens); bad["colors"]["light"]["warning"] = "#92400E"
check("a documented known failure that starts passing must be removed", any("now PASSES" in x for x in gen.validate(bad)))

dart = gen.gen_dart(tokens); css = gen.gen_css(tokens); rep = gen.gen_report(tokens)
check("generation is deterministic", dart == gen.gen_dart(tokens) and css == gen.gen_css(tokens) and rep == gen.gen_report(tokens))
check("Dart: both theme classes, every colour, correct ARGB literal", "abstract final class LightTokens" in dart and "abstract final class DarkTokens" in dart
      and "static const Color primary = Color(0xFF2563EB);" in dart and "static const Color primary = Color(0xFF60A5FA);" in dart)
check("Dart: every colour name appears in both classes", all(dart.count(f"static const Color {n} = ") == 2 for n in tokens["colors"]["light"]))
check("Dart: AppColors exposes every colour as a field and has light and dark constants", "class AppColors {" in dart and all(f"  final Color {n};" in dart for n in tokens["colors"]["light"]) and "static const AppColors light = AppColors(" in dart and "static const AppColors dark = AppColors(" in dart and "primary: DarkTokens.primary," in dart)
check("Dart: braces are balanced", dart.count("{") == dart.count("}"))
check("Dart: spacing, radii, sizes and type scale are generated", "static const double lg = 16.0;" in dart and "abstract final class Radii" in dart and "static const double minTouchTarget = 48.0;" in dart and "static const TypeSpec body = TypeSpec(16.0, 1.5, 400);" in dart)
check("CSS: light in :root, dark under prefers-color-scheme and under data-theme=dark", ":root {" in css and "@media (prefers-color-scheme: dark)" in css and ':root[data-theme="dark"]' in css)
check("CSS: camelCase names become kebab-case variables", "--fl-color-surface-variant: #F1F5F9;" in css and "--fl-color-on-primary: #FFFFFF;" in css)
check("CSS: braces are balanced", css.count("{") == css.count("}"))
check("report lists every pair and the known failures", all(f"`{p['fg']}` on `{p['bg']}`" in rep for p in tokens["pairs"]) and "do NOT meet the bar" in rep)

check("the committed generated files are up to date (--check passes)", gen.main(["x", "--check"]) == 0)
d = tempfile.mkdtemp(); orig = dict(gen.OUT)
try:
    gen.OUT = {k: os.path.join(d, os.path.basename(v)) for k, v in orig.items()}
    check("--check fails when generated files are missing", gen.main(["x", "--check"]) == 1)
    gen.main(["x"])
    check("generating then checking passes", gen.main(["x", "--check"]) == 0)
    open(gen.OUT["css"], "a").write("/* hand edit */\n")
    check("--check detects a hand-edited generated file", gen.main(["x", "--check"]) == 1)
finally:
    gen.OUT = orig; shutil.rmtree(d)

print(f"\n{sum(results)} passed, {len(results) - sum(results)} failed")
sys.exit(0 if all(results) else 1)

"""Contract tests: hand-written vectors <-> Python reference <-> spec <-> the SQL constraints in the migrations.
The same vectors are loaded by the Dart test (packages/core/test/validation_test.dart), so Dart must match what is proven here."""
import glob, json, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
import reference_validation as ref
V = json.load(open(os.path.join(ROOT, "test-vectors", "validation.json"), encoding="utf-8"))
SPEC = ref.SPEC
results = []

def check(name, cond, detail=""):
    results.append(bool(cond)); print(("PASS  " if cond else "FAIL  ") + name + (f"   [{str(detail)[:300]}]" if (detail and not cond) else ""))

check("vectors file is up to date with its generator", subprocess.run([sys.executable, os.path.join(HERE, "make_vectors.py"), "--check"], capture_output=True).returncode == 0)
for group, cases in V.items():
    names = [c["name"] for c in cases]
    check(f"{group}: case names are unique", len(names) == len(set(names)))

bad = []
for c in V["displayName"]:
    code, norm = ref.client_display_name(c["in"])
    if code != c["client"] or ("normalized" in c and norm != c["normalized"]) or ref.db_display_name(c["in"]) != c["db"]: bad.append(c["name"])
check("displayName: reference matches every vector (client, normalised, db)", not bad, bad)
bad = [c["name"] for c in V["deviceName"] if ref.client_device_name(c["in"])[0] != c["client"] or ref.db_device_name(c["in"]) != c["db"] or ("normalized" in c and ref.client_device_name(c["in"])[1] != c["normalized"])]
check("deviceName: reference matches every vector", not bad, bad)
bad = [c["name"] for c in V["birthYear"] if ref.client_birth_year(c["year"], c["now"]) != c["client"] or ref.db_birth_year(c["year"]) != c["db"] or ref.is_possible_minor(c["year"], c["now"]) != c["minor"]]
check("birthYear: reference matches every vector (client, db, possible minor)", not bad, bad)
bad = [c["name"] for c in V["email"] if ref.client_email(c["in"])[0] != c["client"] or ("normalized" in c and ref.client_email(c["in"])[1] != c["normalized"])]
check("email: reference matches every vector", not bad, bad)
bad = [c["name"] for c in V["password"] if ref.client_password(c["in"], c["email"]) != c["client"]]
check("password: reference matches every vector", not bad, bad)
bad = [c["name"] for c in V["stream"] if ref.client_stream(c["in"]) != c["client"] or ref.db_stream(c["in"]) != c["db"]]
check("stream: reference matches every vector", not bad, bad)
bad = [c["name"] for c in V["subjects"] if ref.client_subjects(c["in"]) != c["client"] or ref.db_subjects(c["in"]) != c["db"]]
check("subjects: reference matches every vector", not bad, bad)
bad = [c["name"] for c in V["avatarKey"] if ref.client_avatar_key(c["in"], c["user"]) != c["client"] or ref.db_avatar_key(c["in"], c["user"]) != c["db"]]
check("avatarKey: reference matches every vector", not bad, bad)
bad = [c["name"] for c in V["timeZone"] if ref.client_time_zone(c["in"]) != c["client"]]
check("timeZone: reference matches every vector", not bad, bad)

bad = [c["name"] for c in V["clientKey"] if ref.client_key(c["in"]) != c["client"]]
check("clientKey: reference matches every vector (secret and service_role keys are refused)", not bad, bad)
bad = [c["name"] for c in V["authError"] if ref.auth_error_kind(c["code"], c["status"], c["network"]) != c["kind"]]
check("authError: reference matches every vector", not bad, bad)
check("authError: every kind used by the UI appears in the vectors", {c["kind"] for c in V["authError"]} >= {"invalid_credentials", "email_not_confirmed", "rate_limited", "captcha_failed", "weak_password", "email_taken", "same_password", "server", "network", "unknown"})

loose = [(g, c["name"]) for g, cases in V.items() for c in cases if c.get("db") == "invalid" and c.get("client") == "ok"]
check("the client is never looser than the database (no vector the db rejects but the client accepts)", not loose, loose)
seen = {c["client"] for g, cases in V.items() if g != "authError" for c in cases}
want = {"secret_key", "ok", "blank", "too_short", "too_long", "control_char", "invalid_format", "out_of_range", "too_young", "unknown_value", "too_many", "common_password", "contains_email", "wrong_owner"}
check("every error code is exercised by at least one vector", want <= seen, want - seen)
check("Sinhala, Tamil, emoji and a zero-width joiner are covered", all(any(x in c["in"] for c in V["displayName"]) for x in ("අ", "த", "\U0001F642", "\u200d")))

# ---- spec <-> SQL parity: the numbers and lists in the migrations must equal the spec
sql = {os.path.basename(p): open(p, encoding="utf-8").read() for p in glob.glob(os.path.join(ROOT, "backend/supabase/migrations/*.sql"))}
allsql = "\n".join(sql.values())
def grab(pattern, text=allsql):
    m = re.search(pattern, text, re.S)
    return m.groups() if m else None
def lst(pattern):
    g = grab(pattern); return [x.strip().strip("'") for x in g[0].split(",")] if g else None

check("SQL parity: display name length", grab(r"char_length\(btrim\(display_name\)\) between (\d+) and (\d+)") == (str(SPEC["displayName"]["min"]), str(SPEC["displayName"]["max"])))
check("SQL parity: birth year range", grab(r"birth_year between (\d+) and (\d+)") == (str(SPEC["birthYear"]["dbMin"]), str(SPEC["birthYear"]["dbMax"])))
check("SQL parity: possible-minor threshold", grab(r"extract\(year from \(now\(\) at time zone 'utc'\)\)::integer - new\.birth_year < (\d+)") == (str(SPEC["birthYear"]["possibleMinorIfYearDifferenceLessThan"]),))
check("SQL parity: subjects limits", grab(r"cardinality\(subjects\) <= (\d+) and char_length\(array_to_string\(subjects, ','\)\) <= (\d+)") == (str(SPEC["subjects"]["maxCount"]), str(SPEC["subjects"]["maxJoinedLength"])))
check("SQL parity: stream list", lst(r"stream in \(([^)]*)\)") == SPEC["streams"])
check("SQL parity: avatar key pattern", grab(r"avatar_key ~ '([^']+)'") == (SPEC["avatarKeyPattern"],))
check("SQL parity: device name length", grab(r"devices_name_chk check \(char_length\(btrim\(name\)\) between (\d+) and (\d+)") == (str(SPEC["deviceName"]["min"]), str(SPEC["deviceName"]["max"])))
check("SQL parity: app version length", grab(r"char_length\(app_version\) <= (\d+)") == (str(SPEC["appVersionMax"]),))
check("SQL parity: platforms", lst(r"platform in \(([^)]*)\)") == SPEC["platforms"])
check("SQL parity: languages", lst(r"language in \(([^)]*)\)") == SPEC["languages"])
check("SQL parity: themes", lst(r"theme in \(([^)]*)\)") == SPEC["themes"])
check("SQL parity: consent kinds", lst(r"kind in \(([^)]*)\)") == SPEC["consentKinds"])
check("SQL: control characters are rejected in display names", "display_name !~ '[[:cntrl:]]'" in allsql)

print(f"\n{sum(results)} passed, {len(results) - sum(results)} failed")
sys.exit(0 if all(results) else 1)

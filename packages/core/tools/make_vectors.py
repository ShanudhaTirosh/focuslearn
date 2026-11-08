#!/usr/bin/env python3
"""Writes test-vectors/validation.json. The EXPECTED results below are written by hand and are independent of any implementation.
The Python reference and the Dart implementation must both reproduce them. Run: python3 packages/core/tools/make_vectors.py  (or --check)."""
import base64, json, os, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(ROOT, "test-vectors", "validation.json")
SIN = "අ" * 40          # 40 Sinhala letters = 40 code points, 120 UTF-8 bytes
UUID_A = "00000000-0000-0000-0000-0000000000a1"
UUID_B = "00000000-0000-0000-0000-0000000000b2"
OBJ = "00000000-0000-0000-0000-000000000001"

def jwt(role):
    b = lambda o: base64.urlsafe_b64encode(json.dumps(o, separators=(",", ":")).encode()).decode().rstrip("=")
    return b({"alg": "HS256", "typ": "JWT"}) + "." + b({"role": role, "iss": "supabase"}) + ".c2lnbmF0dXJl"

def c(name, inp, client, db=None, **kw):
    d = {"name": name, "in": inp, "client": client}
    if db is not None:
        d["db"] = db
    d.update(kw)
    return d

V = {
  "displayName": [
    c("plain name", "Amal", "ok", "ok"),
    c("spaces around are trimmed", "  Amal  ", "ok", "ok", normalized="Amal"),
    c("empty", "", "blank", "invalid"),
    c("only spaces", "     ", "blank", "invalid"),
    c("exactly 40 characters", "a" * 40, "ok", "ok"),
    c("41 characters", "a" * 41, "too_long", "invalid"),
    c("40 characters plus 5 trailing spaces (trim first)", "a" * 40 + "     ", "ok", "ok", normalized="a" * 40),
    c("40 Sinhala letters count as 40 (code points, not bytes)", SIN, "ok", "ok"),
    c("41 Sinhala letters", SIN + "අ", "too_long", "invalid"),
    c("Sinhala 'shri' contains a zero-width joiner and must be allowed", "ශ්\u200dරී", "ok", "ok"),
    c("Tamil", "தமிழ்", "ok", "ok"),
    c("one emoji counts as one character", "\U0001F642", "ok", "ok"),
    c("40 emoji are 40 characters (UTF-16 would say 80)", "\U0001F642" * 40, "ok", "ok"),
    c("41 emoji", "\U0001F642" * 41, "too_long", "invalid"),
    c("tab inside", "a\tb", "control_char", "invalid"),
    c("newline at the end", "Amal\n", "control_char", "invalid"),
    c("NUL character", "a\u0000b", "control_char", "invalid"),
    c("DEL character", "a\u007fb", "control_char", "invalid"),
    c("C1 control character (NEL)", "a\u0085b", "control_char", "invalid"),
    c("no-break space only: the database allows it, the client is stricter", "\u00a0", "blank", "ok"),
    c("no-break space between words", "Amal\u00a0Perera", "ok", "ok"),
  ],
  "birthYear": [
    {"name": "typical A/L student", "year": 2008, "now": 2026, "client": "ok", "db": "ok", "minor": True},
    {"name": "age 13 is the client minimum", "year": 2013, "now": 2026, "client": "ok", "db": "ok", "minor": True},
    {"name": "age 12 is too young for the client", "year": 2014, "now": 2026, "client": "too_young", "db": "ok", "minor": True},
    {"name": "year difference 18 is still a possible minor", "year": 2008, "now": 2026, "client": "ok", "db": "ok", "minor": True},
    {"name": "year difference 19 is not", "year": 2007, "now": 2026, "client": "ok", "db": "ok", "minor": False},
    {"name": "the boundary moves with the year", "year": 2008, "now": 2027, "client": "ok", "db": "ok", "minor": False},
    {"name": "adult", "year": 1990, "now": 2026, "client": "ok", "db": "ok", "minor": False},
    {"name": "1946 (age 80) is below the database minimum, so the client rejects it too", "year": 1946, "now": 2026, "client": "out_of_range", "db": "invalid", "minor": False},
    {"name": "age 80 is the client maximum", "year": 1960, "now": 2040, "client": "ok", "db": "ok", "minor": False},
    {"name": "age 81 is above the client maximum (the database allows it)", "year": 1959, "now": 2040, "client": "out_of_range", "db": "ok", "minor": False},
    {"name": "1950 is the database minimum", "year": 1950, "now": 2026, "client": "ok", "db": "ok", "minor": False},
    {"name": "1949 is below the database minimum", "year": 1949, "now": 2026, "client": "out_of_range", "db": "invalid", "minor": False},
    {"name": "a future birth year", "year": 2030, "now": 2026, "client": "out_of_range", "db": "ok", "minor": True},
    {"name": "2101 is above the database maximum", "year": 2101, "now": 2026, "client": "out_of_range", "db": "invalid", "minor": True},
  ],
  "email": [
    c("ordinary", "amal@example.com", "ok", normalized="amal@example.com"),
    c("surrounding spaces are trimmed", "  amal@example.com ", "ok", normalized="amal@example.com"),
    c("tabs and newlines around are trimmed", "\t amal@example.com\n", "ok", normalized="amal@example.com"),
    c("no at sign", "amal.example.com", "invalid_format"),
    c("no dot in the domain", "amal@localhost", "invalid_format"),
    c("space inside", "am al@example.com", "invalid_format"),
    c("two at signs", "a@b@example.com", "invalid_format"),
    c("empty", "", "blank"),
    c("254 characters is the maximum", "a" * 242 + "@example.com", "ok"),
    c("255 characters", "a" * 243 + "@example.com", "too_long"),
  ],
  "password": [
    {"name": "a passphrase", "in": "correct horse battery", "email": "amal@example.com", "client": "ok"},
    {"name": "exactly 10 characters", "in": "kQ7vN2xLp9", "email": "amal@example.com", "client": "ok"},
    {"name": "9 characters", "in": "kQ7vN2xLp", "email": "amal@example.com", "client": "too_short"},
    {"name": "no composition rules: all lowercase is fine", "in": "abcdefghijklmnop", "email": "amal@example.com", "client": "ok"},
    {"name": "common password", "in": "password123", "email": "amal@example.com", "client": "common_password"},
    {"name": "common password in capitals", "in": "PASSWORD123", "email": "amal@example.com", "client": "common_password"},
    {"name": "common password: digits", "in": "1234567890", "email": "amal@example.com", "client": "common_password"},
    {"name": "contains the e-mail name", "in": "amal.perera2026!", "email": "amal.perera@example.com", "client": "contains_email"},
    {"name": "short e-mail names (under 4) are not checked", "in": "amal-is-great-2026", "email": "am@example.com", "client": "ok"},
    {"name": "72 bytes is the maximum", "in": "a1" * 36, "email": "x@example.com", "client": "ok"},
    {"name": "73 bytes", "in": "a1" * 36 + "b", "email": "x@example.com", "client": "too_long"},
    {"name": "25 Sinhala letters are only 25 characters but 75 bytes", "in": "අ" * 25, "email": "x@example.com", "client": "too_long"},
    {"name": "24 Sinhala letters are 72 bytes", "in": "අ" * 24, "email": "x@example.com", "client": "ok"},
    {"name": "empty", "in": "", "email": "x@example.com", "client": "too_short"},
  ],
  "deviceName": [
    c("typical", "Redmi 9", "ok", "ok"),
    c("trimmed", "  Laptop ", "ok", "ok", normalized="Laptop"),
    c("empty", "", "blank", "invalid"),
    c("60 characters", "d" * 60, "ok", "ok"),
    c("61 characters", "d" * 61, "too_long", "invalid"),
    c("control character", "a\u0007b", "control_char", "invalid"),
  ],
  "stream": [
    c("technology", "technology", "ok", "ok"), c("other", "other", "ok", "ok"),
    c("unknown", "astrology", "unknown_value", "invalid"), c("wrong case", "Commerce", "unknown_value", "invalid"), c("empty", "", "unknown_value", "invalid"),
  ],
  "subjects": [
    {"name": "none", "in": [], "client": "ok", "db": "ok"},
    {"name": "three subjects", "in": ["ICT", "Physics", "Combined Mathematics"], "client": "ok", "db": "ok"},
    {"name": "12 subjects", "in": ["s%d" % i for i in range(12)], "client": "ok", "db": "ok"},
    {"name": "13 subjects", "in": ["s%d" % i for i in range(13)], "client": "too_many", "db": "invalid"},
    {"name": "one subject of 60 characters", "in": ["x" * 60], "client": "ok", "db": "ok"},
    {"name": "one subject of 61 characters: client stricter than db", "in": ["x" * 61], "client": "too_long", "db": "ok"},
    {"name": "12 subjects of 60 characters: joined with commas that is 731, above the database limit of 720", "in": ["y" * 60] * 12, "client": "too_long", "db": "invalid"},
    {"name": "joined length exactly 720 (eleven of 59 and one of 60, plus 11 commas)", "in": ["z" * 59] * 11 + ["z" * 60], "client": "ok", "db": "ok"},
    {"name": "joined length 721 (ten of 59 and two of 60, plus 11 commas)", "in": ["z" * 59] * 10 + ["z" * 60] * 2, "client": "too_long", "db": "invalid"},
    {"name": "blank subject", "in": ["ICT", "  "], "client": "blank", "db": "ok"},
  ],
  "avatarKey": [
    {"name": "own folder", "in": "objects/%s/%s" % (UUID_A, OBJ), "user": UUID_A, "client": "ok", "db": "ok"},
    {"name": "someone else's folder", "in": "objects/%s/%s" % (UUID_B, OBJ), "user": UUID_A, "client": "wrong_owner", "db": "invalid"},
    {"name": "wrong prefix", "in": "public/%s/%s" % (UUID_A, OBJ), "user": UUID_A, "client": "invalid_format", "db": "invalid"},
    {"name": "path traversal", "in": "objects/%s/../%s" % (UUID_A, OBJ), "user": UUID_A, "client": "invalid_format", "db": "invalid"},
    {"name": "missing file part", "in": "objects/%s" % UUID_A, "user": UUID_A, "client": "invalid_format", "db": "invalid"},
    {"name": "a trailing newline is not allowed (Python \"$\" would accept it; the database and Dart do not)", "in": "objects/%s/%s\n" % (UUID_A, OBJ), "user": UUID_A, "client": "invalid_format", "db": "invalid"},
    {"name": "uppercase hex is not allowed", "in": ("objects/%s/%s" % (UUID_A, OBJ)).upper().replace("OBJECTS", "objects"), "user": UUID_A.upper(), "client": "invalid_format", "db": "invalid"},
  ],
  "clientKey": [
    c("publishable key", "sb_publishable_abc123", "ok"),
    c("secret key", "sb_secret_abc123", "secret_key"),
    c("secret key with surrounding spaces", "  sb_secret_abc123 ", "secret_key"),
    c("legacy anon JWT", jwt("anon"), "ok"),
    c("legacy service_role JWT", jwt("service_role"), "secret_key"),
    c("a JWT with another role", jwt("authenticated"), "ok"),
    c("three dot-separated words that are not a JWT", "a.b.c", "ok"),
    c("empty", "", "blank"),
    c("only spaces", "   ", "blank"),
  ],
  "authError": [
    {"name": "wrong password", "code": "invalid_credentials", "status": 400, "network": False, "kind": "invalid_credentials"},
    {"name": "email not confirmed", "code": "email_not_confirmed", "status": 400, "network": False, "kind": "email_not_confirmed"},
    {"name": "rate limit by code", "code": "over_request_rate_limit", "status": 429, "network": False, "kind": "rate_limited"},
    {"name": "e-mail rate limit by code", "code": "over_email_send_rate_limit", "status": 429, "network": False, "kind": "rate_limited"},
    {"name": "rate limit by status only", "code": None, "status": 429, "network": False, "kind": "rate_limited"},
    {"name": "captcha failed", "code": "captcha_failed", "status": 400, "network": False, "kind": "captcha_failed"},
    {"name": "weak password", "code": "weak_password", "status": 422, "network": False, "kind": "weak_password"},
    {"name": "user already exists", "code": "user_already_exists", "status": 422, "network": False, "kind": "email_taken"},
    {"name": "email exists", "code": "email_exists", "status": 422, "network": False, "kind": "email_taken"},
    {"name": "same password", "code": "same_password", "status": 422, "network": False, "kind": "same_password"},
    {"name": "server error without a code", "code": None, "status": 503, "network": False, "kind": "server"},
    {"name": "network failure wins over everything", "code": "invalid_credentials", "status": None, "network": True, "kind": "network"},
    {"name": "unknown code", "code": "something_new", "status": 400, "network": False, "kind": "unknown"},
    {"name": "a metadata key in the mapping is never a real code", "code": "_network", "status": 400, "network": False, "kind": "unknown"},
    {"name": "nothing known at all", "code": None, "status": None, "network": False, "kind": "unknown"},
  ],
  "timeZone": [
    c("Colombo", "Asia/Colombo", "ok"), c("UTC", "UTC", "ok"), c("three parts", "America/Argentina/Buenos_Aires", "ok"),
    c("with plus sign", "Etc/GMT+5", "ok"), c("empty", "", "invalid_format"), c("space", "Asia/ Colombo", "invalid_format"), c("traversal", "../etc/passwd", "invalid_format"), c("trailing newline", "Asia/Colombo\n", "invalid_format"),
  ],
}

def main(argv):
    text = json.dumps(V, indent=1, ensure_ascii=False, sort_keys=True) + "\n"
    if "--check" in argv:
        ok = os.path.exists(OUT) and open(OUT, encoding="utf-8").read() == text
        print("OK    test vectors are up to date" if ok else "FAIL  test-vectors/validation.json is out of date: run make_vectors.py")
        return 0 if ok else 1
    open(OUT, "w", encoding="utf-8").write(text)
    print("wrote", os.path.relpath(OUT, ROOT), "-", sum(len(v) for v in V.values()), "cases")
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv))

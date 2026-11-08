#!/usr/bin/env python3
"""Python REFERENCE implementation of the client validation rules (packages/core/spec/validation.json).
It exists to prove the rules against the hand-written vectors NOW, and to be the second implementation the Dart one is compared with.
`client_*` functions model the app; `db_*` functions model the database constraints (an independent re-statement of the SQL)."""
import base64, json, os, re, unicodedata

HERE = os.path.dirname(os.path.abspath(__file__))
SPEC = json.load(open(os.path.join(HERE, "..", "spec", "validation.json"), encoding="utf-8"))
UNICODE_WHITESPACE = {0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x20, 0x85, 0xA0, 0x1680, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000} | set(range(0x2000, 0x200B))
EMAIL_RE = re.compile(SPEC["email"]["pattern"])  # used with fullmatch: Python "$" would otherwise accept a trailing newline
TZ_RE = re.compile(SPEC["timeZone"]["pattern"])
AVATAR_RE = re.compile(SPEC["avatarKeyPattern"])


def is_control(ch):
    o = ord(ch)
    return o < 0x20 or 0x7F <= o <= 0x9F


def trim_ws(s):
    """Trim the explicit Unicode White_Space set (NOT str.strip(), which also trims U+001C-U+001F; Dart trim() also trims U+FEFF)."""
    i, j = 0, len(s)
    while i < j and ord(s[i]) in UNICODE_WHITESPACE:
        i += 1
    while j > i and ord(s[j - 1]) in UNICODE_WHITESPACE:
        j -= 1
    return s[i:j]


def trim_spaces(s):
    return s.strip(" ")           # Postgres btrim(x) removes only U+0020


def _name(s, lo, hi, reject_ws_only):
    if any(is_control(c) for c in s):
        return ("control_char", s)
    t = trim_spaces(s)
    if len(t) < lo or (reject_ws_only and all(ord(c) in UNICODE_WHITESPACE for c in t)):
        return ("blank", t)
    if len(t) > hi:
        return ("too_long", t)
    return ("ok", t)


def client_display_name(s):
    d = SPEC["displayName"]
    return _name(s, d["min"], d["max"], True)


def db_display_name(s):
    d = SPEC["displayName"]
    code, t = _name(s, d["min"], d["max"], False)
    return "ok" if code == "ok" else "invalid"


def client_device_name(s):
    d = SPEC["deviceName"]
    return _name(s, d["min"], d["max"], True)


def db_device_name(s):
    d = SPEC["deviceName"]
    return "ok" if _name(s, d["min"], d["max"], False)[0] == "ok" else "invalid"


def client_birth_year(year, now):
    b = SPEC["birthYear"]
    if year > now or year < b["dbMin"] or year > b["dbMax"]:
        return "out_of_range"
    age = now - year
    if age < b["clientMinAge"]:
        return "too_young"
    if age > b["clientMaxAge"]:
        return "out_of_range"
    return "ok"


def db_birth_year(year):
    b = SPEC["birthYear"]
    return "ok" if b["dbMin"] <= year <= b["dbMax"] else "invalid"


def is_possible_minor(year, now):
    return now - year < SPEC["birthYear"]["possibleMinorIfYearDifferenceLessThan"]


def client_email(s):
    e = SPEC["email"]
    t = trim_ws(s)
    if t == "":
        return ("blank", t)
    if len(t) > e["maxLength"]:
        return ("too_long", t)
    if not EMAIL_RE.fullmatch(t):
        return ("invalid_format", t)
    return ("ok", t)


def client_password(pw, email):
    p = SPEC["password"]
    if len(pw) < p["minLength"]:
        return "too_short"
    if len(pw.encode("utf-8")) > p["maxBytes"]:
        return "too_long"
    if pw.lower() in p["blocklist"]:
        return "common_password"
    local = email.split("@")[0].lower() if "@" in email else ""
    if len(local) >= p["rejectIfContainsEmailLocalPartOfAtLeast"] and local in pw.lower():
        return "contains_email"
    return "ok"


def client_stream(s):
    return "ok" if s in SPEC["streams"] else "unknown_value"


def db_stream(s):
    return "ok" if s in SPEC["streams"] else "invalid"


def client_subjects(items):
    sj = SPEC["subjects"]
    if len(items) > sj["maxCount"]:
        return "too_many"
    for x in items:
        if trim_spaces(x) == "" or all(ord(c) in UNICODE_WHITESPACE for c in x):
            return "blank"
        if len(x) > sj["clientMaxEachLength"]:
            return "too_long"
    if len(",".join(items)) > sj["maxJoinedLength"]:
        return "too_long"
    return "ok"


def db_subjects(items):
    sj = SPEC["subjects"]
    return "ok" if len(items) <= sj["maxCount"] and len(",".join(items)) <= sj["maxJoinedLength"] else "invalid"


def client_avatar_key(key, user):
    if not AVATAR_RE.fullmatch(key):
        return "invalid_format"
    if key.split("/")[1] != user:
        return "wrong_owner"
    return "ok"


def db_avatar_key(key, user):
    return "ok" if AVATAR_RE.fullmatch(key) and key.split("/")[1] == user else "invalid"


def client_time_zone(s):
    return "ok" if TZ_RE.fullmatch(s) else "invalid_format"


def _jwt_role(token):
    """Role claim of a JWT-shaped token, or None if it does not decode as one."""
    parts = token.split(".")
    if len(parts) != 3:
        return None
    try:
        payload = parts[1] + "=" * (-len(parts[1]) % 4)
        data = json.loads(base64.urlsafe_b64decode(payload.encode("ascii")).decode("utf-8"))
        return data.get("role") if isinstance(data, dict) else None
    except Exception:
        return None


def client_key(key):
    k = trim_ws(key)
    if k == "":
        return "blank"
    c = SPEC["clientKey"]
    if any(k.startswith(p) for p in c["secretPrefixes"]):
        return "secret_key"
    if _jwt_role(k) in c["forbiddenJwtRoles"]:
        return "secret_key"
    return "ok"


def auth_error_kind(code=None, status=None, network=False):
    m = SPEC["authErrors"]
    if network:
        return m["_network"]
    if code and code in m and not code.startswith("_"):
        return m[code]
    if status == 429:
        return m["_status429"]
    if status is not None and status >= 500:
        return m["_status5xx"]
    return m["_default"]

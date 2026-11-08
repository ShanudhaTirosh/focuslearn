#!/usr/bin/env bash
# Offline tests for lib.sh helpers and the tunnel config template. No Docker or network needed.
# Run: bash infra/docker/tests/test-lib.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=../lib.sh
. "$HERE/../lib.sh"

pass=0; failn=0
t() { if "$@"; then pass=$((pass+1)); printf 'PASS  %s\n' "$DESC"; else failn=$((failn+1)); printf 'FAIL  %s\n' "$DESC"; fi; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# set_env / get_cfg
printf 'A=1\nPASS=old\n' > "$TMP/e"
set_env "$TMP/e" PASS 'p\w=d&/x$y'
DESC="set_env round-trips tricky value"; t test "$(get_cfg "$TMP/e" PASS)" = 'p\w=d&/x$y'
DESC="set_env keeps other keys"; t test "$(get_cfg "$TMP/e" A)" = 1
DESC="env file mode is 600"; t test "$(stat -c %a "$TMP/e")" = 600
DESC="version_ge accepts equal"; t version_ge 2.24.4 2.24.4
DESC="version_ge rejects older"; t bash -c '. "$0"; ! version_ge 2.24.3 2.24.4' "$HERE/../lib.sh"

# render_template
TPL="$ROOT/cloudflare/tunnel-config.template.yml"
render_template "$TPL" "$TMP/c.yml" TUNNEL_UUID=11111111-2222-3333-4444-555555555555 \
  API_HOST=eduapp-api.example.com STUDIO_HOST=eduapp-studio.example.com GATEWAY=envoy
DESC="template renders without leftover placeholders"; t bash -c '! grep -Eq "@[A-Z_]+@" "$0"' "$TMP/c.yml"
DESC="render fails when a placeholder is missing"; t bash -c '. "$0"; ! render_template "$1" "$2" TUNNEL_UUID=x 2>/dev/null' "$HERE/../lib.sh" "$TPL" "$TMP/bad.yml"
DESC="rendered config ends with a catch-all 404 rule"; t bash -c 'tail -n1 "$0" | grep -q "service: http_status:404"' "$TMP/c.yml"

# YAML validity and path allowlist, if python3 + PyYAML exist
if python3 -c 'import yaml' 2>/dev/null; then
  DESC="rendered YAML parses and has 3 ingress rules"
  t python3 - "$TMP/c.yml" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
assert len(d["ingress"]) == 3, d
assert d["ingress"][-1] == {"service": "http_status:404"}
PY
  DESC="path allowlist: allowed and denied cases (Python re, same syntax as Go RE2 here)"
  t python3 - "$TMP/c.yml" <<'PY'
import sys, re, yaml
rx = re.compile(yaml.safe_load(open(sys.argv[1]))["ingress"][0]["path"])
allow = ["/auth/v1", "/auth/v1/health", "/rest/v1/", "/rest/v1/profiles", "/realtime/v1/websocket", "/functions/v1/files-presign"]
deny  = ["/", "/project/default", "/pg/tables", "/api/platform/projects", "/storage/v1/", "/auth/v10", "/rest/v1evil", "//auth/v1/x", "/x/auth/v1/health", "/AUTH/v1/health"]
bad = [p for p in allow if not rx.search(p)] + [p for p in deny if rx.search(p)]
assert not bad, bad
PY
else
  echo "SKIP  YAML tests (PyYAML not installed)"
fi

# render_override: every combination must be strict-valid YAML (no duplicate keys) and contain exactly what was asked for
if python3 -c 'import yaml' 2>/dev/null; then
  for combo in "0 0 -" "1 0 -" "1 1 -" "1 0 2026.8.1" "1 1 2026.8.1" "0 0 2026.8.1"; do
    read -r ha cap cf <<< "$combo"; [ "$cf" = "-" ] && cf=""
    render_override envoy "$ha" "$cap" "$cf" > "$TMP/ov.yml"
    DESC="override [auth=$ha captcha=$cap tunnel=${cf:-none}] is strict-valid YAML with exactly the expected services and settings"
    t python3 "$HERE/check_override.py" "$TMP/ov.yml" "$ha" "$cap" "$cf"
  done
else
  echo "SKIP  override YAML tests (PyYAML not installed)"
fi

printf '\n%d passed, %d failed\n' "$pass" "$failn"
[ "$failn" -eq 0 ]

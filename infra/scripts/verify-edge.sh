#!/usr/bin/env bash
# Verifies the public edge: API allowlist, Studio isolation, Access gate, WebSocket upgrade, optional captcha probe.
# Usage: verify-edge.sh [--probe-captcha]
# Reads hostnames from infra/docker/.env and the publishable key from the stack .env. Prints no secrets.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../docker/lib.sh
. "$ROOT/docker/lib.sh"
OVERLAY="$ROOT/docker/.env"
STACKENV="$ROOT/docker/stack/.env"

API="$(get_cfg "$OVERLAY" API_HOST)"
STUDIO="$(get_cfg "$OVERLAY" STUDIO_HOST)"
KEY="$(get_cfg "$STACKENV" SUPABASE_PUBLISHABLE_KEY)"
[ -n "$API" ] && [ -n "$STUDIO" ] && [ -n "$KEY" ] || { echo "missing API_HOST, STUDIO_HOST or key"; exit 1; }

fail=0
ok()  { printf 'OK    %s\n' "$1"; }
bad() { printf 'FAIL  %s\n' "$1"; fail=1; }

code() { curl -s -o /dev/null -m 10 -w '%{http_code}' "$@" || echo 000; }

# 1. Allowlisted API paths work
c="$(code -H "apikey: $KEY" "https://$API/auth/v1/health")"
[ "$c" = 200 ] && ok "api /auth/v1/health 200" || bad "api /auth/v1/health returned $c"
c="$(code -H "apikey: $KEY" "https://$API/rest/v1/")"
case "$c" in 2??|401|403) ok "api /rest/v1/ reachable ($c)";; *) bad "api /rest/v1/ returned $c";; esac

# 2. Everything else on the API host must be 404 (Studio must not be reachable here)
for p in / /project/default /pg/tables /api/platform/projects /storage/v1/ /auth/v10 /rest/v1evil; do
  c="$(code "https://$API$p")"
  [ "$c" = 404 ] && ok "api $p blocked (404)" || bad "api $p returned $c (expected 404)"
done

# 3. Path tricks must not reach Studio (basic-auth header or 2xx means leak)
for p in '/auth/v1/../' '/auth/v1/%2e%2e/' '/auth/v1/..%2f' '/auth/v1/%2e%2e%2fproject/default'; do
  hdr="$(curl -s -D - -o /dev/null -m 10 --path-as-is "https://$API$p" || true)"
  first="$(printf '%s' "$hdr" | head -n1 | tr -d '\r')"
  if printf '%s' "$hdr" | grep -qi '^www-authenticate:' || printf '%s' "$first" | grep -Eq ' 2[0-9][0-9]'; then
    bad "api path trick $p may reach Studio: $first"
  else
    ok "api path trick $p not served ($first)"
  fi
done

# 4. Studio hostname must be gated by Access: no 200 without login
out="$(curl -s -o /dev/null -m 10 -w '%{http_code} %{redirect_url}' "https://$STUDIO/" || echo '000 ')"
scode="${out%% *}"; sloc="${out#* }"
if [ "$scode" = 302 ] && printf '%s' "$sloc" | grep -q 'cloudflareaccess.com'; then
  ok "studio redirects to Cloudflare Access login"
elif [ "$scode" = 403 ]; then
  ok "studio denied (403)"
else
  bad "studio unauthenticated returned '$out' (expected Access redirect or 403)"
fi

# 5. WebSocket upgrade for Realtime
hdrs="$(curl -s -D - -o /dev/null -m 6 --http1.1 \
  -H 'Connection: Upgrade' -H 'Upgrade: websocket' -H 'Sec-WebSocket-Version: 13' \
  -H "Sec-WebSocket-Key: $(openssl rand -base64 16)" \
  "https://$API/realtime/v1/websocket?apikey=$KEY&vsn=1.0.0" || true)"
if printf '%s' "$hdrs" | head -n1 | grep -q ' 101'; then ok "realtime websocket upgrade 101"; else bad "realtime websocket upgrade failed: $(printf '%s' "$hdrs" | head -n1 | tr -d '\r')"; fi

# 6. Optional: captcha must block signup without a token. Uses a non-routable address.
if [ "${1:-}" = "--probe-captcha" ]; then
  body="$(curl -s -m 10 -X POST "https://$API/auth/v1/signup" -H "apikey: $KEY" -H 'Content-Type: application/json' \
    -d "{\"email\":\"edge-probe-$(date +%s)@example.invalid\",\"password\":\"$(openssl rand -hex 12)Aa1!\"}" || true)"
  if printf '%s' "$body" | grep -qi 'captcha'; then
    ok "signup without captcha token is rejected"
  else
    bad "signup was NOT rejected for captcha. A probe user may exist: delete edge-probe-*@example.invalid in Studio"
  fi
fi

exit "$fail"

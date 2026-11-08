#!/usr/bin/env bash
# Triggers a real Auth email through the gateway so you can check the whole path (SMTP, link host and path).
# Usage: auth-email-probe.sh EMAIL [signup|recover] [BASE_URL]      (BASE_URL default http://127.0.0.1:8000)
# signup creates a user with a random throwaway password: delete that user in Studio afterwards.
# If captcha is enabled this fails with a captcha error: run it in local mode before enabling Turnstile.
# Prints only the HTTP status and a short error summary. No keys or tokens.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../docker/lib.sh
. "$ROOT/docker/lib.sh"
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 2; }
email="${1:?usage: auth-email-probe.sh EMAIL [signup|recover] [BASE_URL]}"
kind="${2:-signup}"
base="${3:-http://127.0.0.1:8000}"
key="$(get_cfg "$ROOT/docker/stack/.env" SUPABASE_PUBLISHABLE_KEY)"
[ -n "$key" ] || { echo "publishable key not found; is the stack set up?" >&2; exit 1; }

case "$kind" in
  signup)  path=/auth/v1/signup;  body="{\"email\":\"$email\",\"password\":\"$(openssl rand -hex 12)Aa1!\"}" ;;
  recover) path=/auth/v1/recover; body="{\"email\":\"$email\"}" ;;
  *) echo "kind must be signup or recover" >&2; exit 2 ;;
esac

out="$(curl -s -m 20 -w '\n%{http_code}' -X POST "$base$path" -H "apikey: $key" -H 'Content-Type: application/json' -d "$body")"
code="${out##*$'\n'}"; resp="${out%$'\n'*}"
summary="$(printf '%s' "$resp" | jq -r '[.error_code, .msg, .error_description] | map(select(. != null)) | join(" | ")' 2>/dev/null || true)"
echo "HTTP $code ${summary:+($summary)}"
case "$summary" in *aptcha*) echo "Captcha is enabled. Probe in local mode before enabling Turnstile." ;; esac
[ "$code" = 200 ]

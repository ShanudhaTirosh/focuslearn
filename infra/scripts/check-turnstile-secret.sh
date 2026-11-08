#!/usr/bin/env bash
# Preflight: asks Cloudflare whether a Turnstile secret is valid, using a dummy token.
# Reads the secret from the TURNSTILE_SECRET environment variable (keeps it out of the process list).
# Exit: 0 secret accepted, 1 secret rejected, 2 could not check.
set -uo pipefail

: "${TURNSTILE_SECRET:?set TURNSTILE_SECRET}"

resp="$(printf 'data-urlencode = "secret=%s"\ndata-urlencode = "response=focuslearn-preflight"\n' "$TURNSTILE_SECRET" \
  | curl -sS -m 10 -X POST -K - https://challenges.cloudflare.com/turnstile/v0/siteverify 2>/dev/null)" \
  || { echo "could not reach Cloudflare siteverify" >&2; exit 2; }

case "$resp" in
  *invalid-input-secret*) echo "Turnstile secret REJECTED by Cloudflare" >&2; exit 1 ;;
  *invalid-input-response*|*missing-input-response*|*timeout-or-duplicate*)
    echo "Turnstile secret accepted (the dummy token was rejected, as expected)"; exit 0 ;;
  *) echo "unexpected siteverify response; cannot confirm the secret" >&2; exit 2 ;;
esac

#!/usr/bin/env bash
# Logs the API health once per interval so you can time an outage (for example, unplugging ISP 1).
# Usage: outage-probe.sh https://eduapp-api.shanutechx.com [interval_seconds]
# Output: ISO time, HTTP code (000 = no connection). Stop with Ctrl-C. No secrets needed (unauthenticated probe).
set -uo pipefail
url="${1:?usage: outage-probe.sh BASE_URL [interval]}"
every="${2:-2}"
while true; do
  c="$(curl -s -o /dev/null -m 5 -w '%{http_code}' "$url/auth/v1/health" || echo 000)"
  printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$c"
  sleep "$every"
done

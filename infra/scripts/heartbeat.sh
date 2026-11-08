#!/usr/bin/env bash
# Dead-man's-switch heartbeat. Run every 5 minutes by a systemd timer (install-heartbeat.sh).
# Runs the local health check, then pings an external monitor (for example Healthchecks.io):
#   healthy   -> GET  <HEARTBEAT_URL>
#   unhealthy -> POST <HEARTBEAT_URL>/fail   with at most 500 bytes of the health-check output (names and percentages, no secrets)
# The monitor alerts you when pings STOP (power cut, ISP down, tunnel down, laptop off) or when a /fail arrives.
# The URL is a secret: anyone who has it can send pings. It lives only in infra/docker/.env and is never printed.
# Exit: 0 healthy and delivered, 1 unhealthy or could not deliver, 2 not configured or unsafe URL.
# Test hook: HEARTBEAT_HEALTHCHECK=<script> replaces the health check.
set -uo pipefail

INFRA="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../docker/lib.sh
. "$INFRA/docker/lib.sh"
log() { printf '[heartbeat] %s\n' "$*"; }

URL="$(get_cfg "$INFRA/docker/.env" HEARTBEAT_URL)"
[ -n "$URL" ] || { log "HEARTBEAT_URL is empty in infra/docker/.env" >&2; exit 2; }
case "$URL" in
  https://*|http://127.0.0.1:*|http://localhost:*) ;;
  *) log "HEARTBEAT_URL must start with https:// (plain http is allowed only for localhost tests)" >&2; exit 2 ;;
esac

out="$(bash "${HEARTBEAT_HEALTHCHECK:-$INFRA/scripts/healthcheck.sh}" 2>&1)"
rc=$?

if [ "$rc" -eq 0 ]; then
  if curl -fsS -m 10 --retry 3 --retry-delay 2 -o /dev/null "$URL" >/dev/null 2>&1; then log "healthy, ping delivered"; exit 0; fi
  log "healthy, but the monitor could not be reached (the monitor will alert if this continues)" >&2; exit 1
fi

body="$(printf '%s' "$out" | head -c 500)"
if curl -fsS -m 10 --retry 3 --retry-delay 2 --data-raw "$body" -o /dev/null "${URL%/}/fail" >/dev/null 2>&1; then
  log "UNHEALTHY, failure signal delivered" >&2
else
  log "UNHEALTHY and the monitor could not be reached" >&2
fi
exit 1

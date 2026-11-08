#!/usr/bin/env bash
# Local health check for the FocusLearn Supabase stack. Exit code 0 = healthy. Prints no secrets.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STACK="$ROOT/docker/stack"
BASE="${BASE_URL:-http://127.0.0.1:8000}"
MAX_DISK_PCT="${MAX_DISK_PCT:-85}"
fail=0

ok()  { printf 'OK    %s\n' "$1"; }
bad() { printf 'FAIL  %s\n' "$1"; fail=1; }

printf 'FocusLearn health %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

[ -d "$STACK" ] || { bad "stack not set up (run: bash infra/scripts/stack.sh setup)"; exit 1; }

# 1. Containers: all running, and healthy where a healthcheck exists
ps_out="$(cd "$STACK" && docker compose ps --format '{{.Name}}|{{.State}}|{{.Health}}' 2>/dev/null)"
if [ -z "$ps_out" ]; then
  bad "no containers running"
else
  bad_ct="$(printf '%s\n' "$ps_out" | awk -F'|' '$2!="running" || ($3!="" && $3!="healthy"){print "  " $1 " (" $2 "/" $3 ")"}')"
  if [ -n "$bad_ct" ]; then bad "containers not healthy:"; printf '%s\n' "$bad_ct"; else ok "all containers running and healthy"; fi
fi

# 2. API through the gateway (publishable key is safe for this check)
KEY="$(grep -E '^SUPABASE_PUBLISHABLE_KEY=' "$STACK/.env" | tail -n1 | cut -d= -f2-)"
if [ -z "$KEY" ]; then
  bad "SUPABASE_PUBLISHABLE_KEY missing in stack .env"
else
  code="$(curl -s -o /dev/null -m 5 -w '%{http_code}' -H "apikey: $KEY" "$BASE/auth/v1/health" || true)"
  if [ "$code" = "200" ]; then ok "auth health 200"; else bad "auth health returned '$code'"; fi
  code="$(curl -s -o /dev/null -m 5 -w '%{http_code}' -H "apikey: $KEY" "$BASE/rest/v1/" || true)"
  case "$code" in 2??|401|403) ok "rest reachable ($code)";; *) bad "rest returned '$code'";; esac
fi

# 3. Disk
pct="$(df -P "$STACK" | awk 'NR==2{gsub("%","",$5); print $5}')"
if [ -n "$pct" ] && [ "$pct" -lt "$MAX_DISK_PCT" ]; then ok "disk ${pct}% used"; else bad "disk ${pct:-?}% used (limit ${MAX_DISK_PCT}%)"; fi

# 4. Backup freshness. Before the first backup this only warns; afterwards a stale backup fails the check.
LS="$ROOT/backup/out/last-success"
if [ -f "$LS" ] && grep -Eq '^[0-9]{10}$' "$LS"; then
  bage=$(( $(date +%s) - $(cat "$LS") ))
  if [ "$bage" -lt "${MAX_BACKUP_AGE_S:-93600}" ]; then ok "last backup $((bage / 3600)) h ago"; else bad "last backup $((bage / 3600)) h ago (limit $(( ${MAX_BACKUP_AGE_S:-93600} / 3600 )) h)"; fi
else
  printf 'WARN  no successful backup recorded yet (see docs/RUNBOOK.md)\n'
fi

exit "$fail"

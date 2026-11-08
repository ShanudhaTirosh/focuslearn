#!/usr/bin/env bash
# One command, one report: runs every Phase 0 check in order and prints a compact report you can paste back.
# It changes nothing (health checks, dry runs and read-only audits; pgTAP runs inside a rolled-back transaction).
# Output is passed through a redactor (long tokens and e-mail addresses), but still glance at it before sharing.
#
# Usage: bash infra/scripts/phase0-verify.sh [--only id,id] [--list]
# Optional inputs (environment variables):
#   P0_EMAIL_DOMAIN=eduapp.shanutechx.com  P0_DKIM_SELECTORS="sel1 sel2"   -> email DNS check
#   P0_TEST_EMAIL=you@example.com                                          -> sends one real test e-mail
#   P0_AGE_IDENTITY=/path/to/identity.txt                                  -> runs the restore drill (starts an isolated db container)
set -uo pipefail

INFRA="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$(cd "$INFRA/.." && pwd)"
STACK="$INFRA/docker/stack"
# shellcheck source=../docker/lib.sh
. "$INFRA/docker/lib.sh"

IDS="tests lint audit health exposure migrations pgtap edge emaildns backup r2 heartbeat smtp drill"
ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --only) ONLY="${2:?--only needs ids}"; shift ;;
    --list) echo "$IDS" | tr ' ' '\n'; exit 0 ;;
    -h|--help) sed -n '2,13p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done
want() { [ -z "$ONLY" ] || case ",$ONLY," in *",$1,"*) return 0 ;; *) return 1 ;; esac; }

redact() { sed -E 's/[A-Za-z0-9_-]{32,}/[redacted]/g; s/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/[email]/g'; }

pass=0; failn=0; skipn=0; warnn=0
LINES=()
add() { LINES+=("$1"); }

run_step() {  # id title command...
  local id="$1" title="$2"; shift 2
  want "$id" || return 0
  local t0 out rc w last wt dt l
  t0="$(date +%s)"
  out="$("$@" 2>&1)"; rc=$?
  dt=$(( $(date +%s) - t0 ))
  w="$(printf '%s\n' "$out" | grep -c '^WARN' || true)"
  last="$(printf '%s\n' "$out" | grep -v '^[[:space:]]*$' | tail -n1 | redact | cut -c1-110)"
  if [ "$rc" -eq 0 ]; then
    pass=$((pass+1)); wt=""
    if [ "${w:-0}" -gt 0 ]; then warnn=$((warnn+1)); wt=" [$w warning(s)]"; fi
    add "PASS  $title (${dt}s)$wt - $last"
  else
    failn=$((failn+1))
    add "FAIL  $title (${dt}s, exit $rc)"
    if printf '%s\n' "$out" | grep -q '^FAIL'; then
      while IFS= read -r l; do add "        | $l"; done < <(printf '%s\n' "$out" | grep -E '^(FAIL|  )' | head -n 15 | redact | cut -c1-160)
    else
      while IFS= read -r l; do add "        | $l"; done < <(printf '%s\n' "$out" | grep -v '^[[:space:]]*$' | tail -n 8 | redact | cut -c1-160)
    fi
  fi
}
skip() { want "$1" || return 0; skipn=$((skipn+1)); add "SKIP  $2 - $3"; }

env_info() {
  local os mem cpu disk dk dc crypt bat ntp
  os="$( . /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-unknown}" || echo unknown)"
  mem="$(awk '/^MemTotal:/{printf "%d MB", $2/1024}' /proc/meminfo 2>/dev/null || echo unknown)"
  swap="$(awk '/^SwapTotal:/{printf "%d MB", $2/1024}' /proc/meminfo 2>/dev/null || echo unknown)"
  cpu="$(awk -F: '/model name/{gsub(/^ +/,"",$2); print $2; exit}' /proc/cpuinfo 2>/dev/null || true)"; cpu="${cpu:-unknown} ($(nproc 2>/dev/null || echo '?') threads)"
  disk="$(df -h --output=avail "$REPO" 2>/dev/null | tail -n1 | tr -d ' ' || echo unknown)"
  dk="$(docker --version 2>/dev/null | sed 's/,.*//' || true)"; dk="${dk:-not installed}"
  dc="$(docker compose version --short 2>/dev/null || true)"; dc="${dc:-not installed}"
  if command -v lsblk >/dev/null 2>&1 && lsblk -rno TYPE 2>/dev/null | grep -q '^crypt$'; then crypt=yes; else crypt=no; fi
  if ls -d /sys/class/power_supply/BAT* >/dev/null 2>&1; then bat="yes ($(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo '?'))"; else bat=no; fi
  if command -v timedatectl >/dev/null 2>&1; then ntp="$(timedatectl show -p NTPSynchronized --value 2>/dev/null || echo '?')"; else ntp='?'; fi
  printf 'OS: %s\nRAM: %s, swap: %s\nCPU: %s\nDisk free (repo volume): %s\nDocker: %s, Compose: %s\nDisk encryption in use: %s\nBattery present: %s\nClock synchronised: %s\nUpstream pin: %s\nMode: %s\n' \
    "$os" "$mem" "$swap" "$cpu" "$disk" "$dk" "$dc" "$crypt" "$bat" "$ntp" \
    "$(tr -d '[:space:]' < "$INFRA/docker/UPSTREAM_VERSION" 2>/dev/null || echo '?')" "$(get_cfg "$INFRA/docker/.env" FOCUSLEARN_MODE | grep . || echo 'no overlay .env')"
}

MODE="$(get_cfg "$INFRA/docker/.env" FOCUSLEARN_MODE)"
HAVE_STACK=0; [ -d "$STACK" ] && HAVE_STACK=1
NOSTACK="stack not set up (bash infra/scripts/stack.sh up)"

run_step tests "offline test suites" bash "$INFRA/scripts/tests/run-all.sh"
run_step lint  "migration lint" python3 "$INFRA/scripts/lint-migrations.py"
if [ "$(uname -s)" = Linux ]; then run_step audit "host audit" bash "$INFRA/scripts/audit-host.sh"; else skip audit "host audit" "not Linux"; fi

if [ "$HAVE_STACK" = 1 ]; then
  run_step health     "stack health" bash "$INFRA/scripts/healthcheck.sh"
  run_step exposure   "port exposure" bash "$INFRA/scripts/check-exposure.sh"
  run_step migrations "migrations (dry run)" bash "$INFRA/scripts/migrate.sh" --dry-run
  run_step pgtap      "pgTAP security tests" bash "$INFRA/scripts/run-pgtap.sh"
else
  for i in health exposure migrations pgtap; do skip "$i" "$i" "$NOSTACK"; done
fi

if [ "$MODE" = public ] && [ "$HAVE_STACK" = 1 ]; then run_step edge "public edge" bash "$INFRA/scripts/verify-edge.sh"; else skip edge "public edge" "FOCUSLEARN_MODE is not 'public'"; fi

if [ -n "${P0_EMAIL_DOMAIN:-}" ]; then
  sel=(); for s in ${P0_DKIM_SELECTORS:-}; do sel+=(--dkim "$s"); done
  run_step emaildns "email DNS" bash "$INFRA/scripts/check-email-dns.sh" "$P0_EMAIL_DOMAIN" "${sel[@]}"
else skip emaildns "email DNS" "set P0_EMAIL_DOMAIN (and P0_DKIM_SELECTORS)"; fi

if [ -f "$INFRA/backup/.env" ]; then
  run_step backup "backup in R2 (complete set present)" bash -c 'n=$(python3 "$1" list daily/ | grep -c "/manifest.json"); echo "$n complete daily set(s)"; [ "$n" -ge 1 ]' _ "$INFRA/backup/r2_cli.py"
else skip backup "backup in R2" "infra/backup/.env missing (no backup configured yet)"; fi

if [ -f "$INFRA/cloudflare/.env" ]; then run_step r2 "R2 spike (uses about 25 operations)" python3 "$INFRA/cloudflare/r2-spike/r2_spike.py"; else skip r2 "R2 spike" "infra/cloudflare/.env missing"; fi

if [ -n "$(get_cfg "$INFRA/docker/.env" HEARTBEAT_URL)" ]; then run_step heartbeat "heartbeat ping" bash "$INFRA/scripts/heartbeat.sh"; else skip heartbeat "heartbeat ping" "HEARTBEAT_URL empty"; fi

if [ -n "${P0_TEST_EMAIL:-}" ]; then run_step smtp "test e-mail" python3 "$INFRA/scripts/send-test-email.py" --to "$P0_TEST_EMAIL"; else skip smtp "test e-mail" "set P0_TEST_EMAIL"; fi

if [ -n "${P0_AGE_IDENTITY:-}" ] && [ "$HAVE_STACK" = 1 ]; then run_step drill "restore drill" bash "$INFRA/backup/verify-restore.sh" --identity "$P0_AGE_IDENTITY"; else skip drill "restore drill" "set P0_AGE_IDENTITY=<age identity file> (needs a stack and a backup)"; fi

echo "===== FOCUSLEARN PHASE 0 REPORT (paste everything between the markers) ====="
date -u +"Date: %Y-%m-%dT%H:%M:%SZ"
env_info
echo "-- results --"
printf '%s\n' "${LINES[@]}"
echo "-- summary --"
echo "$pass passed ($warnn with warnings), $failn failed, $skipn skipped"
echo "===== END ====="
[ "$failn" -eq 0 ]

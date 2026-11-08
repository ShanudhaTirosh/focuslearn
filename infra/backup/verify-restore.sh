#!/usr/bin/env bash
# Restore drill: proves a backup can be fetched, decrypted and restored, WITHOUT touching production.
# It starts an isolated copy of the `db` service (own container, own empty volume, no ports, throwaway passwords),
# restores the dump into it, then compares row counts and RLS flags with the manifest.
#
# Usage: verify-restore.sh --identity FILE [--set daily|weekly] [--ts TIMESTAMP] [--keep]
#   --identity   the age IDENTITY (secret) file. Bring it from offline storage for the drill, delete the copy afterwards.
# Exit 0 = PASS. Prints the elapsed time: that is your measured recovery time for the database.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA="$(cd "$HERE/.." && pwd)"
STACK="$INFRA/docker/stack"
OUT="$HERE/out"
CFG="$HERE/.env"
DRILL_PW="drill-only-not-a-secret"

log() { printf '[drill] %s\n' "$*"; }
die() { printf '[drill] ERROR: %s\n' "$*" >&2; exit 1; }

identity=""; kind=daily; ts=""; keep=0
while [ $# -gt 0 ]; do
  case "$1" in
    --identity) identity="${2:?}"; shift 2 ;;
    --set) kind="${2:?}"; shift 2 ;;
    --ts) ts="${2:?}"; shift 2 ;;
    --keep) keep=1; shift ;;
    *) die "unknown argument: $1" ;;
  esac
done
[ -f "$identity" ] || die "--identity FILE is required (the age secret identity, from offline storage)"
case "$kind" in daily|weekly) ;; *) die "--set must be daily or weekly" ;; esac
for c in age docker python3 tar; do command -v "$c" >/dev/null 2>&1 || die "missing dependency: $c"; done
[ -f "$CFG" ] || die "missing $CFG"

umask 077
mkdir -p "$OUT"; chmod 700 "$OUT"
work="$OUT/drill-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$work"
dc() { docker compose -p focuslearn-restore -f "$work/restore-compose.json" "$@"; }
cleanup() {
  if [ "$keep" = 1 ]; then log "kept $work and the drill container for inspection (remove with: docker compose -p focuslearn-restore -f $work/restore-compose.json down -v)"; return; fi
  [ -f "$work/restore-compose.json" ] && dc down -v >/dev/null 2>&1
  rm -rf "$work"
}
trap cleanup EXIT

r2() { python3 "$HERE/r2_cli.py" --config "$CFG" "$@"; }
start="$(date +%s)"

if [ -z "$ts" ]; then
  ts="$(r2 list "$kind/" | awk -F'\t' '{print $1}' | sed -n -E "s#^$kind/([0-9]{8}T[0-9]{6}Z)/manifest.json\$#\1#p" | sort | tail -n1)"
fi
[ -n "$ts" ] || die "no complete backup set (one with a manifest) found under $kind/"
log "using $kind set $ts"

for f in manifest.json db.dump.age secrets.tar.age; do r2 get "$kind/$ts/$f" "$work/$f" || die "download failed: $f"; done
python3 "$HERE/bk_tools.py" check-files --manifest "$work/manifest.json" --dir "$work" || die "downloaded files do not match the manifest"

log "checking that the secrets bundle decrypts (file names only)"
names="$(age -d -i "$identity" "$work/secrets.tar.age" | tar -tf - 2>/dev/null)" || die "cannot decrypt the secrets bundle with this identity"
printf '%s\n' "$names" | grep -q '\.env$' || die "secrets bundle has no .env file"
log "secrets bundle OK ($(printf '%s\n' "$names" | wc -l | tr -d ' ') files)"

log "building an isolated db service from the running stack definition"
(cd "$STACK" && docker compose config --format json) > "$work/stack-config.json" || die "cannot read the stack definition"
python3 "$HERE/bk_tools.py" isolate --in "$work/stack-config.json" --out "$work/restore-compose.json" || die "isolate failed"
rm -f "$work/stack-config.json"   # contains production secrets; the isolated file does not
dc up -d || die "cannot start the isolated database"

ready=0
for _ in $(seq 1 90); do
  if docker exec focuslearn-restore-db pg_isready -h localhost -U supabase_admin >/dev/null 2>&1; then ready=1; break; fi
  sleep 2
done
[ "$ready" = 1 ] || die "isolated database did not become ready in 180 seconds"

log "restoring (decrypt and pipe into pg_restore)"
# No errexit in this script: every step has an explicit check, and the final exit code is the comparison result.
age -d -i "$identity" "$work/db.dump.age" | docker exec -i -e PGPASSWORD="$DRILL_PW" focuslearn-restore-db \
  pg_restore -h localhost -U supabase_admin -d postgres --clean --if-exists 2> "$work/pg_restore.err"
rcs=("${PIPESTATUS[@]}")
[ "${rcs[0]}" = 0 ] || die "decryption failed (wrong identity, or the file is corrupt)"
nerr="$(grep -c 'error' "$work/pg_restore.err" || true)"
log "pg_restore exit code ${rcs[1]}, $nerr error line(s) (some are normal when restoring over a freshly initialised Supabase database)"
[ "${nerr:-0}" -gt 0 ] && { echo "--- first error lines ---"; grep 'error' "$work/pg_restore.err" | head -n 15; echo "-------------------------"; }

docker exec -i -e PGPASSWORD="$DRILL_PW" focuslearn-restore-db psql -h localhost -U supabase_admin -d postgres -At -f - \
  < "$HERE/stats.sql" > "$work/restored-stats.json" || die "cannot read statistics from the restored database"

python3 "$HERE/bk_tools.py" compare --manifest "$work/manifest.json" --restored "$work/restored-stats.json"
rc=$?
log "elapsed: $(( $(date +%s) - start )) seconds (record this in docs/setup/measurements.md)"
exit "$rc"

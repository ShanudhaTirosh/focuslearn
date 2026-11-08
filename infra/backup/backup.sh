#!/usr/bin/env bash
# Encrypted backup of the database and the server secrets to R2. Run daily by a systemd timer (install-timer.sh).
#  - pg_dump is piped straight into `age`: no plaintext dump ever touches the disk.
#  - Only the age PUBLIC key is on this machine, so a stolen server cannot decrypt old backups.
#  - A set is db.dump.age + secrets.tar.age + manifest.json. The manifest is uploaded LAST: a set without one is incomplete.
# Test hooks (not for production): BACKUP_TS_OVERRIDE, BACKUP_FORCE_WEEKLY=1, BACKUP_DOW_OVERRIDE=<1-7, ISO weekday>.
set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA="$(cd "$HERE/.." && pwd)"
STACK="$INFRA/docker/stack"
OUT="$HERE/out"
# shellcheck source=../docker/lib.sh
. "$INFRA/docker/lib.sh"

log() { printf '[backup] %s\n' "$*"; }
die() { printf '[backup] ERROR: %s\n' "$*" >&2; exit 1; }

CFG="$HERE/.env"
[ -f "$CFG" ] || die "missing $CFG (copy infra/backup/.env.example and fill it)"
REC="$(get_cfg "$CFG" BACKUP_AGE_RECIPIENT)"
case "$REC" in age1*) ;; *) die "BACKUP_AGE_RECIPIENT must be an age public key starting with age1" ;; esac
DBUSER="$(get_cfg "$CFG" PG_DUMP_USER)"; DBUSER="${DBUSER:-postgres}"
MIN_BYTES="$(get_cfg "$CFG" MIN_DUMP_BYTES)"; MIN_BYTES="${MIN_BYTES:-10240}"
for c in age docker python3 tar curl; do command -v "$c" >/dev/null 2>&1 || die "missing dependency: $c"; done
PGPW="$(get_cfg "$STACK/.env" POSTGRES_PASSWORD)"
[ -n "$PGPW" ] || die "POSTGRES_PASSWORD not found in $STACK/.env (is the stack set up?)"

PING="$(get_cfg "$CFG" BACKUP_PING_URL)"
case "$PING" in ""|https://*|http://127.0.0.1:*|http://localhost:*) ;; *) die "BACKUP_PING_URL must start with https:// (or be empty)" ;; esac
ping_ok()   { [ -z "$PING" ] || curl -fsS -m 10 --retry 2 -o /dev/null "$PING" >/dev/null 2>&1 || log "WARN: could not reach the backup monitor"; }
ping_fail() { [ -z "$PING" ] || curl -fsS -m 10 --retry 2 -o /dev/null "${PING%/}/fail" >/dev/null 2>&1 || true; }

ts="${BACKUP_TS_OVERRIDE:-$(date -u +%Y%m%dT%H%M%SZ)}"
umask 077
mkdir -p "$OUT"; chmod 700 "$OUT"
set_dir="$OUT/$ts"
ok=0
trap 'if [ "$ok" != 1 ]; then rm -rf "$set_dir"; ping_fail; fi' EXIT
mkdir -p "$set_dir"

dbexec() { (cd "$STACK" && PGPASSWORD="$PGPW" docker compose exec -T -e PGPASSWORD db "$@"); }
stats() { dbexec psql -h localhost -U "$DBUSER" -d postgres -At -f - < "$HERE/stats.sql"; }

log "collecting statistics (before)"
stats > "$set_dir/stats_before.json"

log "dumping and encrypting the database"
dbexec pg_dump -h localhost -U "$DBUSER" -d postgres -Fc < /dev/null | age -r "$REC" -o "$set_dir/db.dump.age"
size="$(stat -c %s "$set_dir/db.dump.age")"
[ "$size" -ge "$MIN_BYTES" ] || die "encrypted dump is only $size bytes (minimum $MIN_BYTES): refusing to upload"

log "collecting statistics (after)"
stats > "$set_dir/stats_after.json"

log "encrypting server secrets (stack env, overlay env, tunnel credentials, key files)"
files=()
while IFS= read -r -d '' f; do files+=("${f#"$INFRA"/}"); done < <(
  find "$STACK" -maxdepth 3 \( -name '.env' -o -name '*.pem' \) -not -path '*/volumes/db/data/*' -print0
  find "$STACK/cloudflared" -maxdepth 1 -name '*.json' -print0 2>/dev/null || true
)
[ -f "$INFRA/docker/.env" ] && files+=("docker/.env")
[ "${#files[@]}" -gt 0 ] || die "no secret files found to back up"
printf '%s\0' "${files[@]}" | tar -C "$INFRA" --null -T - -cf - | age -r "$REC" -o "$set_dir/secrets.tar.age"

python3 "$HERE/bk_tools.py" manifest --ts "$ts" --db "$set_dir/db.dump.age" --secrets "$set_dir/secrets.tar.age" \
  --before "$set_dir/stats_before.json" --after "$set_dir/stats_after.json" \
  --upstream "$(tr -d '[:space:]' < "$INFRA/docker/UPSTREAM_VERSION")" > "$set_dir/manifest.json"
rm -f "$set_dir/stats_before.json" "$set_dir/stats_after.json"

r2() { python3 "$HERE/r2_cli.py" --config "$CFG" "$@"; }
for f in db.dump.age secrets.tar.age manifest.json; do r2 put "$set_dir/$f" "daily/$ts/$f"; done
if [ "${BACKUP_FORCE_WEEKLY:-0}" = 1 ] || [ "${BACKUP_DOW_OVERRIDE:-$(date -u +%u)}" = 7 ]; then
  log "Sunday: also writing the weekly copy"
  for f in db.dump.age secrets.tar.age manifest.json; do r2 put "$set_dir/$f" "weekly/$ts/$f"; done
fi

# Keep the newest 3 sets locally for fast restores
find "$OUT" -mindepth 1 -maxdepth 1 -type d -regextype posix-extended -regex '.*/[0-9]{8}T[0-9]{6}Z' | sort -r | tail -n +4 | while IFS= read -r d; do rm -rf "$d"; done

date -u +%s > "$OUT/last-success"
ok=1
ping_ok
log "done: set $ts uploaded (database $size bytes encrypted)"

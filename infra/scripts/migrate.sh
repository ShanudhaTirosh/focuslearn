#!/usr/bin/env bash
# Applies pending SQL migrations from backend/supabase/migrations inside the db container, as the postgres role.
# Why not the Supabase CLI: the database port is deliberately not exposed, and this needs no extra tooling.
# Bookkeeping uses the CLI's own table (supabase_migrations.schema_migrations) so the CLI can adopt the history later,
# plus focuslearn_checksums, which detects edits to migrations that were already applied.
#
# Usage: bash infra/scripts/migrate.sh [--dry-run] [--allow-out-of-order]
# Safety: lint first (refuses on any problem); each file runs in ONE transaction; stops at the first failure.
set -uo pipefail

INFRA="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$(cd "$INFRA/.." && pwd)"
STACK="$INFRA/docker/stack"
MIGDIR="${MIGRATIONS_DIR:-$REPO/backend/supabase/migrations}"
# shellcheck source=../docker/lib.sh
. "$INFRA/docker/lib.sh"

log() { printf '[migrate] %s\n' "$*"; }
die() { printf '[migrate] ERROR: %s\n' "$*" >&2; exit 1; }

dry=0; ooo=0
for a in "$@"; do
  case "$a" in
    --dry-run) dry=1 ;;
    --allow-out-of-order) ooo=1 ;;
    *) die "unknown argument: $a" ;;
  esac
done

PGPW="$(get_cfg "$STACK/.env" POSTGRES_PASSWORD)"
[ -n "$PGPW" ] || die "POSTGRES_PASSWORD not found in $STACK/.env (is the stack set up?)"
DBUSER="${MIGRATE_DB_USER:-postgres}"
command -v sha256sum >/dev/null 2>&1 || die "sha256sum is required"

python3 "$INFRA/scripts/lint-migrations.py" "$MIGDIR" || die "lint failed: nothing was applied. Fix the migrations first."

psql_q() { (cd "$STACK" && PGPASSWORD="$PGPW" docker compose exec -T -e PGPASSWORD db psql -h localhost -U "$DBUSER" -d postgres -X -q -At -v ON_ERROR_STOP=1 "$@"); }

psql_q -c "create schema if not exists supabase_migrations; create table if not exists supabase_migrations.schema_migrations (version text not null primary key, statements text[], name text); create table if not exists supabase_migrations.focuslearn_checksums (version text primary key, sha256 text not null);" \
  || die "cannot prepare the bookkeeping tables"

applied="$(psql_q -c "select version from supabase_migrations.schema_migrations order by version")" || die "cannot read applied migrations"
sums="$(psql_q -c "select version || ' ' || sha256 from supabase_migrations.focuslearn_checksums")" || die "cannot read checksums"

declare -a pending_files=() pending_versions=()
mismatch=0
latest_applied="$(printf '%s\n' "$applied" | sort | tail -n1)"
shopt -s nullglob
for f in "$MIGDIR"/*.sql; do
  base="$(basename "$f" .sql)"; v="${base%%_*}"
  sha="$(sha256sum "$f" | cut -d' ' -f1)"
  if printf '%s\n' "$applied" | grep -qx "$v"; then
    recorded="$(printf '%s\n' "$sums" | awk -v v="$v" '$1==v{print $2}')"
    if [ -n "$recorded" ] && [ "$recorded" != "$sha" ]; then
      printf '[migrate] ERROR: %s was changed after it was applied (checksum differs). Never edit an applied migration: add a new one.\n' "$(basename "$f")" >&2
      mismatch=1
    elif [ -z "$recorded" ]; then
      log "WARN: $(basename "$f") was applied without a recorded checksum (applied by another tool?)"
    fi
  else
    if [ -n "$latest_applied" ] && [[ "$v" < "$latest_applied" ]] && [ "$ooo" != 1 ]; then
      die "$(basename "$f") is older than the newest applied migration ($latest_applied). Rename it with a newer timestamp, or pass --allow-out-of-order if you are sure."
    fi
    pending_files+=("$f"); pending_versions+=("$v")
  fi
done
[ "$mismatch" = 0 ] || die "refusing to continue: nothing was applied"

# Applied versions with no local file: warn only
while IFS= read -r v; do
  [ -z "$v" ] && continue
  compgen -G "$MIGDIR/${v}_*.sql" >/dev/null || log "WARN: version $v is applied in the database but has no file here"
done <<< "$applied"

if [ "${#pending_files[@]}" -eq 0 ]; then log "database is up to date"; exit 0; fi
log "${#pending_files[@]} pending migration(s):"
for f in "${pending_files[@]}"; do log "  $(basename "$f")"; done
[ "$dry" = 1 ] && { log "dry run: nothing applied"; exit 0; }

for f in "${pending_files[@]}"; do
  base="$(basename "$f" .sql)"; v="${base%%_*}"; name="${base#*_}"
  sha="$(sha256sum "$f" | cut -d' ' -f1)"
  log "applying $base"
  {
    echo "begin;"
    cat "$f"
    echo
    printf "insert into supabase_migrations.schema_migrations (version, name) values ('%s', '%s');\n" "$v" "$name"
    printf "insert into supabase_migrations.focuslearn_checksums (version, sha256) values ('%s', '%s');\n" "$v" "$sha"
    echo "commit;"
  } | psql_q -f - || die "migration $base FAILED and was rolled back. Later migrations were not attempted."
done
log "done. Next: bash infra/scripts/run-pgtap.sh"

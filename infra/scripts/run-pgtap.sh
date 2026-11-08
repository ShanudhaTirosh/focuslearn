#!/usr/bin/env bash
# Runs every backend/supabase/tests/*.test.sql inside the db container as supabase_admin (superuser) and judges the TAP output.
# Exit 0 only if every file ran without a psql error, has no "not ok", and passed its whole plan.
# Usage: bash infra/scripts/run-pgtap.sh [file.test.sql ...]
set -uo pipefail

INFRA="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$(cd "$INFRA/.." && pwd)"
STACK="$INFRA/docker/stack"
# shellcheck source=../docker/lib.sh
. "$INFRA/docker/lib.sh"

TESTDIR="${PGTAP_DIR:-$REPO/backend/supabase/tests}"
PGPW="$(get_cfg "$STACK/.env" POSTGRES_PASSWORD)"
[ -n "$PGPW" ] || { echo "POSTGRES_PASSWORD not found in $STACK/.env" >&2; exit 2; }

files=("$@")
[ "${#files[@]}" -gt 0 ] || while IFS= read -r f; do files+=("$f"); done < <(find "$TESTDIR" -maxdepth 1 -name '*.test.sql' | sort)
[ "${#files[@]}" -gt 0 ] || { echo "no *.test.sql files in $TESTDIR" >&2; exit 2; }

rc=0
for f in "${files[@]}"; do
  printf '=== %s\n' "$(basename "$f")"
  out="$(cd "$STACK" && PGPASSWORD="$PGPW" docker compose exec -T -e PGPASSWORD db \
        psql -h localhost -U supabase_admin -d postgres -X -q -At -v ON_ERROR_STOP=1 -f - < "$f" 2>&1)"
  prc=$?
  printf '%s\n' "$out" | grep -E '^(ok|not ok|#|1\.\.|psql:|ERROR)' || true
  plan="$(printf '%s\n' "$out" | sed -n -E 's/^1\.\.([0-9]+)$/\1/p' | head -n1)"
  oks="$(printf '%s\n' "$out" | grep -c -E '^ok ' || true)"
  nots="$(printf '%s\n' "$out" | grep -c -E '^not ok ' || true)"
  if [ "$prc" != 0 ]; then echo "FAIL  psql exited with $prc"; rc=1
  elif [ -z "$plan" ]; then echo "FAIL  no TAP plan in the output"; rc=1
  elif [ "$nots" != 0 ]; then echo "FAIL  $nots failing assertion(s)"; rc=1
  elif [ "$oks" != "$plan" ]; then echo "FAIL  plan says $plan assertions, $oks passed"; rc=1
  else echo "PASS  $oks assertion(s)"; fi
done
exit "$rc"

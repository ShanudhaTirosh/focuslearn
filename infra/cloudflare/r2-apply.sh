#!/usr/bin/env bash
# Creates the three R2 buckets and applies lifecycle rules with wrangler. Dry run by default.
#   bash infra/cloudflare/r2-apply.sh            # print the commands only
#   WRANGLER_VERSION=<x.y.z> bash infra/cloudflare/r2-apply.sh --apply
# You must pick the wrangler version yourself (pin it; prefer a release at least two weeks old) and be logged in
# (`npx wrangler@<version> login`). Command syntax comes from third-party docs: VERIFY with `wrangler r2 bucket --help`.
# CORS is applied in the dashboard from r2-cors.json / r2-cors-public.json (format differs between tools).
set -euo pipefail

APPLY=0
[ "${1:-}" = "--apply" ] && APPLY=1
if [ "$APPLY" = 1 ] && [ -z "${WRANGLER_VERSION:-}" ]; then
  echo "Set WRANGLER_VERSION to an explicit, reviewed version before --apply." >&2
  exit 1
fi

run() {
  if [ "$APPLY" = 1 ]; then
    npx --yes "wrangler@${WRANGLER_VERSION}" "$@"
  else
    printf 'DRY: npx wrangler@<version> %s\n' "$*"
  fi
}

PUB=focuslearn-public; PRIV=focuslearn-private; BAK=focuslearn-backups

for b in "$PUB" "$PRIV" "$BAK"; do
  run r2 bucket create "$b" || echo "(bucket $b may already exist, continuing)"
done

# Private: unconfirmed uploads vanish after 1 day; abandoned multipart uploads are aborted after 1 day.
run r2 bucket lifecycle add "$PRIV" --id pending-expire --prefix pending/ --expire-days 1
run r2 bucket lifecycle add "$PRIV" --id abort-mpu --abort-incomplete-days 1

# Backups: retention enforced server-side so a compromised laptop cannot keep dumps forever or silently skip pruning.
run r2 bucket lifecycle add "$BAK" --id daily-expire --prefix daily/ --expire-days 14
run r2 bucket lifecycle add "$BAK" --id weekly-expire --prefix weekly/ --expire-days 56
run r2 bucket lifecycle add "$BAK" --id abort-mpu --abort-incomplete-days 1

echo "Done. Next: dashboard CORS (see infra/cloudflare/r2-setup.md), then run the spike."

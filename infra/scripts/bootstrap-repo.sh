#!/usr/bin/env bash
# Creates the FocusLearn monorepo directory skeleton. Idempotent.
set -euo pipefail

dirs=(
  apps/mobile apps/desktop apps/web apps/admin
  backend/supabase/migrations backend/supabase/functions/_shared
  backend/supabase/tests backend/supabase/seed
  packages/core packages/design_system
  docs/architecture docs/setup docs/security docs/privacy docs/deployment docs/user-guides
  infra/docker infra/cloudflare infra/backup infra/scripts
  test-vectors
  .github/workflows
)

for d in "${dirs[@]}"; do
  mkdir -p "$d"
  [ -e "$d/.gitkeep" ] || [ -n "$(ls -A "$d" 2>/dev/null)" ] || touch "$d/.gitkeep"
done

[ -f apps/web/README.md ] || cat > apps/web/README.md <<'EOF'
# apps/web
Placeholder. The web app is planned for after Phase 9. Do not build it before then.
EOF

echo "Repo skeleton ready."
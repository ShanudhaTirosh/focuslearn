#!/usr/bin/env bash
# Fails if any stack container publishes a port on all interfaces (0.0.0.0 or ::).
# Docker-published ports bypass ufw, so this matters on a home LAN.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STACK="$ROOT/docker/stack"
[ -d "$STACK" ] || { echo "stack not set up"; exit 1; }

out="$(cd "$STACK" && docker compose ps --format '{{.Name}}	{{.Ports}}' 2>/dev/null)"
printf '%s\n' "$out"
exposed="$(printf '%s\n' "$out" | grep -E '(^|[ ,])(0\.0\.0\.0|\[?::\]?):[0-9]+->' || true)"
if [ -n "$exposed" ]; then
  echo
  echo "FAIL: ports published on all interfaces:"
  printf '%s\n' "$exposed"
  echo "Bind them to 127.0.0.1 (see docs/setup/01-supabase-local.md, 'Port exposure')."
  exit 1
fi
echo "OK: no ports published on all interfaces"

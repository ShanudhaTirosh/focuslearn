#!/usr/bin/env bash
# One entry point for the local FocusLearn stack.
#   up        setup + start + health
#   setup     fetch pinned upstream, generate secrets, apply FocusLearn config
#   start|stop|status|logs [service]|health|exposure
#   secrets   print key credentials (contains secrets)
set -euo pipefail
export COMPOSE_PATH_SEPARATOR=":"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STACK="$ROOT/docker/stack"

run() { (cd "$STACK" && sh run.sh "$@"); }

case "${1:-}" in
  up)       bash "$ROOT/docker/setup.sh"; run start; bash "$ROOT/scripts/healthcheck.sh" ;;
  setup)    bash "$ROOT/docker/setup.sh" ;;
  start)    run start ;;
  stop)     run stop ;;
  status)   (cd "$STACK" && docker compose ps) ;;
  logs)     shift; run logs "$@" ;;
  health)   bash "$ROOT/scripts/healthcheck.sh" ;;
  exposure) bash "$ROOT/scripts/check-exposure.sh" ;;
  secrets)  run secrets ;;
  *) sed -n '2,7p' "${BASH_SOURCE[0]}"; exit 2 ;;
esac

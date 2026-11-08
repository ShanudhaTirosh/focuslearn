#!/usr/bin/env bash
# Installs the heartbeat timer. Needs sudo. Usage: bash infra/scripts/install-heartbeat.sh [--print-only DIR]
# Refuses to install while HEARTBEAT_URL is empty (a timer that cannot ping would only create noise).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
# shellcheck source=../docker/lib.sh
. "$REPO/infra/docker/lib.sh"
RUN_USER="${SUDO_USER:-$(id -un)}"

dest=/etc/systemd/system; print_only=0
if [ "${1:-}" = "--print-only" ]; then dest="${2:?DIR required}"; print_only=1; mkdir -p "$dest"; fi
if [ "$print_only" = 0 ] && [ -z "$(get_cfg "$REPO/infra/docker/.env" HEARTBEAT_URL)" ]; then
  echo "Set HEARTBEAT_URL in infra/docker/.env first (docs/setup/06-monitoring.md)." >&2; exit 1
fi
for u in service timer; do
  render_template "$HERE/focuslearn-heartbeat.$u.template" "$dest/focuslearn-heartbeat.$u" "RUN_USER=$RUN_USER" "REPO=$REPO"
done
if [ "$print_only" = 1 ]; then echo "rendered into $dest"; exit 0; fi
[ "$(id -u)" = 0 ] || { echo "run with sudo" >&2; exit 1; }
systemctl daemon-reload
systemctl enable --now focuslearn-heartbeat.timer
systemctl list-timers focuslearn-heartbeat.timer --no-pager

#!/usr/bin/env bash
# Installs the daily backup timer. Needs sudo. Usage: bash infra/backup/install-timer.sh [--print-only DIR]
#   --print-only DIR renders the units into DIR without installing (used by tests).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
# shellcheck source=../docker/lib.sh
. "$REPO/infra/docker/lib.sh"
RUN_USER="${SUDO_USER:-$(id -un)}"

dest=/etc/systemd/system
print_only=0
if [ "${1:-}" = "--print-only" ]; then dest="${2:?DIR required}"; print_only=1; mkdir -p "$dest"; fi

for u in service timer; do
  render_template "$HERE/focuslearn-backup.$u.template" "$dest/focuslearn-backup.$u" "RUN_USER=$RUN_USER" "REPO=$REPO"
done
if [ "$print_only" = 1 ]; then echo "rendered into $dest"; exit 0; fi

[ "$(id -u)" = 0 ] || { echo "run with sudo" >&2; exit 1; }
systemctl daemon-reload
systemctl enable --now focuslearn-backup.timer
systemctl list-timers focuslearn-backup.timer --no-pager
echo "Test now with: sudo systemctl start focuslearn-backup.service && journalctl -u focuslearn-backup.service -n 30 --no-pager"

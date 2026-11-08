#!/usr/bin/env bash
# FocusLearn: harden the Ubuntu machine that runs the stack (home laptop first, VPS later).
# DRY RUN by default: it prints what it would do. Nothing changes without --apply.
#
# Default modules : power time updates docker
# Extra (opt-in)  : --lan-cidr CIDR            adds the firewall module (ufw: deny incoming, SSH only from your LAN)
#                   --harden-ssh               adds ssh + fail2ban; REQUIRES --yes-i-have-a-working-ssh-key
# Options         : --apply  --only mod1,mod2  --ssh-user NAME  --auto-reboot HH:MM  -h
#
# Examples:
#   bash infra/scripts/harden-ubuntu.sh                                   # show the plan
#   sudo bash infra/scripts/harden-ubuntu.sh --apply                      # power, time, updates, docker
#   sudo bash infra/scripts/harden-ubuntu.sh --apply --lan-cidr 192.168.1.0/24 --harden-ssh --yes-i-have-a-working-ssh-key
#
# Test hooks (not for production): HARDEN_ROOT=<dir> prefixes every file path; HARDEN_NO_EXEC=1 skips system commands.
set -euo pipefail

log() { printf '[harden] %s\n' "$*"; }
die() { printf '[harden] ERROR: %s\n' "$*" >&2; exit 1; }
usage() { sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

APPLY=0; ONLY=""; LAN=""; SSH_USER="${SUDO_USER:-$(id -un)}"; HARDEN_SSH=0; SSH_KEY_OK=0; AUTO_REBOOT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1 ;;
    --only) ONLY="${2:?--only needs a list}"; shift ;;
    --lan-cidr) LAN="${2:?--lan-cidr needs a CIDR}"; shift ;;
    --ssh-user) SSH_USER="${2:?--ssh-user needs a name}"; shift ;;
    --harden-ssh) HARDEN_SSH=1 ;;
    --yes-i-have-a-working-ssh-key) SSH_KEY_OK=1 ;;
    --auto-reboot) AUTO_REBOOT="${2:?--auto-reboot needs HH:MM}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1 (see --help)" ;;
  esac
  shift
done

R="${HARDEN_ROOT:-}"
NOEXEC="${HARDEN_NO_EXEC:-0}"
if [ "$APPLY" = 1 ] && [ -z "$R" ] && [ "$(id -u)" != 0 ]; then die "--apply needs root (use sudo)"; fi
if [ -n "$AUTO_REBOOT" ] && ! printf '%s' "$AUTO_REBOOT" | grep -Eq '^([01][0-9]|2[0-3]):[0-5][0-9]$'; then die "--auto-reboot must be HH:MM"; fi

modules="power time updates docker"
[ -n "$LAN" ] && modules="$modules firewall"
[ "$HARDEN_SSH" = 1 ] && modules="$modules ssh fail2ban"
want() {
  case " $modules " in *" $1 "*) ;; *) return 1 ;; esac
  [ -z "$ONLY" ] || case ",$ONLY," in *",$1,"*) return 0 ;; *) return 1 ;; esac
}

write_file() {  # path mode ; content on stdin. Idempotent. Keeps a .focuslearn-bak of any file it replaces.
  local path="$R$1" mode="$2" content
  content="$(cat)"
  if [ -f "$path" ] && [ "$(cat "$path")" = "$content" ]; then log "unchanged: $1"; return 0; fi
  if [ "$APPLY" != 1 ]; then
    log "WOULD WRITE $1 (mode $mode)"; printf '%s\n' "$content" | sed 's/^/    | /'; return 0
  fi
  mkdir -p "$(dirname "$path")"
  [ -f "$path" ] && cp -p "$path" "$path.focuslearn-bak"
  printf '%s\n' "$content" > "$path"
  chmod "$mode" "$path"
  log "wrote $1"
}
run() {
  if [ "$APPLY" = 1 ] && [ "$NOEXEC" != 1 ]; then log "+ $*"; "$@"; else log "WOULD RUN: $*"; fi
}

mod_power() {
  log "== power: never sleep, ignore the lid, keep running 24/7"
  write_file /etc/systemd/logind.conf.d/99-focuslearn.conf 644 <<'CFG'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
IdleAction=ignore
CFG
  run systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
  run systemctl kill -s HUP systemd-logind
  log "manual (BIOS/UEFI): set 'Restore on AC power loss' / 'After power failure: Power On'. See docs/security/hardening.md"
  log "manual (desktop edition only, run as your user): gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'"
}

mod_time() {
  log "== time: clock must be correct (signed URLs, token expiry, TOTP)"
  run timedatectl set-ntp true
}

mod_updates() {
  log "== updates: automatic security updates, no automatic reboot unless you ask for one"
  run apt-get install -y unattended-upgrades
  write_file /etc/apt/apt.conf.d/20auto-upgrades 644 <<'CFG'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
CFG
  if [ -n "$AUTO_REBOOT" ]; then
    write_file /etc/apt/apt.conf.d/52focuslearn-unattended 644 <<CFG
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "$AUTO_REBOOT";
CFG
  else
    write_file /etc/apt/apt.conf.d/52focuslearn-unattended 644 <<'CFG'
Unattended-Upgrade::Remove-Unused-Dependencies "true";
// No automatic reboot: with full-disk encryption a reboot waits for your passphrase. Reboot in a planned window.
Unattended-Upgrade::Automatic-Reboot "false";
CFG
  fi
}

mod_docker() {
  log "== docker: start on boot, rotate container logs, keep containers up across daemon restarts"
  local f="$R/etc/docker/daemon.json" new
  new="$(python3 - "$f" <<'PY'
import json, os, sys
p = sys.argv[1]
cur = {}
if os.path.exists(p):
    txt = open(p, encoding="utf-8").read().strip()
    if txt:
        cur = json.loads(txt)
cur["log-driver"] = "json-file"
opts = dict(cur.get("log-opts", {}))
opts.update({"max-size": "10m", "max-file": "3"})
cur["log-opts"] = opts
cur["live-restore"] = True
print(json.dumps(cur, indent=2, sort_keys=True))
PY
)" || die "cannot parse $f (invalid JSON). Fix it by hand first."
  printf '%s\n' "$new" | write_file /etc/docker/daemon.json 644
  run systemctl enable docker
  log "NOTE: restart Docker in a quiet moment (sudo systemctl restart docker), then recreate the stack so log rotation applies: cd infra/docker/stack && sh run.sh recreate"
}

mod_firewall() {
  log "== firewall: deny incoming, SSH only from $LAN"
  python3 -c 'import ipaddress,sys; ipaddress.ip_network(sys.argv[1], strict=False)' "$LAN" 2>/dev/null || die "invalid CIDR: $LAN"
  if [ -n "${SSH_CONNECTION:-}" ]; then
    local client="${SSH_CONNECTION%% *}"
    python3 - "$LAN" "$client" <<'PY' || die "your current SSH client ($client) is outside $LAN: enabling the firewall could lock you out"
import ipaddress, sys
sys.exit(0 if ipaddress.ip_address(sys.argv[2]) in ipaddress.ip_network(sys.argv[1], strict=False) else 1)
PY
  fi
  run apt-get install -y ufw
  run ufw default deny incoming
  run ufw default allow outgoing
  run ufw allow from "$LAN" to any port 22 proto tcp comment 'ssh from LAN'
  run ufw --force enable
  log "NOTE: ufw does NOT filter ports published by Docker. The stack stays private because the gateway is bound to 127.0.0.1. Verify with: bash infra/scripts/check-exposure.sh"
}

mod_ssh() {
  log "== ssh: keys only, no root, no passwords"
  [ "$SSH_KEY_OK" = 1 ] || die "--harden-ssh needs --yes-i-have-a-working-ssh-key (password login will be disabled)"
  local ak="$R/home/$SSH_USER/.ssh/authorized_keys"
  grep -Eq '^(ssh-(rsa|ed25519|dss)|ecdsa-sha2-|sk-)' "$ak" 2>/dev/null \
    || die "no public key in $ak. Add one, then test a key login from a SECOND terminal before hardening."
  # Named 00- on purpose: sshd uses the FIRST value it reads, and files such as 50-cloud-init.conf may enable passwords.
  write_file /etc/ssh/sshd_config.d/00-focuslearn.conf 644 <<CFG
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
X11Forwarding no
MaxAuthTries 3
LoginGraceTime 30
ClientAliveInterval 300
ClientAliveCountMax 2
AllowUsers $SSH_USER
CFG
  if [ "$APPLY" = 1 ] && [ "$NOEXEC" != 1 ]; then
    if ! sshd -t; then
      rm -f "$R/etc/ssh/sshd_config.d/00-focuslearn.conf"
      [ -f "$R/etc/ssh/sshd_config.d/00-focuslearn.conf.focuslearn-bak" ] && mv "$R/etc/ssh/sshd_config.d/00-focuslearn.conf.focuslearn-bak" "$R/etc/ssh/sshd_config.d/00-focuslearn.conf"
      die "sshd -t rejected the configuration: change removed, nothing reloaded"
    fi
  fi
  run systemctl reload ssh
  log "KEEP YOUR CURRENT SSH SESSION OPEN and test a new key login from another terminal now."
}

mod_fail2ban() {
  log "== fail2ban: ban repeated SSH failures"
  run apt-get install -y fail2ban
  local ignore="127.0.0.1/8 ::1"
  [ -n "$LAN" ] && ignore="$ignore $LAN"
  write_file /etc/fail2ban/jail.d/focuslearn.local 644 <<CFG
[DEFAULT]
ignoreip = $ignore

[sshd]
enabled = true
backend = systemd
maxretry = 4
findtime = 10m
bantime = 1h
CFG
  run systemctl enable --now fail2ban
}

[ "$APPLY" = 1 ] && log "APPLYING changes" || log "DRY RUN: nothing will change (add --apply)"
for m in power time updates docker firewall ssh fail2ban; do
  if want "$m"; then "mod_$m"; fi
done
if [ "$APPLY" = 1 ]; then
  log "done. Reboot once when convenient, then run: bash infra/scripts/audit-host.sh"
else
  log "dry run complete. Review the plan, then re-run with --apply"
fi

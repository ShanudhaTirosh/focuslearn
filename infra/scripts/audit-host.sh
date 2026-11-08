#!/usr/bin/env bash
# Read-only audit of the host that runs the stack. Changes nothing. Run with sudo for the complete picture
# (ufw status and sshd -T need root; without root those checks WARN instead of failing).
# Usage: audit-host.sh            normal
#        REAL_USERS=1 audit-host.sh   treat missing disk encryption as FAIL (required before real student data)
# Exit code 1 if any FAIL.
set -uo pipefail

A="${AUDIT_ROOT:-}"   # test hook: prefixes file paths
fail=0
ok()   { printf 'OK    %s\n' "$1"; }
bad()  { printf 'FAIL  %s\n' "$1"; fail=1; }
warn() { printf 'WARN  %s\n' "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }
is_root() { [ "$(id -u)" = 0 ]; }

printf 'FocusLearn host audit %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# --- power: must never sleep
tgt_bad=""
if have systemctl; then
  for t in sleep suspend hibernate hybrid-sleep; do
    [ "$(systemctl is-enabled "$t.target" 2>/dev/null || true)" = masked ] || tgt_bad="$tgt_bad $t"
  done
  if [ -z "$tgt_bad" ]; then ok "sleep, suspend, hibernate targets are masked"; else bad "not masked:$tgt_bad (run harden-ubuntu.sh --apply)"; fi
  if have systemd-analyze; then
    cfg="$(systemd-analyze cat-config systemd/logind.conf 2>/dev/null || true)"
    if printf '%s\n' "$cfg" | grep -Eq '^HandleLidSwitch=ignore' && printf '%s\n' "$cfg" | grep -Eq '^HandleLidSwitchExternalPower=ignore'; then
      ok "lid close is ignored"
    else
      bad "lid close is not ignored in logind configuration"
    fi
  else
    warn "systemd-analyze missing: cannot check lid settings"
  fi
else
  warn "systemctl missing: power and service checks skipped (is this Linux with systemd?)"
fi

# --- time
if have timedatectl; then
  if [ "$(timedatectl show -p NTPSynchronized --value 2>/dev/null || echo no)" = yes ]; then ok "clock is NTP-synchronised"; else bad "clock is not NTP-synchronised (signed URLs and tokens can fail)"; fi
else
  warn "timedatectl missing: cannot check time sync"
fi

# --- updates
if have dpkg && dpkg -s unattended-upgrades >/dev/null 2>&1; then
  if have apt-config && apt-config dump 2>/dev/null | grep -q 'APT::Periodic::Unattended-Upgrade "1"'; then ok "unattended security upgrades enabled"; else bad "unattended-upgrades installed but not enabled"; fi
else
  bad "unattended-upgrades is not installed"
fi
if [ -f "$A/var/run/reboot-required" ]; then warn "reboot required since $(stat -c %y "$A/var/run/reboot-required" 2>/dev/null | cut -d. -f1): plan a maintenance window"; else ok "no reboot pending"; fi

# --- ssh, firewall, fail2ban
ssh_active=0
if have systemctl && { systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null || systemctl is-active --quiet ssh.socket 2>/dev/null; }; then ssh_active=1; fi
if [ "$ssh_active" = 1 ]; then
  if have sshd && is_root; then
    eff="$(sshd -T 2>/dev/null || true)"
    printf '%s\n' "$eff" | grep -qi '^passwordauthentication no' && ok "ssh: password login disabled" || bad "ssh: password login is enabled"
    printf '%s\n' "$eff" | grep -Eqi '^permitrootlogin (no|prohibit-password)' && ok "ssh: root login restricted" || bad "ssh: root login is permitted"
  else
    warn "ssh is running; run with sudo to check its effective settings"
  fi
  if have systemctl && systemctl is-active --quiet fail2ban 2>/dev/null; then ok "fail2ban is active"; else bad "ssh is running but fail2ban is not active"; fi
else
  ok "ssh is not running (console access only)"
fi
if have ufw; then
  if is_root; then ufw status 2>/dev/null | grep -q '^Status: active' && ok "ufw firewall active" || warn "ufw installed but inactive"; else warn "run with sudo to check ufw"; fi
else
  warn "ufw not installed (acceptable while nothing listens beyond loopback; see listeners below)"
fi

# --- listeners reachable beyond loopback
if have ss; then
  exposed="$(ss -tlnH 2>/dev/null | awk '{print $4}' | grep -Ev '^(127\.|\[::1\]|::1)' | grep -E ':(5432|6543|8000|8443|3000|2000)$' || true)"
  if [ -n "$exposed" ]; then bad "stack ports reachable beyond loopback: $(printf '%s' "$exposed" | tr '\n' ' ')"; else ok "no stack ports (5432, 6543, 8000, 8443, 3000, 2000) listening beyond loopback"; fi
  other="$(ss -tlnH 2>/dev/null | awk '{print $4}' | grep -Ev '^(127\.|\[::1\]|::1)' | sort -u | tr '\n' ' ' || true)"
  [ -n "$other" ] && warn "other listeners beyond loopback: $other"
else
  warn "ss missing: cannot list listeners"
fi

# --- docker
if have docker && have systemctl; then
  systemctl is-enabled docker >/dev/null 2>&1 && ok "docker starts on boot" || bad "docker is not enabled on boot"
  if [ -f "$A/etc/docker/daemon.json" ] && grep -q '"max-size"' "$A/etc/docker/daemon.json"; then ok "docker log rotation configured"; else bad "docker log rotation not configured (disk can fill with logs)"; fi
else
  warn "docker not found: skipped"
fi

# --- disk encryption
if have lsblk && lsblk -rno TYPE 2>/dev/null | grep -q '^crypt$'; then
  ok "disk encryption (LUKS/dm-crypt) is in use"
elif [ "${REAL_USERS:-0}" = 1 ]; then
  bad "no disk encryption detected: required before real student data (theft would expose it)"
else
  warn "no disk encryption detected: required before real student data (REAL_USERS=1 makes this a FAIL)"
fi

# --- memory
if [ -r "$A/proc/meminfo" ]; then
  mem_mb=$(( $(awk '/^MemTotal:/{print $2}' "$A/proc/meminfo") / 1024 ))
  swap_mb=$(( $(awk '/^SwapTotal:/{print $2}' "$A/proc/meminfo") / 1024 ))
  if [ "$mem_mb" -lt 3800 ]; then bad "RAM ${mem_mb} MB is below the 4 GB official minimum for the stack"
  elif [ "$mem_mb" -lt 7600 ]; then
    if [ "$swap_mb" -ge 2048 ]; then ok "RAM ${mem_mb} MB with ${swap_mb} MB swap (8 GB advised)"; else warn "RAM ${mem_mb} MB (8 GB advised) and only ${swap_mb} MB swap"; fi
  else ok "RAM ${mem_mb} MB"; fi
fi

# --- battery (laptop)
bat="$(ls -d "$A"/sys/class/power_supply/BAT* 2>/dev/null | head -n1 || true)"
if [ -n "$bat" ]; then
  st="$(cat "$bat/status" 2>/dev/null || echo unknown)"; cap="$(cat "$bat/capacity" 2>/dev/null || echo '?')"
  if [ "$st" = Discharging ]; then warn "running on battery ($cap%): check the power adapter and any UPS"; else ok "on mains power, battery $cap% ($st)"; fi
  thr="$bat/charge_control_end_threshold"
  if [ -r "$thr" ]; then
    [ "$(cat "$thr")" -ge 100 ] && warn "battery charge limit is 100%: an 80% limit extends battery life on a 24/7 machine (vendor setting, see hardening.md)" || ok "battery charge limit $(cat "$thr")%"
  else
    warn "no battery charge limit control found (set one in BIOS or with the vendor tool if available)"
  fi
fi

# --- secret files: readable by the owner only
REPO="${AUDIT_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
for rel in infra/docker/stack/.env infra/docker/.env infra/backup/.env infra/cloudflare/.env; do
  f="$REPO/$rel"
  if [ -f "$f" ]; then
    m="$(stat -c %a "$f" 2>/dev/null || echo '?')"
    if [ "$m" = 600 ]; then ok "$rel mode 600"; else bad "$rel has mode $m (must be 600: chmod 600 $rel)"; fi
  fi
done

exit "$fail"

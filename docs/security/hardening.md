# Hardening the host (Phase 0.9)

Scope: the Ubuntu machine that runs the stack. First your home laptop (development and a small private pilot), later a VPS.
Honest summary: a home laptop has no redundancy and weak physical security. It is acceptable for development and a private pilot **only if the items marked REQUIRED are done**.
Anything involving real student data (many are minors) also needs your lawyer's PDPA review (`DATA_INVENTORY.md`).

## What the scripts do and do not do
| Script | Does | Does not |
|---|---|---|
| `infra/scripts/harden-ubuntu.sh` | Never sleep, ignore lid, clock sync, automatic security updates, Docker start on boot and log rotation, optional firewall and SSH hardening and fail2ban. **Dry run by default.** | BIOS settings, disk encryption, UPS, router settings, battery care, anything on Windows |
| `infra/scripts/audit-host.sh` | Read-only check of the result, exit 1 on any FAIL | Fix anything |
| `infra/scripts/check-exposure.sh` | Fails if a stack container publishes a port on all interfaces | Check the host's other services (the audit lists those) |

Run order: `bash infra/scripts/harden-ubuntu.sh` (read the plan) then `sudo bash infra/scripts/harden-ubuntu.sh --apply`, reboot once, then `sudo bash infra/scripts/audit-host.sh`.
Before any real student data: `sudo REAL_USERS=1 bash infra/scripts/audit-host.sh` must exit 0.

## Checklist
| # | Item | REQUIRED for real users? | How | Automated |
|---|---|---|---|---|
| 1 | Machine never sleeps, lid ignored | Yes | logind drop-in, masked sleep targets | script |
| 2 | Starts by itself after a power cut | Yes | BIOS/UEFI "Restore on AC power loss" or "After power failure: Power On" | **manual** |
| 3 | Docker starts on boot, stack restarts | Yes | `systemctl enable docker`, upstream restart policies | script + audit |
| 4 | Clock synchronised | Yes | `timedatectl set-ntp true` | script + audit |
| 5 | Automatic security updates, planned reboots | Yes | unattended-upgrades, no automatic reboot by default | script + audit |
| 6 | Disk encryption | **Yes** | chosen at OS install (see the trade-off below) | audit only |
| 7 | Gateway and database reachable only on loopback | Yes | compose override, `check-exposure.sh` | scripts |
| 8 | No inbound ports, no router port-forwarding | Yes | Cloudflare Tunnel is outbound only. Do not forward ports | **manual** |
| 9 | SSH keys only, LAN only, no root | If SSH is on | `--harden-ssh`, firewall, fail2ban | script + audit |
| 10 | Docker log rotation | Yes | `daemon.json` | script + audit |
| 11 | Secret files mode 600, never in git | Yes | upstream scripts, setup scripts, audit check | audit |
| 12 | Backups verified by a restore drill | Yes | `docs/RUNBOOK.md` | scripts |
| 13 | Wired Ethernet, DHCP reservation | Yes | router setting, Wi-Fi power saving off if Wi-Fi is the only option | **manual** |
| 14 | UPS | Strongly advised | a small UPS covers short cuts and gives time for a clean shutdown | **manual** |
| 15 | Heat and battery care | Yes | see below | **manual** |

## Laptop 24/7 specifics
- **BIOS/UEFI (manual):** find the AC power-loss option (names vary: "Restore on AC Power Loss", "After Power Failure", "Wake on AC"). Disable wake-on-LAN unless you use it. Test by pulling the plug and reconnecting.
- **Heat:** running with the lid closed can raise temperatures on many models because the keyboard area vents heat. Check temperatures with `sensors` (package `lm-sensors`) under load. Prefer a hard surface, open vents, optionally a stand, and dust cleaning every few months.
- **Battery:** a lithium battery held at 100% on mains for months ages quickly and can swell (a fire and safety risk). If your laptop has a charge limit (BIOS or vendor tool, often 80%), set it. The audit warns when the limit is 100% or unknown. If the battery is removable and the laptop runs fine without it, removing it is an option, but then a power cut is an instant shutdown without a UPS.
- **Network:** use Ethernet. Reserve the laptop's IP in the router so the LAN address does not change. Two ISPs only help with a router that does dual-WAN failover (`02-cloudflare-edge.md`, test F).
- **Power:** a UPS also protects the disk from corruption during cuts, which are the most likely failure at home.

## Full-disk encryption: the real trade-off (decision needed from you)
Theft is in the threat model (`THREAT_MODEL.md`), and the disk will hold minors' data. Disk encryption (LUKS) is chosen when installing Ubuntu: adding it later usually means reinstalling.
The catch: with a passphrase, **after a power cut or reboot the machine waits at the passphrase prompt** until someone types it. That conflicts with "starts by itself".
| Option | Protects against theft of the powered-off laptop | Survives a power cut unattended | Notes |
|---|---|---|---|
| A. LUKS with passphrase | Yes | **No**, needs a person at the keyboard | Recommended for real student data, together with a UPS |
| B. LUKS with TPM2 auto-unlock | Disk removed from the laptop: yes. Laptop stolen and powered on: **no** | Yes | `systemd-cryptenroll` or clevis: verify support on your Ubuntu version before relying on it |
| C. No encryption | No | Yes | Only for development with no real data |
My default recommendation: A for the pilot with real students, accept occasional manual unlock, and move to a VPS (provider-managed disks plus your own encryption choices) for production.

## Accounts, SSH and the firewall
- Use a normal user with sudo. Membership of the `docker` group is effectively root: keep that account private.
- Prefer console or LAN-only SSH with keys. **Never forward a router port to this machine.**
- `--harden-ssh` writes `/etc/ssh/sshd_config.d/00-focuslearn.conf`. The name starts with `00-` because sshd uses the **first** value it reads, and cloud images often ship `50-cloud-init.conf` enabling passwords.
- The firewall module refuses to run if your current SSH client is outside the LAN range you passed, and the SSH module refuses without a real key in `authorized_keys` and the explicit confirmation flag. Always keep your current SSH session open and test a second login before closing it.
- `ufw` does **not** filter ports that Docker publishes. The stack is private because the gateway is bound to `127.0.0.1`, which `check-exposure.sh` and the audit verify.
- Remote administration without opening ports (optional, not configured): Cloudflare Tunnel can carry SSH behind Access. Verify the current Cloudflare instructions before using it.

## Updates and reboots
Security updates install automatically. Kernel updates need a reboot: plan a monthly window, take a backup first, and check `stack.sh health` afterwards. `--auto-reboot HH:MM` exists but, with disk encryption option A, a reboot waits for your passphrase.
Docker images are pinned, so they change only through the upgrade procedure in `RUNBOOK.md` section 7.

## Not done here (known gaps)
- journald size limit (set `SystemMaxUse=500M` in `/etc/systemd/journald.conf.d/` yourself if the disk is small).
- Intrusion detection, file integrity monitoring, SELinux/AppArmor tuning for containers: out of scope for the pilot.
- Docker rootless mode and per-container user namespaces: not evaluated.
- Kernel and package CVE scanning of the host beyond unattended-upgrades.

## Appendix: Windows laptop (WSL2): manual steps, all to verify
The scripts above are Ubuntu-only. If the laptop runs Windows 11 with WSL2:
- **Power:** `powercfg /change standby-timeout-ac 0`, `powercfg /change hibernate-timeout-ac 0`, and disable lid action on AC (`powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0` then `powercfg /setactive SCHEME_CURRENT`).
- **Updates:** Windows Update restarts the machine. Set active hours and avoid automatic restarts while signed out, otherwise WSL (and the stack) stays down until someone signs in.
- **Auto-start:** WSL starts only when something launches it. Use Task Scheduler (trigger: at startup, run whether the user is logged on or not) to run a WSL command that keeps the distro up and starts Docker. Enable systemd in the distro (`/etc/wsl.conf`, `[boot] systemd=true`) and `systemctl enable docker` inside it. Test with a reboot.
- **Encryption:** BitLocker with TPM auto-unlock gives the "survives a power cut" behaviour of option B above, with the same limits.
- **Resources:** cap WSL memory in `%UserProfile%\.wslconfig` (for example `[wsl2]` with `memory=` and `swap=`) so Windows keeps enough RAM.
- Keep the repo inside the WSL filesystem, not under `/mnt/c`, for speed and correct file modes (secret files must be mode 600).
- `cloudflared` is outbound only, so no Windows firewall rules are needed for the tunnel. Do not publish ports to the Windows LAN.

## Known issues
- **Not run on a real machine.** Verified offline: 38 tests (`python3 infra/scripts/tests/test_host_tools.py`) cover file contents, idempotence, JSON merge safety, the lock-out guards (CIDR, key presence, confirmation flag), option handling, and every audit branch using stand-in commands.
  Not verified: that the real `systemctl`, `ufw`, `sshd -t`, `apt`, `timedatectl` and `fail2ban` behave as the script assumes on your Ubuntu version. Run the dry run first, then apply the default modules, audit, and only then the optional ones.
- `systemctl kill -s HUP systemd-logind` should reload the lid settings without logging you out. If the lid still suspends the machine, reboot and re-audit.
- Docker's `live-restore` only takes effect after a daemon restart, and the first restart stops running containers.

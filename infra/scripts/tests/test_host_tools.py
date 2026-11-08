"""Offline tests for harden-ubuntu.sh and audit-host.sh. No root, no system changes.
harden-ubuntu.sh is exercised with HARDEN_ROOT (all paths prefixed) and HARDEN_NO_EXEC=1 (no system commands).
audit-host.sh is exercised with AUDIT_ROOT and stand-in system commands on PATH."""
import json, os, shutil, stat, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
HARDEN = os.path.join(HERE, "..", "harden-ubuntu.sh")
AUDIT = os.path.join(HERE, "..", "audit-host.sh")
results = []

def check(name, cond, detail=""):
    results.append(bool(cond)); print(("PASS  " if cond else "FAIL  ") + name + (f"   [{detail}]" if (detail and not cond) else ""))

def harden(root, *args, env=None):
    e = dict(os.environ); e.update({"HARDEN_ROOT": root, "HARDEN_NO_EXEC": "1"}); e.pop("SSH_CONNECTION", None); e.update(env or {})
    return subprocess.run(["bash", HARDEN, *args], capture_output=True, text=True, env=e)

def rd(root, rel):
    return open(os.path.join(root, rel.lstrip("/")), encoding="utf-8").read()

def tree(root):
    return sorted(os.path.join(dp, f)[len(root):] for dp, _, fs in os.walk(root) for f in fs)

tmp = tempfile.mkdtemp(prefix="host-test-")
try:
    # ---------------------------------------------------------------- harden: dry run and apply
    r0 = os.path.join(tmp, "dry"); os.makedirs(r0)
    r = harden(r0)
    check("dry run exits 0 and writes nothing", r.returncode == 0 and tree(r0) == [] and "DRY RUN" in r.stdout, r.stderr)

    r1 = os.path.join(tmp, "apply"); os.makedirs(r1)
    r = harden(r1, "--apply")
    check("apply (default modules) succeeds", r.returncode == 0, r.stderr)
    lg = rd(r1, "/etc/systemd/logind.conf.d/99-focuslearn.conf")
    check("logind drop-in ignores the lid in every power state", all(k in lg for k in ("HandleLidSwitch=ignore", "HandleLidSwitchExternalPower=ignore", "HandleLidSwitchDocked=ignore", "IdleAction=ignore")))
    check("auto-upgrades enabled", 'Unattended-Upgrade "1"' in rd(r1, "/etc/apt/apt.conf.d/20auto-upgrades"))
    check("automatic reboot off by default", 'Automatic-Reboot "false"' in rd(r1, "/etc/apt/apt.conf.d/52focuslearn-unattended"))
    d = json.loads(rd(r1, "/etc/docker/daemon.json"))
    check("docker log rotation and live-restore set", d["log-driver"] == "json-file" and d["log-opts"] == {"max-file": "3", "max-size": "10m"} and d["live-restore"] is True)
    check("no firewall or ssh files without their flags", not any(("ufw" in f or "sshd_config" in f or "fail2ban" in f) for f in tree(r1)))

    before = tree(r1)
    r = harden(r1, "--apply")
    check("second apply is idempotent (all unchanged, no backups created)", r.returncode == 0 and "wrote " not in r.stdout and tree(r1) == before and "unchanged" in r.stdout, r.stdout[-300:])

    # ---------------------------------------------------------------- docker merge safety
    r2 = os.path.join(tmp, "merge"); os.makedirs(os.path.join(r2, "etc/docker"))
    open(os.path.join(r2, "etc/docker/daemon.json"), "w").write(json.dumps({"registry-mirrors": ["https://m.example"], "log-opts": {"labels": "x", "max-size": "1g"}}))
    r = harden(r2, "--apply", "--only", "docker")
    d = json.loads(rd(r2, "/etc/docker/daemon.json"))
    check("docker merge keeps existing keys and overrides only ours", d["registry-mirrors"] == ["https://m.example"] and d["log-opts"]["labels"] == "x" and d["log-opts"]["max-size"] == "10m")
    check("previous daemon.json kept as .focuslearn-bak", os.path.exists(os.path.join(r2, "etc/docker/daemon.json.focuslearn-bak")))
    r3 = os.path.join(tmp, "badjson"); os.makedirs(os.path.join(r3, "etc/docker")); open(os.path.join(r3, "etc/docker/daemon.json"), "w").write("{bad")
    r = harden(r3, "--apply", "--only", "docker")
    check("invalid existing daemon.json: refuses and leaves it untouched", r.returncode != 0 and rd(r3, "/etc/docker/daemon.json") == "{bad" and "invalid JSON" in r.stderr, r.stderr)

    # ---------------------------------------------------------------- options
    r4 = os.path.join(tmp, "reboot"); os.makedirs(r4)
    r = harden(r4, "--apply", "--only", "updates", "--auto-reboot", "03:30")
    t = rd(r4, "/etc/apt/apt.conf.d/52focuslearn-unattended")
    check("--auto-reboot writes the reboot window", 'Automatic-Reboot "true"' in t and 'Automatic-Reboot-Time "03:30"' in t, r.stderr)
    check("--auto-reboot rejects a bad time", harden(r4, "--auto-reboot", "25:99").returncode != 0)
    ro = os.path.join(tmp, "only"); os.makedirs(ro); harden(ro, "--apply", "--only", "power")
    check("--only power writes only the power file", tree(ro) == ["/etc/systemd/logind.conf.d/99-focuslearn.conf"], str(tree(ro)))
    check("unknown argument is rejected", harden(ro, "--nope").returncode != 0)
    if os.geteuid() != 0:
        e = dict(os.environ); e.pop("HARDEN_ROOT", None)
        r = subprocess.run(["bash", HARDEN, "--apply", "--only", "time"], capture_output=True, text=True, env=e)
        check("--apply without root (and no test root) is refused", r.returncode != 0 and "root" in r.stderr, r.stderr)
    else:
        print("SKIP  non-root refusal test (the test runner is root)")

    # ---------------------------------------------------------------- firewall guards
    rf = os.path.join(tmp, "fw"); os.makedirs(rf)
    check("invalid CIDR is rejected", harden(rf, "--lan-cidr", "not-a-cidr").returncode != 0)
    r = harden(rf, "--lan-cidr", "192.168.1.0/24", env={"SSH_CONNECTION": "10.9.9.9 50000 192.168.1.5 22"})
    check("firewall refuses when the current SSH client is outside the LAN range", r.returncode != 0 and "lock you out" in r.stderr, r.stderr)
    r = harden(rf, "--lan-cidr", "192.168.1.0/24", env={"SSH_CONNECTION": "192.168.1.77 50000 192.168.1.5 22"})
    check("firewall plan accepted for a client inside the LAN range", r.returncode == 0 and "ufw allow from 192.168.1.0/24 to any port 22" in r.stdout, r.stderr)
    r = harden(rf, "--lan-cidr", "192.168.1.0/24")
    check("firewall plan denies incoming by default", "ufw default deny incoming" in r.stdout and "--force enable" in r.stdout)

    # ---------------------------------------------------------------- ssh guards
    rs = os.path.join(tmp, "ssh"); os.makedirs(rs)
    r = harden(rs, "--harden-ssh", "--ssh-user", "alice")
    check("--harden-ssh without the explicit key confirmation is refused", r.returncode != 0 and "yes-i-have-a-working-ssh-key" in r.stderr, r.stderr)
    r = harden(rs, "--harden-ssh", "--yes-i-have-a-working-ssh-key", "--ssh-user", "alice")
    check("refused when the user has no authorized_keys", r.returncode != 0 and "no public key" in r.stderr, r.stderr)
    os.makedirs(os.path.join(rs, "home/alice/.ssh")); open(os.path.join(rs, "home/alice/.ssh/authorized_keys"), "w").write("# ssh-ed25519 commented out\n")
    r = harden(rs, "--harden-ssh", "--yes-i-have-a-working-ssh-key", "--ssh-user", "alice")
    check("a commented-out key does not count", r.returncode != 0 and "no public key" in r.stderr)
    open(os.path.join(rs, "home/alice/.ssh/authorized_keys"), "w").write("ssh-ed25519 AAAAC3Nza fake@test\n")
    r = harden(rs, "--apply", "--harden-ssh", "--yes-i-have-a-working-ssh-key", "--ssh-user", "alice", "--lan-cidr", "192.168.1.0/24")
    check("ssh hardening applies with a key present", r.returncode == 0, r.stderr)
    names = [f for f in tree(rs) if "sshd_config.d" in f]
    check("ssh drop-in is named 00- so it wins first-match precedence over 50-cloud-init", names == ["/etc/ssh/sshd_config.d/00-focuslearn.conf"], str(names))
    cfg = rd(rs, "/etc/ssh/sshd_config.d/00-focuslearn.conf")
    check("ssh config: no passwords, no root, only the named user", "PasswordAuthentication no" in cfg and "PermitRootLogin no" in cfg and "AllowUsers alice" in cfg and "KbdInteractiveAuthentication no" in cfg)
    jail = rd(rs, "/etc/fail2ban/jail.d/focuslearn.local")
    check("fail2ban jail enabled, LAN not banned", "[sshd]" in jail and "enabled = true" in jail and "192.168.1.0/24" in jail and "backend = systemd" in jail)

    # ---------------------------------------------------------------- audit with stand-in commands
    def make_env(name, **over):
        root = os.path.join(tmp, name); b = os.path.join(root, "bin"); os.makedirs(b)
        for d in ("var/run", "etc/docker", "proc", "sys/class/power_supply/BAT0"): os.makedirs(os.path.join(root, d), exist_ok=True)
        open(os.path.join(root, "etc/docker/daemon.json"), "w").write('{"log-opts":{"max-size":"10m"}}')
        open(os.path.join(root, "proc/meminfo"), "w").write("MemTotal:       16000000 kB\nSwapTotal:       4000000 kB\n")
        bat = os.path.join(root, "sys/class/power_supply/BAT0")
        open(bat + "/status", "w").write("Charging\n"); open(bat + "/capacity", "w").write("80\n"); open(bat + "/charge_control_end_threshold", "w").write("80\n")
        def shim(n, body):
            p = os.path.join(b, n); open(p, "w").write("#!/usr/bin/env bash\n" + body + "\n"); os.chmod(p, 0o755)
        shim("systemctl", 'case "$1" in\n is-enabled) case "$2" in docker) echo enabled; exit 0;; *.target) echo masked; exit 0;; esac; exit 1;;\n is-active) exit 3;;\nesac\nexit 0')
        shim("systemd-analyze", 'printf "[Login]\\nHandleLidSwitch=ignore\\nHandleLidSwitchExternalPower=ignore\\n"')
        shim("timedatectl", 'echo "%s"' % over.get("ntp", "yes"))
        shim("dpkg", "exit 0"); shim("apt-config", 'echo \'APT::Periodic::Unattended-Upgrade "1";\'')
        shim("docker", "exit 0")
        shim("lsblk", 'echo "%s"' % over.get("lsblk", "disk\ncrypt"))
        shim("ss", 'echo "%s"' % over.get("ss", "LISTEN 0 4096 127.0.0.1:8000 0.0.0.0:*"))
        return root
    def audit(root, **env):
        e = dict(os.environ); e.update({"PATH": os.path.join(root, "bin") + os.pathsep + "/usr/bin:/bin", "AUDIT_ROOT": root}); e.update(env)
        return subprocess.run(["bash", AUDIT], capture_output=True, text=True, env=e)

    good = make_env("a_good"); r = audit(good, REAL_USERS="1")
    check("audit: a fully hardened host exits 0", r.returncode == 0 and "FAIL" not in r.stdout, r.stdout)
    bad = make_env("a_bad_ntp", ntp="no"); r = audit(bad)
    check("audit: unsynchronised clock fails", r.returncode == 1 and "FAIL  clock" in r.stdout)
    bad = make_env("a_bad_ss", ss="LISTEN 0 4096 0.0.0.0:8000 0.0.0.0:*"); r = audit(bad)
    check("audit: gateway port reachable beyond loopback fails", r.returncode == 1 and "stack ports reachable" in r.stdout, r.stdout)
    bad = make_env("a_bad_log"); os.remove(os.path.join(bad, "etc/docker/daemon.json")); r = audit(bad)
    check("audit: missing docker log rotation fails", r.returncode == 1 and "log rotation not configured" in r.stdout)
    bad = make_env("a_nocrypt", lsblk="disk\npart"); r = audit(bad)
    check("audit: no disk encryption only warns by default", r.returncode == 0 and "WARN  no disk encryption" in r.stdout, r.stdout)
    r = audit(bad, REAL_USERS="1")
    check("audit: no disk encryption fails when REAL_USERS=1", r.returncode == 1 and "FAIL  no disk encryption" in r.stdout)
    low = make_env("a_lowram"); open(os.path.join(low, "proc/meminfo"), "w").write("MemTotal:  2000000 kB\nSwapTotal: 0 kB\n"); r = audit(low)
    check("audit: RAM below the 4 GB official minimum fails", r.returncode == 1 and "below the 4 GB" in r.stdout)
    mid = make_env("a_mid"); open(os.path.join(mid, "proc/meminfo"), "w").write("MemTotal:  4000000 kB\nSwapTotal: 0 kB\n"); r = audit(mid)
    check("audit: 4 GB without swap warns", r.returncode == 0 and "WARN  RAM" in r.stdout, r.stdout)
    bt = make_env("a_batt"); open(os.path.join(bt, "sys/class/power_supply/BAT0/status"), "w").write("Discharging\n"); r = audit(bt)
    check("audit: running on battery warns", "WARN  running on battery" in r.stdout)
    rr = make_env("a_reboot"); open(os.path.join(rr, "var/run/reboot-required"), "w").write("*** System restart required ***\n"); r = audit(rr)
    check("audit: pending reboot warns", "WARN  reboot required" in r.stdout)
    # secret file permissions
    pr = make_env("a_perm"); repo = os.path.join(pr, "repo"); os.makedirs(os.path.join(repo, "infra/docker/stack"))
    envf = os.path.join(repo, "infra/docker/stack/.env"); open(envf, "w").write("X=1\n"); os.chmod(envf, 0o644)
    r = audit(pr, AUDIT_REPO=repo)
    check("audit: a secrets .env with mode 644 fails", r.returncode == 1 and "mode 644" in r.stdout, r.stdout[-300:])
    os.chmod(envf, 0o600); r = audit(pr, AUDIT_REPO=repo)
    check("audit: the same file at mode 600 passes", "infra/docker/stack/.env mode 600" in r.stdout and "FAIL  infra" not in r.stdout)
finally:
    shutil.rmtree(tmp, ignore_errors=True)

print(f"\n{sum(results)} passed, {len(results) - sum(results)} failed")
sys.exit(0 if all(results) else 1)

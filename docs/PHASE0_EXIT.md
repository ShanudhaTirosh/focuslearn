# Phase 0 exit checklist

Roadmap exit criteria for Phase 0: **the stack boots with one command, health checks are green, and a restore drill is documented.**
We also set stricter ones: private edge verified, email delivered, R2 proven, backups verified by a drill, monitoring alarms tested.

**Honest status:** everything is written and tested **offline** with stand-in programs (18 suites, 575 checks: `bash infra/scripts/tests/run-all.sh`).
**Nothing has run on a real machine yet.** Phase 0 is complete only when the report in step 10 shows no FAIL and `docs/setup/measurements.md` is filled in.

## Decisions I need from you (they change what we build)
| # | Decision | Why it matters | My recommendation |
|---|---|---|---|
| 1 | Disk encryption: passphrase, TPM auto-unlock, or none | Minors' data, theft in the threat model, versus unattended restart after a power cut | Passphrase plus a UPS for real students (`docs/security/hardening.md`) |
| 2 | Did R2 ask for a payment method? | "Stay free" may be impossible for storage | Check before creating buckets |
| 3 | Did Zero Trust or Brevo ask for a card? | Same | Check at sign-up |
| 4 | Laptop OS and RAM | Below 8 GB the stack will swap | The report prints both |
| 5 | Second ISP: router failover or not | Without it the second ISP adds nothing | Measure in the edge tests |
| 6 | Hostnames: flat `eduapp-*.shanutechx.com` (Option A) | Free certificates only cover one level | Confirmed earlier |

## Do this on your laptop, in this order
Why this order: the stack must run before the edge; email must be tested **before** Turnstile (captcha blocks scripted signups); backups before any real data.
Paste the final report after step 10, or after any step that fails.

| # | Step | Commands (repo root) | Done when |
|---|---|---|---|
| 0 | Prerequisites | Ubuntu 24.04, Docker Engine + Compose plugin, `git curl jq python3`. Copy all delivered files into the repo and commit | `docker compose version` works |
| 1 | Offline tests | `bash infra/scripts/tests/run-all.sh` | `ALL SUITES PASSED` (if not, send the output: a tool version differs from my assumptions) |
| 2 | Harden the host | `bash infra/scripts/harden-ubuntu.sh` (read), `sudo bash infra/scripts/harden-ubuntu.sh --apply`, reboot, `sudo bash infra/scripts/audit-host.sh`. Set the BIOS power-loss option by hand | audit has no FAIL |
| 3 | Stack, local mode | `cp infra/docker/.env.example infra/docker/.env`, `bash infra/scripts/stack.sh up`, then `stack.sh exposure` | health green, exposure OK, Studio opens at `http://localhost:8000` |
| 4 | Database baseline | `bash infra/scripts/migrate.sh`, `bash infra/scripts/run-pgtap.sh` | migration applied, 16 pgTAP assertions pass |
| 5 | Backups | Create age keys on another machine (`docs/RUNBOOK.md` section 2); create the R2 backups bucket and token (`infra/cloudflare/r2-setup.md`); fill `infra/backup/.env`; `bash infra/backup/backup.sh`; `sudo bash infra/backup/install-timer.sh`; `bash infra/backup/verify-restore.sh --identity <file>` | **restore drill prints `RESULT: PASS`**; note the seconds |
| 6 | Email | Brevo account, DNS records, `infra/docker/.env` SMTP values (`docs/setup/04-email.md`); `check-email-dns.sh`, `send-test-email.py`, then `auth-email-probe.sh` in **local mode** | mail in the inbox with DKIM and DMARC pass; confirmation link works; you know the link's path |
| 7 | Cloudflare edge | Tunnel, Access for Studio, set `FOCUSLEARN_MODE=public`, Turnstile (`docs/setup/02-cloudflare-edge.md`); `stack.sh setup` and recreate; `bash infra/scripts/verify-edge.sh --probe-captcha` | no FAIL |
| 8 | R2 | Buckets, tokens, CORS, lifecycle (`infra/cloudflare/r2-setup.md`); fill `infra/cloudflare/.env`; `python3 infra/cloudflare/r2-spike/r2_spike.py` | no FAIL; answers to the signed-content-length and CORS questions recorded |
| 9 | Monitoring | Healthchecks.io checks, `HEARTBEAT_URL`, `BACKUP_PING_URL`, `sudo bash infra/scripts/install-heartbeat.sh` (`docs/setup/06-monitoring.md`); run the four alarm tests | an alert actually arrives for the silence test |
| 10 | The report | `P0_EMAIL_DOMAIN=eduapp.shanutechx.com P0_DKIM_SELECTORS="<sel1> <sel2>" P0_TEST_EMAIL=you@gmail.com P0_AGE_IDENTITY=<identity file> bash infra/scripts/phase0-verify.sh` | **no FAIL** |

## The gate
Phase 0 exits when all of these are true: the step 10 report has no FAIL; the restore drill passed; `docs/setup/measurements.md` has real numbers; every decision above is recorded; every line of the list below is either confirmed or turned into a fix.
Then Phase 1 starts. I will not start it on assumptions.

## Everything I assumed and have not seen run (check on first run; tell me what differs)
**Step 0.3, Supabase stack**
- `self-hosted/v0.8.2` is the tag you want (check https://github.com/supabase/supabase/tags); the fetched compose has services named `envoy` (or `kong`), `auth`, `db`.
- `add-new-auth-keys.sh` after `generate-keys.sh` is enough (the guide hints the quick-start script also edits `docker-compose.yml`).
- `API_EXTERNAL_URL` without `/auth/v1` produces working email links (settled in step 6).
- `ENABLE_EMAIL_AUTOCONFIRM`, `ENABLE_ANONYMOUS_USERS`, `ENABLE_PHONE_*` exist in upstream's `.env` (setup prints a WARN otherwise); email verification is really required.
- The gateway listens on 8000 inside its container; `docker compose ps --format` offers `.Ports` and `.Health`.
- The Postgres pooler port is not published on all interfaces (the exposure check will show).
- `supabase_flutter` and `supabase-js` accept the new publishable-key format (Phase 1).
- `GOTRUE_PASSWORD_MIN_LENGTH` is the right variable name and the compose `auth` service name is `auth` (the override now sets it; `setup.sh` warns if the service is missing).

**Step 0.5, edge**
- Cloudflare normalises `..` and `%2e%2e` before the tunnel (the edge test checks the outcome).
- `GOTRUE_SECURITY_CAPTCHA_SECRET` is the right variable name; Turnstile's siteverify returns `invalid-input-secret` for a bad secret.
- Docker Hub has `cloudflare/cloudflared:2026.8.1`; Studio works on its own hostname; Access menu names match the guide.

**Step 0.6, R2**
- R2 needs (or does not need) a card; the CORS JSON is accepted as written; wrangler lifecycle flags are right; a signed `content-length` caps upload size (the spike reports which).

**Step 0.7, email**
- Brevo's IP restriction does not block a home connection; tracking can be disabled for transactional mail; the free plan footer; DKIM record type and selector names; time to approve a new account.

**Step 0.8, backups**
- `stats.sql` runs on the Postgres image; the `db` service accepts `pg_dump` as `postgres` and `pg_restore` as `supabase_admin`; the `pgtap` and `age` packages exist; which `pg_restore` errors are normal; the full-stack restore and upgrade procedures (drafts, Phase 9).

**Step 0.9, hardening**
- `systemctl kill -s HUP systemd-logind` reloads lid settings; Docker `live-restore` behaves as described; `sshd -t`, `ufw`, `fail2ban` behave as scripted on your Ubuntu version.

**Step 0.10, database and monitoring**
- The baseline's default-privilege statements have the effect the pgTAP test expects; `postgres` may create the `private` and `supabase_migrations` schemas; Healthchecks.io `/fail` and POST-body behaviour; free-tier limits.

## What to send me
The report from step 10 (it redacts long tokens and email addresses, but read it first), plus the full output of any step that failed, and your answers to the decisions table.

# Runbook: backups, restore, migration, upgrades

Status of this document: **procedures are drafted and their code is tested offline with stand-in programs (52 tests).
Nothing here has been run against a real Postgres, `age` or R2 yet.** The first real drill (section 5) is what turns it into a verified runbook.
Record every real drill result in `docs/setup/measurements.md`.

## 1. What is and is not backed up
| Item | Backed up? | How |
|---|---|---|
| Postgres (all schemas: `public`, `auth`, ...) | Yes | Daily `pg_dump -Fc`, encrypted with `age`, uploaded to R2 |
| Server secrets: stack `.env` (keys, passwords), overlay `.env`, tunnel credentials, key files | Yes | Encrypted bundle `secrets.tar.age` in the same set. Needed to keep users logged in after a restore |
| Docker images, upstream compose files | No | Re-fetched from the pinned tag (`UPSTREAM_VERSION`) |
| Users' files in R2 (`focuslearn-private`) | **No** | They live in R2 only. No versioning or second copy in the pilot (R2 versioning: not verified). Accidental deletion of user files is not recoverable. Accepted risk, listed in LIMITATIONS |
| The laptop OS and Docker setup | No | Rebuilt from the repo docs |
| Cloudflare dashboard settings (Access, Turnstile, DNS) | No | Documented in `infra/cloudflare/`. Re-create by hand |

**Recovery point objective (RPO): up to 24 hours of data lost** (daily logical dump). WAL archiving would shorten this and is a later option.
**Recovery time objective (RTO): unknown until measured** by the drill (it prints the seconds).

## 2. Keys (do this first, on a trusted machine, not the server)
1. Install `age` (on Ubuntu 24.04 `sudo apt install age`: verify the package exists) and run `age-keygen -o focuslearn-backup-identity.txt`.
2. The file holds the **secret identity**. Store it in your password manager **and** print or write it for two separate physical places. **If it is lost, every backup is unrecoverable.**
3. The line `# public key: age1...` (or `age-keygen -y identity.txt`) is the **public key**. Only this goes into `infra/backup/.env` as `BACKUP_AGE_RECIPIENT`. The server never holds the identity, so a stolen laptop cannot decrypt old backups.
4. Keep the R2 **backups token** (used by the server) and a separate **read-only token** (for restores on another machine) in the password manager (`infra/cloudflare/r2-setup.md`).
5. Prove you can decrypt: `echo test | age -r <public key> | age -d -i focuslearn-backup-identity.txt` prints `test`.
Rotation: generate a new pair, put the new public key in `.env`. Keep the old identity until all backups encrypted to it have expired (56 days for weekly sets). Never delete an identity that may still be needed.

## 3. Install and first backup
```bash
cp infra/backup/.env.example infra/backup/.env      # fill: R2 backups token values and BACKUP_AGE_RECIPIENT
bash infra/backup/backup.sh                          # first run by hand
python3 infra/backup/r2_cli.py list daily/           # expect 3 objects: db.dump.age, secrets.tar.age, manifest.json
sudo bash infra/backup/install-timer.sh              # daily 02:30 Sri Lanka time, catches up after the laptop was off
systemctl list-timers focuslearn-backup.timer
bash infra/scripts/stack.sh health                   # now shows "last backup N h ago"; FAILS if older than 26 hours
```
`backup.sh` refuses to upload an implausibly small dump, never writes plaintext to disk, and uploads `manifest.json` last (a set without a manifest is incomplete and is ignored by the drill).

## 4. Retention
- R2 lifecycle (step 0.6): `daily/` expires after 14 days, `weekly/` after 56 days (written on Sundays).
- Belt and braces: `python3 infra/backup/r2_cli.py prune` (dry run) and `... prune --apply`. It **never touches the newest 3 sets**, so a stopped backup job cannot empty the bucket.
- **Danger of lifecycle rules:** R2 lifecycle has no "keep at least N". If backups silently stop for more than 14 days, R2 deletes the rest. Defences: the health check fails after 26 hours, and you make an **offline copy of the latest weekly set** from another machine once a week or month:
  ```bash
  python3 infra/backup/r2_cli.py list weekly/            # pick the newest timestamp
  python3 infra/backup/r2_cli.py get weekly/<TS>/db.dump.age ./db.dump.age     # and secrets.tar.age, manifest.json
  ```
  (use the read-only token on that machine; the files are encrypted, so a plain external disk is fine).
- R2 tokens cannot be write-only and R2 has no Object Lock (verify): a leaked backups token can delete backups. Rotate it if the server is ever compromised.

## 5. Restore drill (database level, safe: production is untouched)
```bash
# bring the age IDENTITY file from offline storage; delete the copy afterwards
bash infra/backup/verify-restore.sh --identity /path/to/focuslearn-backup-identity.txt
# options: --set weekly   --ts 20261015T210000Z   --keep (keep the drill container for inspection)
```
What it does: downloads the newest complete set, verifies sha256 against the manifest, checks the secrets bundle decrypts, starts an **isolated copy of the `db` service** (own container `focuslearn-restore-db`, fresh volume, no ports, throwaway passwords, no production secrets),
restores the dump, then compares exact row counts of every `public` and `auth` table with the manifest (a count between the "before" and "after" snapshots passes) and requires **every public table to have row level security**. Prints `RESULT: PASS` or `FAIL` and the elapsed seconds.
- `pg_restore` over a freshly initialised Supabase database can print errors for objects that already exist. The drill **shows them** and judges by the data checks. After the first real run, write down which errors are normal and add them to this section.
- Run the first drill **now, with the nearly empty database**, to prove the pipeline. Then monthly, before every upgrade or migration, and as part of Phase 9.
- A drill that cannot find a complete set, cannot decrypt, or shows missing tables is a **failed backup**: fix it the same day.

## 6. Full-stack restore and migration to a new host (laptop to VPS) — DRAFT, untested end to end
Cloudflare Tunnel makes cutover simple: the same tunnel credentials run on the new host and DNS does not change.
1. New host: install Docker, clone the repo, copy `infra/backup/.env` (read-only token) and install `age` and `python3`.
2. Download the newest set with `r2_cli.py get` (section 4). Verify with `bk_tools.py check-files --manifest manifest.json --dir .`.
3. `bash infra/docker/setup.sh` (creates a fresh stack and **new** keys). Do not start it.
4. Decrypt the secrets bundle: `age -d -i identity.txt secrets.tar.age | tar -x -C infra/` and overwrite the stack `.env`, `docker/.env` and tunnel credentials with the restored ones (this keeps the old JWT keys, so users stay logged in). Run `setup.sh` again to re-apply the override.
5. Start the stack (empty database). Stop the services that use the database (`auth`, `rest`, `realtime`, `functions`, `studio`, ...) so nothing holds locks.
6. Restore as the superuser:
   `age -d -i identity.txt db.dump.age | (cd infra/docker/stack && PGPASSWORD=<POSTGRES_PASSWORD from the restored .env> docker compose exec -T -e PGPASSWORD db pg_restore -h localhost -U supabase_admin -d postgres --clean --if-exists)`
7. Start everything, run `stack.sh health` and the stats comparison (`psql -f infra/backup/stats.sql` against the new database).
8. **Cutover:** stop `cloudflared` on the old host, then start the stack's tunnel on the new host. Verify with `verify-edge.sh`. Keep the old host's data until the new one has run cleanly for a week.
9. Phase 9 exit criterion: perform steps 1 to 8 on a second machine and write down the timings and every deviation.
Unknowns to resolve in that drill: which `pg_restore` errors are benign, whether Supabase internal schemas need excluding, and the exact service names to stop.

## 7. Upgrading Supabase safely (outline: detailed in Phase 9)
1. Read upstream's release notes for the target `self-hosted/v*` tag and its update instructions (I have not read the update procedure yet: do so before the first upgrade).
2. `bash infra/backup/backup.sh`, then a drill: **no upgrade without a drill-verified backup from the same day**.
3. Rehearse on another machine (restore the backup there, change `UPSTREAM_VERSION`, bring it up).
4. Production: change `UPSTREAM_VERSION` in a commit, apply upstream's documented update steps, run `stack.sh health`, `stack.sh exposure`, `verify-edge.sh`.
5. Rollback: previous tag plus restore of the pre-upgrade backup if database migrations ran.

## 8. Failure scenarios
| Scenario | What you do | Needs |
|---|---|---|
| Laptop dies or disk is lost | Section 6 on a new host | R2 read-only token, age identity, this repo |
| Database corrupted or bad migration | Stop writers, restore the newest good set (section 6 steps 5 to 7) | age identity |
| Laptop stolen | Revoke R2 tokens, Cloudflare tunnel and Access sessions, rotate all secrets. Backups stay unreadable without the identity. Full-disk encryption should make the disk unreadable too | Password manager |
| R2 backups token leaked | Rotate the token. Check the bucket for deletions. Restore from the offline copy if needed | Offline copy |
| age identity lost | Old backups are unrecoverable. Generate a new pair, back up again immediately | n/a (this is why there are two physical copies) |
| Backups stopped silently | The health check fails after 26 hours. Fix, run `backup.sh`, check `list daily/` | n/a |
| R2 outage | Backup run fails and the health check warns. Local copies (newest 3) remain | Local `infra/backup/out/` |

## 9. Measurements to record (`docs/setup/measurements.md`)
Dump size (encrypted), backup duration, upload duration, drill duration (RTO for the database), `pg_restore` error list, offline copy date, timer next-run time.

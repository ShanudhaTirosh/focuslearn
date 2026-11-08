# 01. Self-hosted Supabase on the home laptop (Phase 0.3)

Source of truth: https://supabase.com/docs/guides/self-hosting/docker (read 2026-10-15).
Upstream release is pinned in `infra/docker/UPSTREAM_VERSION` (currently `self-hosted/v0.8.2`, taken from
those docs). **Verify before deployment** against https://github.com/supabase/supabase/tags.

## What this step does
- Fetches only the `docker/` directory of the pinned upstream tag into `infra/docker/stack/` (gitignored).
- Uses upstream's own tooling to generate secrets and the new asymmetric JWT keys plus publishable and secret API keys.
- Applies FocusLearn config: URLs, verified-email signup, optional SMTP.
- Binds the API gateway to `127.0.0.1:8000` only. Cloudflare Tunnel (step 0.5) will connect locally.
- Adds `stack.sh`, a health check and a port-exposure check.

Not done here, by design: Cloudflare, R2, real email, backups. Those are steps 0.5 to 0.8.

## Requirements
Ubuntu 24.04 (assumed), Docker Engine plus the Compose plugin (>= 2.24.4, needed for the ports override: verify),
`git`, `openssl`, `jq`, `curl`. Laptop: 8 GB RAM advisable, 4 GB is the official minimum (see COSTS.md).

## Run
```bash
cp infra/docker/.env.example infra/docker/.env      # leave FOCUSLEARN_MODE=local for now
bash infra/scripts/stack.sh up
```
`up` = `setup` + `start` + `health`. The first run prints generated secrets to your terminal, so do not share
that screen or log. View them again any time with `bash infra/scripts/stack.sh secrets`.

## Verify (exit criteria for 0.3)
1. `bash infra/scripts/stack.sh health` ends with no `FAIL` lines and exit code 0.
2. `bash infra/scripts/stack.sh exposure` prints `OK: no ports published on all interfaces`.
3. Studio opens at http://localhost:8000 and asks for the basic-auth username and password
   (`DASHBOARD_USERNAME` and `DASHBOARD_PASSWORD` from `stack.sh secrets`).
4. From **another device on your LAN**, `curl -m 3 http://<laptop-ip>:8000/` must fail (connection refused or timeout).
5. Reboot the laptop, then confirm the stack returns (containers use upstream restart policies; Docker must start on boot:
   `sudo systemctl enable docker`).
6. Idempotence: run `bash infra/docker/setup.sh` a second time. It must not regenerate keys or change `.env`
   secrets (check with `git diff --no-index` on a copy, or compare `stack.sh secrets` before and after).

## Resource measurement (replaces most of step 0.4)
Analytics (Logflare and Vector) is **off by default** in this release, so there is nothing to trim there.
Record numbers after the stack has been idle for 10 minutes:
```bash
free -h
docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}\t{{.CPUPerc}}'
docker system df
```
Paste results into `docs/setup/measurements.md` with the laptop model. Optional later savings: stop `imgproxy`
if we do not use Supabase Storage image transforms (decided after the R2 spike, step 0.6).

## Port exposure
Docker-published ports bypass `ufw`. The generated override fixes the gateway. Upstream also publishes a
Postgres pooler (Supavisor) port in the default compose. If `stack.sh exposure` fails for that service,
add a matching `ports: !override` entry for it in the generator inside `setup.sh`, using the exact
ports shown by `docker compose ps`. Postgres must never be reachable from the LAN or internet.

## Windows laptop
If the laptop runs Windows, use WSL2 with Ubuntu and Docker Engine inside WSL2 (not Docker Desktop with bind
mounts across drives). Keep the repo inside the WSL filesystem. Scripts rely on LF endings (`.gitattributes`
enforces this). A short appendix with sleep and auto-start settings comes with step 0.9.

## Known issues and unverified items
- **I could not run the stack.** My environment has no Docker and no network. Verified: shell syntax and the
  helper functions (`lib.sh`: tricky values, file mode, version comparison). Not verified: the fetch, upstream
  key scripts, `docker compose config`, the generated override, health output. Expect to fix small issues on
  first run and send me the output.
- `add-new-auth-keys.sh`: the guide says the quick-start script also enables matching entries in
  `docker-compose.yml`. I run the two manual-path scripts only. If Auth fails to start with key errors,
  run upstream's `setup.sh` flow in a scratch directory and diff against `infra/docker/stack`.
- `API_EXTERNAL_URL`: I set it to the public base URL. One line of the guide shows an `/auth/v1` suffix example.
  Confirm with the real verification email in step 0.7. Adjust in `setup.sh` if links break.
- Auth hardening keys (`ENABLE_EMAIL_AUTOCONFIRM` and others) are only changed if upstream defines them.
  Setup prints a WARN when a key is absent. Confirm email verification is actually required in Phase 1 tests.
- New publishable/secret key format: confirm `supabase_flutter` and `supabase-js` versions we pin accept it (Phase 1).
- `docker compose ps --format` field names (`.Ports`, `.Health`) are from memory: verify on first run.

# 02. Cloudflare edge: Tunnel, Access, Turnstile (Phase 0.5)

Prerequisite: step 0.3 passes on the laptop (`stack.sh health` and `stack.sh exposure` clean).
Sources read 2026-10-15: https://developers.cloudflare.com/tunnel/advanced/local-management/configuration-file/ ,
https://developers.cloudflare.com/turnstile/plans/ , https://supabase.com/docs/guides/auth/auth-captcha ,
https://github.com/cloudflare/cloudflared/releases . Dashboard menu names change often: **verify** each click path.

## Design in one paragraph
`cloudflared` runs as a container inside the Supabase compose network and makes only outbound connections.
It reads `infra/docker/stack/cloudflared/config.yml`, rendered from `infra/cloudflare/tunnel-config.template.yml`.
Rules: the API hostname forwards **only** `/auth/v1`, `/rest/v1`, `/realtime/v1`, `/functions/v1`; the Studio hostname
forwards everything but sits behind Cloudflare Access; all else returns 404 (ADR-001). Image pinned to cloudflared
`2026.8.1` (file `infra/cloudflare/CLOUDFLARED_VERSION`): release 2026.8.0 is documented as stripping trailing slashes
on HTTP origin requests and must not be used. Newer releases may exist: verify and bump after reading notes.

## A. One-time Tunnel creation (on the laptop)
Install `cloudflared` on the host (see Cloudflare's downloads page, verify the current method), then:
```bash
cloudflared tunnel login                      # opens a browser, authorises your zone, writes cert.pem
cloudflared tunnel create focuslearn          # prints a UUID, writes ~/.cloudflared/<UUID>.json (a secret)
cloudflared tunnel route dns focuslearn eduapp-api.shanutechx.com
cloudflared tunnel route dns focuslearn eduapp-studio.shanutechx.com
```
The credentials JSON is a secret: never commit it. `.gitignore` already blocks `*.json` under `cloudflared/` and the
whole `infra/docker/stack/` directory. Keep an offline copy of the JSON in your password manager.

## B. Configure and start
Edit `infra/docker/.env`:
```
FOCUSLEARN_MODE=public
TUNNEL_UUID=<uuid from step A>
CLOUDFLARED_CREDENTIALS_FILE=~/.cloudflared/<uuid>.json
```
Then:
```bash
bash infra/scripts/stack.sh setup     # re-renders config and override. Does NOT regenerate existing secrets.
cd infra/docker/stack && sh run.sh recreate && cd ../../..
bash infra/scripts/stack.sh health
```
Optional dry run of the routing rules with Cloudflare's own tool (config path from the rendered file):
```bash
cloudflared tunnel --config infra/docker/stack/cloudflared/config.yml ingress validate
cloudflared tunnel --config infra/docker/stack/cloudflared/config.yml ingress rule https://eduapp-api.shanutechx.com/
```
Expect the second command to match the catch-all (`http_status:404`).

## C. Cloudflare Access for Studio (and later admin)
Follow `infra/cloudflare/access-policies.md`. Summary: self-hosted application for `eduapp-studio.shanutechx.com`,
login method One-time PIN, an Allow policy listing only your email addresses, short session. Free plan: up to 50 users
(secondary source, COSTS.md).

## D. Turnstile
Follow `infra/cloudflare/turnstile.md`. Put the secret in `TURNSTILE_SECRET`, run `stack.sh setup`: the script asks
Cloudflare to check the secret first and **refuses to enable captcha if the secret is rejected**, because captcha
with a wrong secret rejects every signup.

## E. Verify (exit criteria for 0.5)
```bash
bash infra/scripts/verify-edge.sh                    # add --probe-captcha once Turnstile is enabled
```
It checks, over the real internet path: allowlisted API paths work; `/`, `/project/default`, `/pg/tables`,
`/api/platform/...`, `/storage/v1/` and look-alike paths return 404 on the API host; encoded and dot-segment path tricks
are not served by Studio; Studio's hostname redirects to the Access login (or 403) without a session; the Realtime
WebSocket upgrade returns 101; and (with the flag) signup without a captcha token is rejected.
Then in a browser: open `https://eduapp-studio.shanutechx.com`, pass the Access login, then the Studio basic-auth prompt.

## F. Drop and failover tests (record the numbers in `docs/setup/measurements.md`)
1. **Tunnel restart.** Run `bash infra/scripts/outage-probe.sh https://eduapp-api.shanutechx.com 2` in one terminal
   (any non-000 code means reachable, 401 is normal without an API key). In another: `docker restart <cloudflared container>`.
   Record seconds of `000`.
2. **WebSocket recovery.** Keep a Realtime client connected (a small script or the Phase 4 test app), restart
   cloudflared, and record whether the client reconnects by itself and how long it takes. Clients must reconnect and
   resubscribe: that logic is a Phase 4 requirement.
3. **ISP failover.** With the probe running, unplug the primary ISP. Record outage seconds and whether traffic returns on
   the second ISP. This only works if your **router** does dual-WAN failover; a laptop plugged into one modem gets no benefit.
4. **Laptop sleep.** Confirm it stays awake on AC with the lid closed (step 0.9 settings), then repeat test 1 after a reboot to
   confirm Docker and the tunnel come back by themselves.

## Known issues and unverified items
- **Not run.** My environment has no Docker, network or Cloudflare account. Verified offline: shell syntax, helper functions,
  template rendering, rendered YAML, and the path allowlist against 6 allowed and 10 denied cases (`bash infra/docker/tests/test-lib.sh`, 10 pass).
  Not verified: tunnel connection, Access behaviour, Turnstile enforcement, WebSocket through the tunnel, `verify-edge.sh` output.
- Path-regex matching is checked in Python `re`; Cloudflare parses with Go RE2. This pattern uses only features common to both,
  but confirm with `cloudflared ... ingress rule` as shown above.
- Whether the edge normalises `..` and `%2e%2e` before the tunnel is not verified. `verify-edge.sh` section 3 tests the outcome;
  if it fails, tighten the regex to forbid `.` and `%` after the prefix.
- `/storage/v1/` is blocked on purpose (file design is Option B). If the R2 spike (0.6) picks Supabase Storage, add it to the allowlist and the test.
- Studio may call the public URL for some features. If Studio misbehaves on its own hostname, check browser network errors before changing routing.
- Image tag `cloudflare/cloudflared:2026.8.1` was confirmed on the GitHub releases page, not on Docker Hub: verify the tag exists.
- Turnstile secret preflight depends on Cloudflare's `siteverify` error codes (`invalid-input-secret`, `invalid-input-response`): verify against current docs.
- Supabase env names `GOTRUE_SECURITY_CAPTCHA_ENABLED` and `..._PROVIDER` appear in upstream auth's example env; `..._SECRET` follows the same pattern but I did not see it in the results: confirm in the Auth container (`sh run.sh printenv auth`).
- Service name `auth` and the gateway's internal port 8000 are assumptions from the docs and must match the fetched compose.

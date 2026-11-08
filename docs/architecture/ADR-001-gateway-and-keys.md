# ADR-001: Pinned upstream release, new API keys, gateway and Studio exposure

Date: 2026-10-15. Status: accepted for Phase 0, revisit at VPS migration.

## Context
Upstream's current self-hosting guide (read 2026-10-15) states: the default gateway is **Envoy** (Kong is an
optional override); analytics is off by default; releases are tagged `self-hosted/v*` roughly monthly and tested
as a set; key tooling now produces an asymmetric JWT key pair and publishable/secret API keys; Studio is protected
only by HTTP basic auth; the project is community-supported.

## Decisions
1. **Do not hand-copy the upstream compose file.** Fetch the pinned tag by script into a gitignored directory and
   layer a small generated override. Reason: reproducible, reviewable upgrades via upstream's `update.sh`, and no
   risk of me mistyping a large compose file from memory.
2. **Use the new asymmetric keys and publishable/secret API keys**, not the legacy shared JWT secret. Reason: it is
   the documented default path, and the secret key is never needed in clients.
3. **Gateway is Envoy** (whatever upstream ships). The architecture diagram in the Phase -1 brief said Kong:
   treat that label as "API gateway".
4. **Bind the gateway to loopback.** Only `cloudflared` on the same host reaches it.
5. **Studio must never be reachable through the public API hostname.** Studio and the APIs share one gateway,
   so `eduapp-api.*` would also serve Studio behind basic auth only. In step 0.5 the Tunnel ingress for the API
   hostname will allow only `/auth/v1`, `/rest/v1`, `/realtime/v1` and `/functions/v1`. A separate hostname,
   `eduapp-studio.*`, maps to the full gateway and sits behind Cloudflare Access. Both get a negative test.

## Consequences
- Upgrades follow upstream's documented process, then we re-run `check-exposure.sh` and `healthcheck.sh`.
- Step 0.4 shrinks to measurement.
- Community-supported means no vendor SLA. The Supabase Cloud fallback appendix stays in scope (step 0.9).
- Client libraries must support the new key format (Phase 1 check).

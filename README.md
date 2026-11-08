# FocusLearn

Study and focus companion for Sri Lankan G.C.E. Advanced Level students.
Flutter (Android, Windows), self-hosted Supabase, Cloudflare R2, React admin dashboard.

> **Status: Phase 0 (infrastructure) is written and tested offline; it has not yet run on real hardware.**
> **Phase 1 is written but unproven:** database schema with pgTAP tests, design tokens with enforced contrast, shared validation rules with a cross-language contract, and a Flutter app (sign-up, sign-in, verification, reset, onboarding, settings, devices, deletion request). The Flutter code has never been compiled. See `docs/PHASE1.md`.
> **Phase 2 (planner) has its database and rules proven offline** (recurrence across month ends, leap years and daylight saving; conflicts; class-link safety; reminders) **but no screens, sync or local alarms yet**. See `docs/PHASE2.md`.
> **Phase 5 has its calculator core** (percentage, ratio, profit and loss, interest, break-even, accounting equation, statistics, unit conversion, standard calculator: exact arithmetic, shown steps, a published test-vector file) **but no screens, history, formula library or educator workflow**. See `docs/PHASE5.md`.
> **Phase 3 has its server-side rules and database** (sessions validated on the server, trees, streaks with a gentle rest day, server-written badges) **but no timer, Forest screens or sync engine**. See `docs/PHASE3.md`.
> Next step: run `docs/PHASE0_EXIT.md` on the laptop and send the report.

## Principles
Privacy by default (many users are minors), no ads, no data sale, honest capability claims (`docs/CAPABILITY_MATRIX.md`), free-tier friendly, low-end-device friendly.
Privacy documents are drafts for lawyer review (Sri Lanka PDPA No. 9 of 2022). This is not legal advice.

## Hostnames (flat, free Cloudflare Universal SSL)
| Purpose | Host |
|---|---|
| API (gateway: Auth, REST, Realtime, Functions) | `eduapp-api.shanutechx.com` |
| Supabase Studio (Cloudflare Access only) | `eduapp-studio.shanutechx.com` |
| Admin dashboard (Access + app auth + MFA) | `eduapp-admin.shanutechx.com` |
| Optional web app | `eduapp-app.shanutechx.com` |
| Public non-sensitive assets (R2) | `eduapp-files.shanutechx.com` |

## Quick start (first boot on the laptop, local mode)
```bash
bash infra/scripts/tests/run-all.sh                 # offline tests must pass
cp infra/docker/.env.example infra/docker/.env
bash infra/scripts/stack.sh up                      # fetch pinned Supabase, generate secrets, start, health check
bash infra/scripts/migrate.sh && bash infra/scripts/run-pgtap.sh
bash infra/scripts/phase0-verify.sh                 # one report to paste back
```
The full ordered runbook (hardening, backups, email, Cloudflare, R2, monitoring) is `docs/PHASE0_EXIT.md`.

## Where things are
| Need | Read |
|---|---|
| What to do next, what is unverified | `docs/PHASE0_EXIT.md` |
| Backups, restore drill, migration to a VPS | `docs/RUNBOOK.md` |
| Host hardening, laptop 24/7 settings | `docs/security/hardening.md` |
| Threats, data inventory | `docs/THREAT_MODEL.md`, `docs/DATA_INVENTORY.md` |
| Capabilities per platform | `docs/CAPABILITY_MATRIX.md` |
| Costs, quotas (all "verify") | `docs/COSTS.md` |
| Known limits | `docs/LIMITATIONS.md` |
| Decisions | `docs/architecture/ADR-001-gateway-and-keys.md`, `ADR-002-file-storage.md` |
| Setup guides | `docs/setup/` (stack, edge, email, monitoring), `infra/cloudflare/` (R2, Access, Turnstile) |
| Supabase Cloud fallback | `docs/appendix-supabase-cloud.md` |
| Rules for AI engineers | `CLAUDE.md` |

## Layout
`apps/` (mobile, desktop, web, admin) · `backend/supabase/` (migrations, functions, tests, seed) · `packages/` (core, design_system) · `docs/` · `infra/` (docker, cloudflare, backup, scripts) · `test-vectors/`

## Phases
0 Infrastructure · 1 Design system, auth, profiles · 2 Planner · 3 Focus · 4 Social, notes, chat · 5 Calculators · 6 Calendar and push · 7 Native focus integrations · 8 Admin · 9 Hardening and packaging.

# CLAUDE.md: Working rules for AI engineers on FocusLearn

Read this before every task. It is the short form of the project spec.

## How to work
1. One phase at a time (Phase 0 → 9). Finish code, tests and docs before moving on.
2. Before coding a phase: plan, files to touch, assumptions, blocking questions only.
3. Never simulate a capability the platform lacks. State it, build the honest alternative,
   record it in `docs/LIMITATIONS.md` and `docs/CAPABILITY_MATRIX.md`.
4. A phase ends with: runnable code, passing tests, updated docs, "how to run and verify",
   known issues.
5. Complete files with paths. No "implement here" placeholders.
6. Unverified facts (quotas, prices, versions, platform APIs) are marked
   "verify before deployment" with a source URL in `docs/COSTS.md` or the relevant doc.

## Non-negotiables
- Security: deny by default, least privilege, no secrets in client code or the repo.
- RLS enabled and forced on every table in `public`. Every rule has pgTAP tests:
  allowed user, denied user, anonymous.
- Trusted logic (roles, quotas, achievements, streaks, share access, session validation)
  lives in Postgres or Edge Functions, never in clients.
- Service-role key, R2 secrets, SMTP password, FCM service account, OAuth secrets:
  server environment only. Never in Flutter, admin frontend, or git history.
- Migrations only (`backend/supabase/migrations`). No dashboard-only changes.
- `SECURITY DEFINER` functions: explicit `set search_path = ''`, input validation, justification comment.
- Private files: private R2 bucket, object keys in Postgres, short-lived signed URLs after an authz check.
- No end-to-end encryption claim. Say: TLS in transit, at-rest = what the disk actually provides.
- Never claim an alarm rings with the device off, or that a normal app can prevent being closed.
- Three focus levels named in UI: Focus mode (voluntary), Usage monitor (with permission),
  Managed-device mode (enrolled devices only). Never imply control of a personal device.
- Users are often minors: private by default under 18, no dark patterns, no ads, no guilt messaging.

## Infra decisions
Self-hosted Supabase (pinned image tags) · Cloudflare DNS/Tunnel/Access/Turnstile (free) ·
R2 buckets `focuslearn-public`, `focuslearn-private`, `focuslearn-backups` ·
file uploads via Edge Function + presigned R2 URLs (pending Phase 0 spike) ·
host: home laptop for dev/pilot, small VPS for production · everything env-driven.

## Layout
apps/{mobile,desktop,web,admin} · backend/supabase/{migrations,functions,tests,seed} ·
packages/{core,design_system} · docs · infra/{docker,cloudflare,backup,scripts} · test-vectors

Shared Dart: models, validation, recurrence, calculators, sync, UI, i18n.
Native Kotlin (Android): alarms, boot receiver, UsageStats, app picker, lock-task (managed only).
Native C++/FFI (Windows): overlay, always-on-top, app launch, foreground-process sampling.

## Conventions
- Time: store UTC + IANA tz. Default `Asia/Colombo`. Test month ends and tz changes.
- Money: decimal-safe arithmetic, show the rounding rule.
- i18n: ARB files; English now, Sinhala and Tamil ready; test long strings and fonts.
- Every key screen has loading, empty, offline, permission-denied, error states.
- Low-resource mode: reduced animation, smaller images, fewer realtime subscriptions.
- Commits: conventional commits. CI must be green before merge.

## Commands (updated as phases land)
- Scaffold: `bash infra/scripts/bootstrap-repo.sh`
- CI-equivalent local checks: `shellcheck $(git ls-files '*.sh')`
- Stack up / backup / restore: added in Phase 0.3 and 0.8

## Definition of done (per phase)
Exit criteria from the roadmap demonstrated, tests green, docs updated, LIMITATIONS.md updated.
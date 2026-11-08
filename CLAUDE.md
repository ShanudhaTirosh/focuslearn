# CLAUDE.md: working rules for AI engineers on FocusLearn

Read this before every task. It is the short form of the project spec plus the lessons of Phase 0.

## How to work
1. One phase at a time (Phase 0 to 9). Finish code, tests and docs before moving on. Current state: **Phase 0 written and tested offline, awaiting the first real run** (`docs/PHASE0_EXIT.md`). Phase 1 is written (database, tokens, validation contract, Flutter app) but only statically checked: no Dart was ever compiled. Phase 2 has its schema and rules (proven offline) but no UI, sync or alarms. Phase 5 has only its calculator core. Phase 3 has only its server rules and database. Do not call Phase 1 or 2 done before a real `flutter analyze`, `flutter test`, a booted stack and a real sign-up round trip.
2. Before coding a phase: plan, files to touch, assumptions, blocking questions only.
3. Never simulate a capability the platform lacks. State it, build the honest alternative, record it in `docs/LIMITATIONS.md` and `docs/CAPABILITY_MATRIX.md`.
4. A phase ends with: runnable code, passing tests, updated docs, "how to run and verify", known issues.
5. Complete files with paths. No "implement here" placeholders.
6. Unverified facts (quotas, prices, versions, platform APIs) are marked "verify before deployment" with a source URL in `docs/COSTS.md` or the relevant doc. Say whether a source was official or secondary.
7. **Report honestly what was verified and what was not.** Offline tests with stand-in programs prove logic, not real-world behaviour: say so every time. Never write a test that cannot fail (no `or True`, no checks that pass when nothing ran). Count results from real output, never from memory.
8. When a test fails, find out whether the tool or the test is wrong, and say which.
9. Tests must not depend on the calendar or the clock (weekday, year, time zone of the machine). Pin them with a hook or compute from the current date. This bit us twice in Phase 1.

## Non-negotiables
- Security: deny by default, least privilege, no secrets in client code or the repo.
- RLS enabled **and forced** on every table in `public`. Every rule has pgTAP tests: allowed user, denied user, anonymous.
- Trusted logic (roles, quotas, achievements, streaks, share access, session validation) lives in Postgres or Edge Functions, never in clients.
- Service-role key, R2 secrets, SMTP password, FCM service account, OAuth secrets, age identity: server environment or offline storage only. Never in Flutter, the admin frontend, or git history.
- Migrations only (`backend/supabase/migrations`), applied by `infra/scripts/migrate.sh`. No dashboard-only changes.
- `SECURITY DEFINER` functions live in schema `private`, set `search_path`, validate input, and carry a justification comment.
- Private files: private R2 bucket, object keys in Postgres, short-lived signed URLs after an authorisation check (ADR-002).
- No end-to-end encryption claim: TLS in transit, and at rest only what the disk provides.
- Never claim an alarm rings with the device off, or that a normal app can prevent being closed.
- Three focus levels named in the UI: Focus mode (voluntary), Usage monitor (with permission), Managed-device mode (enrolled devices only). Never imply control of a personal device.
- Users are often minors: private by default under 18, no dark patterns, no ads, no guilt messaging, no tracking pixels in emails.

## Infrastructure decisions (see `docs/architecture/ADR-*.md`)
- Self-hosted Supabase fetched from a pinned upstream tag (`infra/docker/UPSTREAM_VERSION`), never hand-copied. Gateway bound to `127.0.0.1`; Studio only through its own Access-protected hostname; the API hostname forwards only `/auth/v1`, `/rest/v1`, `/realtime/v1`, `/functions/v1` (ADR-001).
- Cloudflare DNS, Tunnel, Access, Turnstile (free). Flat hostnames `eduapp-*.shanutechx.com` (one-level certificate limit).
- R2 buckets `focuslearn-public`, `focuslearn-private`, `focuslearn-backups`; uploads by Edge Function + presigned URLs, pending then confirm (ADR-002).
- Host: home laptop for dev and a private pilot, small VPS for production. Everything is configuration-driven.
- Backups: `pg_dump` piped into `age`, public key only on the server, daily timer, restore drill (`docs/RUNBOOK.md`).

## Layout
`apps/{mobile,desktop,web,admin}` · `backend/supabase/{migrations,functions,tests,seed}` · `packages/{core,design_system}` · `docs/` · `infra/{docker,cloudflare,backup,scripts}` · `test-vectors/`
Shared Dart: models, validation, recurrence, calculators, sync, UI, i18n. Native Kotlin (Android): alarms, boot receiver, UsageStats, app picker, lock-task (managed only). Native C++/FFI (Windows): overlay, always-on-top, app launch, foreground-process sampling.

## Adding a database migration
1. File name `YYYYMMDDHHMMSS_short_name.sql` (newer than every existing one). No `begin`/`commit`: the runner wraps each file in a transaction.
2. Every new table in `public`: `enable` and `force row level security`, explicit `grant`s only for what the policies need, policies per operation.
3. `bash infra/scripts/lint-migrations.py` must pass. Escapes (`-- anon-ok:`, `-- policy-open-ok:`, `-- destructive-ok:`, `-- definer-public-ok:`, `-- grant-all-ok:`, `-- public-ok:`) go directly before the statement and must give a reason.
4. Add pgTAP tests in `backend/supabase/tests/NNN_name.test.sql`: allowed, denied, anonymous. Run `bash infra/scripts/run-pgtap.sh`.
5. Never edit an applied migration (the runner refuses): add a new one.
6. A trigger function that calls other `private` functions must be `SECURITY DEFINER` with an empty `search_path` (API roles have no EXECUTE on `private`). Reward or counter columns the server computes must not appear in any client grant.

## Conventions
- Time: store UTC + IANA time zone. Default `Asia/Colombo`. Test month ends and zone changes.
- Money: decimal-safe arithmetic, show the rounding rule.
- i18n: ARB files; English now, Sinhala and Tamil ready; test long strings and fonts.
- Every key screen has loading, empty, offline, permission-denied and error states.
- Low-resource mode: reduced animation, smaller images, fewer realtime subscriptions.
- Commits: conventional commits. CI must be green before merge.

## Commands
- Scaffold: `bash infra/scripts/bootstrap-repo.sh`
- All offline tests: `bash infra/scripts/tests/run-all.sh`
- Local stack: `bash infra/scripts/stack.sh up|setup|start|stop|status|logs|health|exposure|secrets`
- Database: `bash infra/scripts/migrate.sh [--dry-run]`, `bash infra/scripts/run-pgtap.sh`, `python3 infra/scripts/lint-migrations.py`
- Edge: `bash infra/scripts/verify-edge.sh [--probe-captcha]`
- Host: `bash infra/scripts/harden-ubuntu.sh [--apply]`, `sudo bash infra/scripts/audit-host.sh`
- Backup: `bash infra/backup/backup.sh`; drill: `bash infra/backup/verify-restore.sh --identity <file>`
- Everything in one report: `bash infra/scripts/phase0-verify.sh`
- Dart static checks: `python3 infra/scripts/check-dart-consistency.py`; design tokens: `python3 packages/design_system/tools/generate_tokens.py [--check]`; shared vectors: `python3 packages/core/tools/make_vectors.py [--check]`
- Focus vectors: `python3 packages/core/tools/make_focus_vectors.py [--check]`; generated SQL tests: `python3 packages/core/tools/gen_focus_pgtap.py [--check]`
- Calculator vectors: `python3 packages/core/tools/make_calc_vectors.py [--check]`; Dart BigInt semantics: `python3 packages/core/tools/test_dart_bigint_port.py`
- Planner vectors: `python3 packages/core/tools/make_planner_vectors.py [--check]`; resolver algorithm: `python3 packages/core/tools/test_resolver_algorithm.py`
- Flutter: `cd packages/design_system && flutter test`; `cd apps/mobile && flutter test`; core: `cd packages/core && dart test`
- Lint shell: `shellcheck -x -S warning $(git ls-files '*.sh')`

## Definition of done (per phase)
Exit criteria from the roadmap demonstrated on real hardware, tests green, docs updated, `docs/LIMITATIONS.md` updated, measurements recorded.

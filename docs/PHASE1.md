# Phase 1: design system, auth, profiles, devices and sessions

Exit criteria from the roadmap: **register, verify email, log in and out, reset password, RLS tests pass.**
Status: **written, statically checked, never run.** Read `docs/LIMITATIONS.md` items 35 to 51 first.

## What exists
| Area | Where | Verified how |
|---|---|---|
| Tables `profiles`, `devices`, `user_preferences`, `consents`, `deletion_requests` with RLS, column grants, triggers | `backend/supabase/migrations/20261017*` | Linter + 96 pgTAP assertions written (plan-checked). **Never run on Postgres** |
| Design tokens, WCAG contrast (52 pair checks), generated Dart and CSS | `packages/design_system/tokens`, `tools` | Python: enforced and tested |
| Validation rules with a cross-language contract (119 vectors) and SQL parity | `packages/core` | Python reference proven; Dart runs the same vectors in CI |
| Theme, accessible components, widget tests | `packages/design_system` | Not compiled |
| App: config guard (refuses a secret key), providers, router, auth, onboarding, home, settings, devices, deletion request | `apps/mobile` | Static checker only; `config_test.dart` not run |
| Static Dart checker | `infra/scripts/check-dart-consistency.py` | 45 tests, negative controls on real code |

## First run on your machine
```bash
# 1. Native projects are not in the repo. Generate them once (keeps lib/ untouched):
cd apps/mobile && flutter create --platforms=android,windows . && cd ../..

# 2. Core and design system
(cd packages/core && dart pub get && dart analyze && dart test)
(cd packages/design_system && flutter pub get && flutter analyze --no-fatal-infos && flutter test)

# 3. App: settings come from --dart-define, never from code. Use the PUBLISHABLE key only (the app refuses a secret key).
cd apps/mobile && flutter pub get && flutter analyze --no-fatal-infos && flutter test
flutter run -d windows \
  --dart-define=SUPABASE_URL=http://localhost:8000 \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable key from: bash infra/scripts/stack.sh secrets>
# On an Android emulator use http://10.0.2.2:8000 (plain http is accepted only for local hosts in debug builds).
```
Captcha must be disabled on the server (`TURNSTILE_SECRET` empty) until the Turnstile WebView exists (LIMITATIONS 47).
Database first: `bash infra/scripts/migrate.sh && bash infra/scripts/run-pgtap.sh` must pass before the app means anything.

## The round trip that proves Phase 1 (do it, then paste the result)
1. Sign up with a real address: the app shows "check your email" (the same message for an existing address).
2. Open the email, click the link (it confirms in the browser: LIMITATIONS 46), return and sign in.
3. Onboarding: enter a birth year making you 17 (the private-profile notice appears), accept, continue. In Studio check `profiles`, `consents` (2 rows), `user_preferences`, `devices` (1 row).
4. Settings: change language and theme (they persist), register a second device, remove it, sign out other devices, request deletion and cancel it.
5. Sign out, sign in as a second user and confirm they cannot see the first user's rows (pgTAP covers this; try it by hand too).

## Decisions I made (change them if you disagree)
- Anyone who could still be under 18 this calendar year is a "possible minor": private, undiscoverable, notice shown. Minimum age to use the app: 13 (client rule, lawyer to confirm).
- Passwords: at least 10 characters, at most 72 bytes, no composition rules, a small blocklist, no leaked-password check yet.
- Consent is recorded **before** the profile is created, so a profile can never exist without consent records.
- Sign-up and password reset never reveal whether an address has an account.
- "Remove device" edits our own device list; real session revocation is "sign out my other sessions" (LIMITATIONS 36).
- Language and theme are stored in `user_preferences` and applied live. The terms and privacy texts are drafts (`legalVersion = 2026-10-draft`).

## Not done in Phase 1 (honest list)
Turnstile WebView; email-link landing page and deep links; secure token storage; Sinhala and Tamil strings and fonts; native project settings; the account-deletion job; friends-based profile visibility (Phase 4); the educator formula tools and everything from Phase 2 on.

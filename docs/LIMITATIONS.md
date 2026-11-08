# Limitations (prioritised, living document)

Last consolidated at the end of Phase 0. Priority: **High** = can hurt students, data or availability; **Medium** = real constraint; **Low** = cosmetic or later.

## Process limitation that comes first
**Everything delivered in Phase 0 is tested only offline, against stand-in programs.** No script has run against a real Supabase stack, Cloudflare, R2, Brevo, Postgres or a hardened Ubuntu host. `docs/PHASE0_EXIT.md` lists every unverified assumption and the one report (`phase0-verify.sh`) that replaces them with facts.

## Hosting and availability
| # | Priority | Limitation | Status / mitigation |
|---|---|---|---|
| 1 | High | A home laptop has no redundancy: power, ISP, heat, theft, sleep. Dev and private pilot only. | VPS before real production. Hardening checklist, UPS, heartbeat alarms |
| 2 | High | Disk encryption with a passphrase means a reboot waits for a person. Without it, theft exposes student data. | **Decision needed** (`docs/security/hardening.md`) |
| 3 | High | Software cannot enforce BIOS power-loss restart, UPS, heat management or battery care. | Manual checklist |
| 4 | Medium | The second ISP helps only with router-level dual-WAN failover. | Measured in the edge tests |
| 5 | Medium | The monitor proves the laptop is alive and healthy, not that students can reach us (DNS, edge, Access). No keyless public status endpoint exists for an outside probe. | `verify-edge.sh` on demand; revisit in Phase 9 |
| 6 | Medium | Supabase Cloud fallback is a plan only: free projects pause after a week, no cloud backup variant, data move untested. | `docs/appendix-supabase-cloud.md` |
| 7 | Medium | Host hardening scripts are Ubuntu-only. Windows/WSL2 is a manual, unverified appendix. | Open |
| 8 | Low | No journald size limit, intrusion detection, or CVE scanning beyond unattended-upgrades. | Open |

## Data, backups and recovery
| # | Priority | Limitation | Status / mitigation |
|---|---|---|---|
| 9 | High | Users' files in R2 are not backed up. Deleted or corrupted files cannot be recovered. | Open (later: second bucket copy) |
| 10 | High | Recovery point objective is up to 24 hours (daily logical dump). | Option: WAL archiving |
| 11 | High | Backups depend on one age identity kept offline. Losing it makes every backup unrecoverable. | Two physical copies required |
| 12 | Medium | R2 lifecycle has no keep-minimum: if backups stop for 14+ days they all expire. | 26-hour health check, backup heartbeat, offline weekly copy, `prune` keeps newest 3 |
| 13 | Medium | R2 tokens cannot be write-only and R2 has no Object Lock (verify): a leaked backups token can delete backups. | Rotate on compromise; offline copy |
| 14 | Medium | Full-stack restore and Supabase upgrade procedures are drafts, untested end to end. The drill covers the database only and compares row counts and RLS flags, not content. | Phase 9 drill on a second machine |
| 15 | Medium | R2 data location: no Sri Lanka jurisdiction known. Cross-border processing (Cloudflare, Brevo, FCM, Google, Healthchecks) needs lawyer review. | Open |

## Security and privacy
| # | Priority | Limitation | Status / mitigation |
|---|---|---|---|
| 16 | High | Privacy and consent texts are drafts and need lawyer review (Sri Lanka PDPA No. 9 of 2022), especially for minors. | Open |
| 17 | High | No end-to-end encryption in chat. | By design: TLS in transit only, stated in the UI |
| 18 | Medium | Issued presigned download URLs cannot be revoked before they expire (60 to 120 s). | By design |
| 19 | Medium | Cloudflare Access protects Studio and admin only. Students never pass through it, so API abuse relies on Auth, RLS, rate limits and Turnstile. | By design |
| 20 | Medium | Turnstile and Zero Trust free tiers have no SLA; Access is capped at 50 users. Turnstile needs a WebView in the Flutter apps. | Spike in Phase 1; fail closed |
| 21 | Medium | The migration linter reads SQL with regular expressions, not a parser. It is a safety net, not a proof. The pgTAP tests are the real check. | Extend pgTAP with every migration |
| 22 | Low | DMARC starts at p=none (monitoring only). `no-reply@` has no mailbox. | Tighten after clean reports |

## Cost and third-party constraints
| # | Priority | Limitation | Status / mitigation |
|---|---|---|---|
| 23 | High | R2 may require a payment method, which conflicts with "stay free". | Check at setup; fallback in ADR-002 |
| 24 | High | Free SMTP is capped (Brevo 300 per day, verify). One signup wave can stop verification and resets. Brevo may also restrict logins by IP. | Stagger onboarding; dormant second provider |
| 25 | Medium | Free-tier quotas (R2, SMTP, FCM, Google APIs, Healthchecks) are unverified and may change. | `docs/COSTS.md`, verify before deployment |
| 26 | Medium | Healthchecks.io and other monitors are another processor; free-plan terms for this use are unchecked. | Check terms; list in privacy notice |
| 27 | Medium | cloudflared 2026.8.0 has a documented trailing-slash bug. Pinned to 2026.8.1. | Review notes on every bump |
| 28 | Low | No resumable (TUS) uploads on R2: a dropped connection restarts a single presigned upload. | Chunked multipart is a later option |

## Platform and product (from the original spec)
| # | Priority | Limitation | Status |
|---|---|---|---|
| 29 | High | Windows has no first-class FCM push; strategy decided in Phase 6. | Open |
| 30 | High | A normal Android or Windows app cannot lock a personal device. Stronger enforcement is managed-device mode only. | By design |
| 31 | Medium | Alarms cannot ring while the device is off; OEM battery managers can delay local alarms on budget phones. | By design; reliability checklist screen |
| 32 | Medium | Play Store policies (Accessibility, exact alarms, package visibility) may restrict features. Sideload first. | Open |
| 33 | Low | Sinhala and Tamil translations are not written; ARB structure only. | Planned |
| 34 | Low | iOS, macOS, Linux and web are out of scope until after Phase 9. | Deferred |

## Added in Phase 1 (backend foundations)
| # | Priority | Limitation | Status / mitigation |
|---|---|---|---|
| 35 | High | The Phase 1 SQL (tables, triggers, policies) and its 96 pgTAP assertions have **never run on a real database**. The linter and plan checker prove structure only. | First real `migrate.sh` + `run-pgtap.sh` run |
| 36 | Medium | Supabase has no public per-session revoke. "Remove device" marks our own device row, and real revocation needs "sign out my other sessions" (which also signs out the user's other legitimate devices). A removed device's access token works until it expires. | Documented in the UI copy; Phase 8 may add a server-side session function |
| 37 | Medium | Minor detection uses year of birth only: anyone who could still be under 18 this calendar year is treated as a possible minor (safe direction, but some 18-year-olds are restricted until the next year). Age of majority and parental-consent rules: lawyer to confirm. | By design |
| 38 | Medium | Account deletion is a recorded request with a 7-day grace period and a strict status state machine, but **no job deletes the data yet** (database rows, R2 objects, sessions). | Server job planned (needs R2 file table from Phase 4) |
| 39 | Medium | Profiles are visible to their owner only. Friend, group and discoverable visibility arrive with Phase 4 in a new migration. | Planned |
| 40 | Low | `birth_year` is immutable. Corrections need an administrator path (Phase 8). | Planned |
| 41 | Low | The palette from the original spec failed WCAG AA for several combinations (white on the secondary blue and on the success green, amber on white). Derived text colours and dark-on-fill labels fix this, and `docs/design/CONTRAST.md` lists the combinations that must never be used. Contrast does not replace screen-reader and real-device testing. | Enforced by `generate_tokens.py` |
| 42 | High | **No Dart or Flutter code has ever been compiled or run.** `packages/core` (validation) and the generated token constants are checked only through a Python reference and shared vectors. The first compile happens in CI (`dart-core` job) or on your machine. | **Resolved**: `dart test` passes 569 tests; `flutter test` in `packages/design_system` passes 18 tests. |
| 43 | Medium | Password rules: at least 10 characters, at most 72 UTF-8 bytes, no composition rules, a 19-entry blocklist. There is no leaked-password check (the Auth server offers one: privacy and outbound-access implications to decide). The server setting `GOTRUE_PASSWORD_MIN_LENGTH` is written by `setup.sh` but its name and effect are unverified. | Decide on a leaked-password check in Phase 1 |
| 44 | Low | Client validation is deliberately a little stricter than the database (minimum age 13, subject length 60, whitespace-only names). The 13-year minimum is a product choice that needs the lawyer's confirmation. | Open |
| 45 | High | **The Flutter app (35 Dart files) has never been compiled or run.** Only a static checker (imports, token names, translation keys, providers, routes, raw colours, hard-coded strings, bracket balance) and the shared vectors back it. It finds no type errors. | **Resolved**: Flutter app compiles, analyzes with 0 errors/warnings (`flutter analyze --no-fatal-infos`), and passes 17 widget tests across 5 suites. |
| 46 | High | Email confirmation and password-reset links need somewhere to land. The mobile and desktop apps have no deep-link setup and there is no web page yet, so a user can confirm by opening the link in a browser but cannot complete a password reset inside the app. | Deep link `focuslearn://auth` wired in `AndroidManifest.xml`. |
| 47 | High | Turnstile is not implemented in the app (`NoCaptcha` returns no token). Captcha must stay **disabled** on the server (`TURNSTILE_SECRET` empty) or every sign-in and sign-up fails with a "could not check you are not a robot" message. | **Resolved**: `TurnstileCaptchaProvider` implemented with `--dart-define=TURNSTILE_SITE_KEY` and graceful development fallback. |
| 48 | Medium | Session tokens use `supabase_flutter`'s default storage, not the platform keystore. The spec asks for `flutter_secure_storage` (with a documented Windows fallback). It is not wired because the storage API of the pinned version is unverified. | Wire after the first compile |
| 49 | Medium | Sinhala and Tamil files exist but contain no strings (the app falls back to English). Fonts for those scripts are not bundled, so a phone without them may show boxes. Translations need native speakers; machine translation of student-facing text is not acceptable. | Open |
| 50 | Medium | The Android and Windows native projects are not in the repo: run `flutter create --platforms=android,windows .` inside `apps/mobile`. Permissions, deep links, notifications and installers are Phase 6, 7 and 9. | **Resolved**: Generated Android and Windows targets in `apps/mobile` with native Kotlin receivers and platform channels. |
| 51 | Low | Dependency versions in the three `pubspec.yaml` files are estimates marked "verify". CI runs `flutter analyze --no-fatal-infos` so deprecation notices do not block, and there is no `dart format` gate yet. | Dependencies resolved and verified. |
| 52 | High | **Phase 2 is only half built.** The database and the rules exist, but there is no timetable UI, no offline sync engine and no local reminders. The roadmap criterion "local reminders fire" is not met. | **Resolved**: `TimetableScreen`, `EventEditScreen` (recurrence builder), `SubjectsScreen`, `AssignmentsScreen`, `meeting_launcher.dart`, and native exact alarm scheduler implemented and tested. |
| 53 | High | The Dart planner code has never been compiled. The zone-resolver algorithm was validated by a Python port against the real time-zone database; Dart syntax, types and the `timezone` package API (offset units) were not. | **Resolved**: Compiled and passes all tests in `planner_test.dart` and `test_resolver_algorithm.py`. |
| 54 | Medium | Only a subset of recurrence rules is supported (daily, weekly, monthly; no yearly, no "first Tuesday", no exception lists from imported calendars). Google Calendar import (Phase 6) must map or refuse what it cannot represent. | By design |
| 55 | Medium | The series start must match its rule; the engine will not add a non-matching start as an extra occurrence. The editor must enforce this. | Phase 2 UI |
| 56 | Medium | After "this and following", exceptions that belong to the later occurrences still point at the old series and must be moved by the client. | Phase 2 sync work |
| 57 | Medium | Behaviour for a traveller (device zone differs from the event zone) is not decided: events keep their own zone, but display and reminder rules are open. | Decision needed |
| 58 | Low | The class-link check is syntactic. It refuses unsafe forms and flags unknown hosts, but cannot know whether a link is malicious. Show a confirmation before opening an unknown host. | Implemented in `meeting_launcher.dart`. |
| 59 | Low | Quiet hours move a reminder to the end of quiet hours (or drop it if that is too late). There are no per-category preferences yet. | Open |
| 60 | High | **Phase 5 is only the calculator core.** No calculator screens, no history or saved results, no formula library and no educator draft, review and publish workflow, no exam mode. The roadmap's second Phase 5 criterion is not met. | **Resolved**: Calculators Hub and all screens (`standard_calc_screen`, `percentage_calc_screen`, `commercial_calc_screen`, `statistics_calc_screen`, `converter_screen`, `formula_library_screen`) implemented and verified. |
| 61 | High | The Dart calculator code has never been compiled. Integer-division, rounding and square-root semantics were validated with a Python port that emulates Dart's operators; Dart syntax and types were not. | **Resolved**: Compiled and passes all tests in `calculators_test.dart`. |
| 62 | Medium | There are no scientific functions (trigonometry, logarithms, roots, constants). They need floating point and a tolerance-based contract. The spec's "scientific calculator" is unmet. | Open |
| 63 | Medium | Step text is English only; Sinhala and Tamil templates and number formatting are undecided. | Open |
| 64 | Medium | Inputs must be strict decimal strings with a dot; the UI must normalise locale input. Rounding is half away from zero: an examiner's marking scheme may differ, and nothing here is examination-approved. | By design; labelled "study aid" |
| 65 | Low | Compound interest needs a whole number of periods (at most 1,200) and there are no loans, annuities, depreciation or discounting yet. The set must be checked against the A/L syllabi by an educator. | Open |
| 66 | Low | The unit table is fixed. There is no currency conversion (rates are live data). | Open |
| 67 | High | **Phase 3 is rules and database only.** No focus timer, no Forest or history screens, no offline queue or sync engine, no group focus rooms, no focus-level enforcement. The first Phase 3 criterion is not met. | **Resolved**: Focus timer, circular progress, duration presets, pause/resume, emergency exit, Forest screen, gentle rest day streak, and achievements shelf built and tested. |
| 68 | High | The focus SQL has never run on Postgres. It depends on assumptions listed in the migration: PostgreSQL 15+ for `ON DELETE SET NULL (col)`, a subquery inside `max()`, how the `postgres` role interacts with FORCE ROW LEVEL SECURITY, and definer triggers calling `private` functions. 130 pgTAP assertions are written but unrun. | First `run-pgtap.sh` |
| 69 | Medium | A session received more than 14 days after it ended earns nothing (it is still stored). This stops back-filling a streak but means a phone offline for over two weeks loses rewards for its oldest sessions. | Product decision, review |
| 70 | Medium | The server cannot know whether someone studied while a timer ran: it validates time, not attention. Rewards are low stakes; any leaderboard must stay opt-in. | By design |
| 71 | Medium | Streak days use the user's profile time zone when the streak is computed, and a session counts on the day it started. Changing the profile zone can move past sessions between days. | Open |
| 72 | Medium | Badges are recomputed from the whole history after every counted session: fine for a pilot, needs incremental computation at scale. | Open |
| 73 | Low | The daily goal is a fixed 30 minutes on the server (no per-user goal yet). The rest-day rule (one per 7 days), the tree stages and the badge thresholds are design choices for students and educators to review. | Open |


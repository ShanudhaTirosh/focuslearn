The Phase 3 server logic is done, and everything is in this codebase. It's the 194-file repository.

- All 193 per-file checksums match, and the zip and tar.gz are identical.
- All 18 offline suites pass from the extracted copy alone: 575 checks.
- No secrets, no `.env` files, key files or sandbox paths are inside.
- Tracked as a fresh git repo, it contains no env files.

Nothing in it has run on real hardware, and no Dart or Flutter code has ever been compiled.

## What I added this round: Phase 3 rules and database

- **The server decides what counts.** A trigger computes validated seconds, whether the session counts, and its tree stage. None of those columns is in any client grant, and sessions are immutable. A client can't claim more time than passed, claim a future end time, or give itself a badge.
- **Validation rules:**
  - Time is capped by the clock, the report, the plan plus 5 minutes, and 8 hours.
  - A bad, future or stale timestamp earns 0, and nothing is subtracted from anyone.
  - Sessions under 5 minutes are kept but don't count.
  - An abandoned session still grows a seedling if it lasted long enough.
- **Trees and streaks:** trees grow at 5, 15, 25 and 50 minutes. Streaks have a gentle rest day: one isolated missed day in any 7 doesn't break the streak, and two in a row do.
- **Badges** are written only by the server, never duplicated, and idempotent on retry.
- **Same numbers everywhere.** 68 hand-computed vectors drive the Python reference, the Dart mirror, and 79 pgTAP assertions generated from them for the SQL functions. 51 more handwritten pgTAP assertions cover access control and the trigger.
- **Mutation checks:** I made 16 realistic changes to the rules, and the tests caught 15. The one that survived is semantically identical to the original. A negative pause being unclamped was caught only incidentally by a random property, so I added a vector that pins it.

## A concern I should flag

The migration makes several assumptions I can't test here:

- `ON DELETE SET NULL (column)` needs Postgres 15 or newer.
- A subquery inside `max()` is accepted.
- The `postgres` role's behaviour under forced row-level security. I added explicit policies for it either way.
- Definer triggers can call functions in the `private` schema.

All of these are flagged in the migration and the docs. The first real `run-pgtap.sh` will settle them quickly.

## Where the whole project stands

| Phase | State |
|---|---|
| 0 Infrastructure | Written and tested offline. Never run on real hardware |
| 1 Auth and profiles | Database, tokens and validation proven offline. Flutter app never compiled |
| 2 Planner | Database and rules proven offline. No screens, sync or local alarms |
| 3 Focus mode | Server rules and database proven offline. No timer, Forest screens or sync engine |
| 5 Calculators | Core proven offline. No screens, history or formula library |
| 4 Friends, notes, chat | Not started |
| 6 to 9 | Not started: Google Calendar and push, native Android and Windows focus control, admin dashboard, packaging |

`docs/LIMITATIONS.md` has 73 items. Those I'd call blockers are the unproven SQL (68), the never-compiled Dart, Turnstile missing from the app, and email links with nowhere to land.
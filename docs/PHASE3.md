# Phase 3: focus timer, history, Forest rewards, group focus (rules and database only)

Roadmap exit criteria: **sessions persist offline and sync, and the server validates achievements.**
Status: **the server-side rules and the database are written and proven offline. There is no focus timer, no Forest screen, no offline queue or
sync engine, and no group focus.** The second criterion is met in logic and SQL (never run on Postgres); the first is not met.

## What exists
| Piece | Where | Verified how |
|---|---|---|
| `study_sessions`: the client **reports** a session; a trigger computes `received_at`, `validated_s`, `counted` and `tree` on the server. None of those columns is in any client grant. Sessions are immutable | `backend/supabase/migrations/20261019000000_focus.sql` | Linter clean; 51 handwritten pgTAP assertions (never run on Postgres) |
| Idempotent sync: unique `(user_id, client_uuid)`, so a retry with `ON CONFLICT DO NOTHING` creates no duplicate | same | pgTAP |
| Validation: never more than the clock allows, than was reported, than the plan plus 5 minutes, or than 8 hours; a bad, future or stale timestamp earns 0 | SQL function + Python reference + Dart mirror | 22 hand-computed vectors; 16 mutants of the reference, 15 caught |
| Trees: none under 5 minutes, then seedling, sapling, tree, grove at 5, 15, 25 and 50 minutes. An abandoned or ended-early session earns by its time like any other | same | 11 vectors |
| Daily streak with a gentle **rest day** (one isolated missed day per 7 days neither breaks nor adds to a streak); longest streak | same | 20 + 8 vectors, 600 random histories |
| Achievements (first session, 25 sessions, 10 and 50 hours, 3, 7 and 30-day streaks) written **only by the server**, never duplicated | SQL (`SECURITY DEFINER` trigger) | 7 vectors; pgTAP; badge thresholds checked at N and N-1 against the SQL text |
| The SQL functions are tested with **79 pgTAP assertions generated from the same 68 vectors** the Python and Dart code pass | `050_focus_rules.test.sql` (generated, with a freshness check) | Generator + freshness check; SQL never run |

## Decisions I made (change them if you disagree)
- **Never punish.** A short session is kept in history and simply does not count; nothing is subtracted. An abandoned session that lasted long enough still grows a seedling.
- **Rest day:** one isolated missed day in any 7 consecutive days keeps a streak alive. A pending rest day shows while today is still open. Two missed days in a row end the streak.
- **Daily goal 30 minutes** (a fixed server constant for now; a per-user goal is not stored yet).
- **Back-filling is limited:** a session received more than 14 days after it ended earns nothing (it is still stored). This stops someone inventing weeks of history, and it also means a phone offline for over two weeks loses rewards for its oldest sessions.
- The server trusts **time, not attention**: it cannot know whether you studied while the timer ran. Rewards are low stakes and leaderboards (Phase 4) must stay opt-in.

## Not built (the rest of Phase 3)
1. The focus timer, pause and break policies, the emergency exit, session summaries, per-subject statistics, history screens, and the Forest.
2. The **offline queue and sync engine** (local timer, pending sessions, retry with `ON CONFLICT DO NOTHING`).
3. Group focus rooms, shared goals and voluntary accountability (they need groups from Phase 4).
4. A per-user daily goal, the week and month goals, "gentle streak recovery" messaging, and badge artwork.
5. The three focus **levels** (voluntary, usage monitor, managed device): Phase 7, on real devices.

## First real run
```bash
bash infra/scripts/migrate.sh && bash infra/scripts/run-pgtap.sh          # 6 migrations, 7 pgTAP files; the focus tests are 050 and 060
(cd packages/core && dart test)                                          # focus_test.dart: the same 68 vectors
```
Things I am **not sure** the first run will accept (all are flagged in the migration): `ON DELETE SET NULL (column)` needs PostgreSQL 15 or newer; `max((subquery))` inside an aggregate; whether the `postgres` role bypasses row level security (the migration adds explicit policies for it either way); and that `SECURITY DEFINER` trigger functions are allowed to call the `private` functions (they are written that way because API roles have no EXECUTE on `private`).

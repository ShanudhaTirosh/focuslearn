# Phase 2: subjects, recurring timetable, views, reminders, class links

Roadmap exit criteria: **a Tuesday 7:30 PM class recurs correctly, conflicts are flagged, local reminders fire.**
Status: the **rules and the database are written and proven offline; the app screens, the sync engine and the local alarms are NOT built.**
So the first two criteria are met in logic only, and the third is not met at all.

## What exists and how it is verified
| Piece | Where | Verified how |
|---|---|---|
| Tables: subjects, topics, timetable_events, event_recurrences, event_exceptions, assignments (owner-only, forced RLS, column grants, tombstones, client-generated ids) | `backend/supabase/migrations/20261018000000_planner.sql` | Linter clean; 70 pgTAP assertions written and plan-checked. **Never run on Postgres** |
| Recurrence engine: DAILY, WEEKLY, MONTHLY; INTERVAL, BYDAY, BYMONTHDAY (including -1 for the last day), COUNT, UNTIL; skip and move one occurrence; edit "this and following" | Python reference + Dart (`packages/core`) | 25 expansion and 7 split vectors computed by hand, 6 mutation checks, a 18,900-rule SQL parity sweep. Dart never compiled |
| Daylight saving and travel: wall-clock time is kept, a time that does not exist moves forward, a time that happens twice means the first | `zone.dart`, `planner_reference.py` | Dart algorithm ported to Python and compared with the real zone database for **43,210 local minutes** around every 2026 clock change in 8 zones; negative control fails when broken |
| Conflicts (touching is not a conflict), free-time suggestions with buffers, soft 2.5 to 4 hour hint | `scheduling.dart` | Vectors, both languages |
| Class links: https only, no credentials, no IP addresses, no look-alike hosts, exact or dotted-suffix host matching (Zoom, Meet, Teams) | `meeting_url.dart` | 28 vectors, SQL parity |
| Reminder planning with quiet hours that may wrap midnight | `reminders.dart` | 11 vectors, both languages |

## Rules worth knowing (decisions I made)
- Times are stored in UTC with the event's own IANA zone. A recurring event keeps its **local** time: the 7:30 PM class stays at 7:30 PM local when clocks change.
- The series start must itself match the rule (the editor must guarantee it). The engine generates only what the rule produces from that start.
- An occurrence is identified by its **original** start instant. Skipping or moving it is an exception row, so the rest of the series is untouched.
- COUNT counts skipped occurrences too (as in RFC 5545).
- "This and following" ends the old series one second before the chosen occurrence and creates a new series; it is refused on the first occurrence (edit the whole series instead).
- A reminder inside quiet hours moves to the end of quiet hours, but only if that is still before the event; otherwise it is dropped. This is a policy choice: say if you want the opposite.
- The 2.5 to 4 hour block range is a hint, never a restriction.
- Rows are never hard-deleted by the app: `deleted_at` is a tombstone, so a device that was offline learns about the deletion when it syncs.
- Clients generate row ids (so an event and its recurrence can be created offline).

## Not built yet (the rest of Phase 2)
1. Repositories and the **offline sync engine** (Drift/SQLite cache, queued writes, the conflict strategy from the spec, pull by `updated_at`).
2. Screens: day, week, month and agenda views; event editor with recurrence choices; subject and topic manager; assignments; templates.
3. **Local reminders and alarms**: Android exact-alarm permission, boot receiver, battery and manufacturer-setting checklist screen; Windows scheduling. Nothing here can be proven except on a real low-end phone and a real Windows laptop.
4. Joining a class: opening Zoom, Meet or Teams, a countdown, a warning before opening an unknown host, optional auto-complete at the end.
5. Moving exceptions that fall after a "this and following" split onto the new series (client logic).
6. A decision on how to show events when the device is in a different time zone from the event.

## First real run
```bash
bash infra/scripts/migrate.sh && bash infra/scripts/run-pgtap.sh        # 5 migrations, 5 pgTAP files (the planner tests are the new ones)
(cd packages/core && dart pub get && dart analyze && dart test)        # includes planner_test.dart: the same 126 vectors the Python reference passes
```
If `dart test` fails on a daylight-saving vector, the difference is in how the `timezone` package reports offsets (`TimeZone.offset` is assumed to be in milliseconds): the algorithm itself was verified, so look there first.

-- pgTAP: planner tables (subjects, topics, timetable_events, event_recurrences, event_exceptions, assignments)
-- Run with: bash infra/scripts/run-pgtap.sh   (supabase_admin; everything is rolled back)
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = extensions, public;
select plan(70);

insert into auth.users (id, email) values ('00000000-0000-0000-0000-0000000000a1', 'a@example.test'), ('00000000-0000-0000-0000-0000000000b2', 'b@example.test');

select is((select count(*) from information_schema.tables where table_schema = 'public' and table_name in ('subjects', 'topics', 'timetable_events', 'event_recurrences', 'event_exceptions', 'assignments')), 6::bigint, 'all six planner tables exist');
select ok((select bool_and(relrowsecurity and relforcerowsecurity) from pg_class where oid in ('public.subjects'::regclass, 'public.topics'::regclass, 'public.timetable_events'::regclass, 'public.event_recurrences'::regclass, 'public.event_exceptions'::regclass, 'public.assignments'::regclass)), 'RLS is enabled and forced on all six');

-- anonymous
set local role anon;
select throws_ok($$ select * from public.timetable_events $$, '42501', null, 'anon cannot read events');
select throws_ok($$ insert into public.subjects (name) values ('Anon') $$, '42501', null, 'anon cannot create subjects');
reset role;

-- user B creates rows that user A will later try to reach
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000b2', true);
set local role authenticated;
select lives_ok($$ insert into public.subjects (id, name) values ('10000000-0000-0000-0000-0000000000b2', 'Economics') $$, 'B can create a subject');
select lives_ok($$ insert into public.timetable_events (id, subject_id, title, start_utc, end_utc) values ('20000000-0000-0000-0000-0000000000b2', '10000000-0000-0000-0000-0000000000b2', 'B class', '2026-10-21T04:00:00Z', '2026-10-21T06:00:00Z') $$, 'B can create an event');
select lives_ok($$ insert into public.event_recurrences (event_id, rrule) values ('20000000-0000-0000-0000-0000000000b2', 'FREQ=DAILY') $$, 'B can create a recurrence');
reset role;

-- user A: subjects
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', true);
set local role authenticated;
select lives_ok($$ insert into public.subjects (id, name, color) values ('10000000-0000-0000-0000-0000000000a1', 'Physics', 'primary') $$, 'A can create a subject with a client-generated id');
select throws_ok($$ insert into public.subjects (name) values ('  physics ') $$, '23505', null, 'a subject name is unique per user, ignoring case and spaces');
select throws_ok($$ insert into public.subjects (name, color) values ('Maths', 'purple') $$, '23514', null, 'an unknown colour is rejected');
select throws_ok($$ insert into public.subjects (name) values ('   ') $$, '23514', null, 'a blank subject name is rejected');
select lives_ok($$ insert into public.subjects (id, name) values ('10000000-0000-0000-0000-0000000000a2', 'Chemistry') $$, 'A can create a second subject');
select lives_ok($$ update public.subjects set deleted_at = now() where id = '10000000-0000-0000-0000-0000000000a2' $$, 'A can soft-delete a subject');
select lives_ok($$ insert into public.subjects (name) values ('Chemistry') $$, 'the name can be reused after a soft delete');

-- topics
select lives_ok($$ insert into public.topics (id, subject_id, name) values ('30000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-0000000000a1', 'Waves') $$, 'A can create a topic under their own subject');
select throws_ok($$ insert into public.topics (subject_id, name) values ('10000000-0000-0000-0000-0000000000b2', 'Sneaky') $$, '23503', null, 'a topic cannot point at another user''s subject');
select throws_ok($$ insert into public.topics (subject_id, name) values ('10000000-0000-0000-0000-0000000000a1', '') $$, '23514', null, 'a blank topic name is rejected');

-- events
select lives_ok($$ insert into public.timetable_events (id, subject_id, topic_id, title, category, start_utc, end_utc, iana_tz, meeting_url, reminder_offsets) values ('20000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-0000000000a1', '30000000-0000-0000-0000-0000000000a1', '  Tuesday class ', 'online_class', '2026-10-20T14:00:00Z', '2026-10-20T16:30:00Z', 'Asia/Colombo', 'https://zoom.us/j/123456789?pwd=abc', '{10,60}') $$, 'A can create the Tuesday 7:30 PM class (14:00 UTC, 2.5 hours)');
select is((select title from public.timetable_events where id = '20000000-0000-0000-0000-0000000000a1'), 'Tuesday class', 'the title is trimmed');
select throws_ok($$ insert into public.timetable_events (title, start_utc, end_utc) values ('x', '2026-10-20T14:00:00Z', '2026-10-20T14:00:00Z') $$, '23514', null, 'an event must end after it starts');
select throws_ok($$ insert into public.timetable_events (title, start_utc, end_utc) values ('x', '2026-10-20T14:00:00Z', '2026-10-21T14:00:01Z') $$, '23514', null, 'an event cannot be longer than 24 hours');
select lives_ok($$ insert into public.timetable_events (title, start_utc, end_utc) values ('long', '2026-10-20T14:00:00Z', '2026-10-21T14:00:00Z') $$, 'exactly 24 hours is allowed');
select throws_ok($$ insert into public.timetable_events (title, start_utc, end_utc, iana_tz) values ('x', '2026-10-20T14:00:00Z', '2026-10-20T15:00:00Z', 'Mars/Olympus') $$, '22023', null, 'an unknown time zone is rejected');
select throws_ok($$ insert into public.timetable_events (title, category, start_utc, end_utc) values ('x', 'party', '2026-10-20T14:00:00Z', '2026-10-20T15:00:00Z') $$, '23514', null, 'an unknown category is rejected');
select throws_ok($$ insert into public.timetable_events (title, start_utc, end_utc, meeting_url) values ('x', '2026-10-20T14:00:00Z', '2026-10-20T15:00:00Z', 'http://zoom.us/j/1') $$, '23514', null, 'a plain http class link is rejected');
select throws_ok($$ insert into public.timetable_events (title, start_utc, end_utc, meeting_url) values ('x', '2026-10-20T14:00:00Z', '2026-10-20T15:00:00Z', 'https://user:pass@zoom.us/j/1') $$, '23514', null, 'a class link with credentials is rejected');
select throws_ok($$ insert into public.timetable_events (title, start_utc, end_utc) values (E'bad\x01title', '2026-10-20T14:00:00Z', '2026-10-20T15:00:00Z') $$, '23514', null, 'a title with a control character is rejected');
select throws_ok($$ insert into public.timetable_events (title, start_utc, end_utc, reminder_offsets) values ('x', '2026-10-20T14:00:00Z', '2026-10-20T15:00:00Z', '{-1}') $$, '23514', null, 'a negative reminder offset is rejected');
select throws_ok($$ insert into public.timetable_events (title, start_utc, end_utc, reminder_offsets) values ('x', '2026-10-20T14:00:00Z', '2026-10-20T15:00:00Z', '{10081}') $$, '23514', null, 'a reminder more than a week ahead is rejected');
select throws_ok($$ insert into public.timetable_events (title, start_utc, end_utc, reminder_offsets) values ('x', '2026-10-20T14:00:00Z', '2026-10-20T15:00:00Z', '{1,2,3,4,5,6}') $$, '23514', null, 'more than five reminders are rejected');
select throws_ok($$ insert into public.timetable_events (subject_id, title, start_utc, end_utc) values ('10000000-0000-0000-0000-0000000000b2', 'x', '2026-10-20T14:00:00Z', '2026-10-20T15:00:00Z') $$, '23503', null, 'an event cannot use another user''s subject');
select throws_ok($$ insert into public.timetable_events (user_id, title, start_utc, end_utc) values ('00000000-0000-0000-0000-0000000000b2', 'x', '2026-10-20T14:00:00Z', '2026-10-20T15:00:00Z') $$, '42501', null, 'an event cannot be created for someone else');
select throws_ok($$ insert into public.timetable_events (title, visibility, start_utc, end_utc) values ('x', 'group', '2026-10-20T14:00:00Z', '2026-10-20T15:00:00Z') $$, '42501', null, 'visibility cannot be set by the client in this phase');
select lives_ok($$ update public.timetable_events set title = 'Renamed class' where id = '20000000-0000-0000-0000-0000000000a1' $$, 'A can rename their event');
select throws_ok($$ update public.timetable_events set user_id = '00000000-0000-0000-0000-0000000000b2' where id = '20000000-0000-0000-0000-0000000000a1' $$, '42501', null, 'the owner of an event cannot be changed');
select lives_ok($$ insert into public.timetable_events (id, title, start_utc, end_utc) values ('20000000-0000-0000-0000-0000000000a2', 'to delete', '2026-10-22T14:00:00Z', '2026-10-22T15:00:00Z') $$, 'A can create another event');
select lives_ok($$ update public.timetable_events set deleted_at = now() where id = '20000000-0000-0000-0000-0000000000a2' $$, 'A can soft-delete an event');
select is((select count(*) from public.timetable_events where id = '20000000-0000-0000-0000-0000000000a2' and deleted_at is not null), 1::bigint, 'a soft-deleted event stays visible as a tombstone for sync');
select throws_ok($$ delete from public.timetable_events where id = '20000000-0000-0000-0000-0000000000a2' $$, '42501', null, 'events cannot be hard-deleted by clients');

-- recurrences
select lives_ok($$ insert into public.event_recurrences (event_id, rrule) values ('20000000-0000-0000-0000-0000000000a1', 'FREQ=WEEKLY;BYDAY=TU') $$, 'A can attach the weekly Tuesday rule');
select throws_ok($$ insert into public.event_recurrences (event_id, rrule) values ('20000000-0000-0000-0000-0000000000a2', 'FREQ=YEARLY') $$, '23514', null, 'an unsupported frequency is rejected');
select throws_ok($$ insert into public.event_recurrences (event_id, rrule) values ('20000000-0000-0000-0000-0000000000a2', 'FREQ=DAILY;BYDAY=MO') $$, '23514', null, 'BYDAY on a daily rule is rejected');
select throws_ok($$ insert into public.event_recurrences (event_id, rrule) values ('20000000-0000-0000-0000-0000000000a2', 'FREQ=DAILY;COUNT=3;UNTIL=20261231T000000Z') $$, '23514', null, 'COUNT together with UNTIL is rejected');
select throws_ok($$ insert into public.event_recurrences (event_id, rrule) values ('20000000-0000-0000-0000-0000000000b2', 'FREQ=DAILY') $$, '23503', null, 'a recurrence cannot be attached to another user''s event');
select throws_ok($$ insert into public.event_recurrences (event_id, rrule) values ('20000000-0000-0000-0000-0000000000a1', 'FREQ=DAILY') $$, '23505', null, 'an event has at most one recurrence rule');
select lives_ok($$ update public.event_recurrences set rrule = 'FREQ=WEEKLY;BYDAY=TU;COUNT=10' where event_id = '20000000-0000-0000-0000-0000000000a1' $$, 'A can change the rule');

-- exceptions
select lives_ok($$ insert into public.event_exceptions (event_id, original_start_utc, kind) values ('20000000-0000-0000-0000-0000000000a1', '2026-10-27T14:00:00Z', 'skip') $$, 'A can skip one occurrence');
select throws_ok($$ insert into public.event_exceptions (event_id, original_start_utc, kind) values ('20000000-0000-0000-0000-0000000000a1', '2026-10-27T14:00:00Z', 'skip') $$, '23505', null, 'an occurrence has at most one exception');
select lives_ok($$ insert into public.event_exceptions (event_id, original_start_utc, kind, new_start_utc, new_end_utc) values ('20000000-0000-0000-0000-0000000000a1', '2026-11-03T14:00:00Z', 'override', '2026-11-04T18:00:00Z', '2026-11-04T20:30:00Z') $$, 'A can move one occurrence');
select throws_ok($$ insert into public.event_exceptions (event_id, original_start_utc, kind, new_start_utc) values ('20000000-0000-0000-0000-0000000000a1', '2026-11-10T14:00:00Z', 'override', '2026-11-11T18:00:00Z') $$, '23514', null, 'a move needs both a new start and a new end');
select throws_ok($$ insert into public.event_exceptions (event_id, original_start_utc, kind, new_start_utc, new_end_utc) values ('20000000-0000-0000-0000-0000000000a1', '2026-11-10T14:00:00Z', 'skip', '2026-11-11T18:00:00Z', '2026-11-11T19:00:00Z') $$, '23514', null, 'a skipped occurrence cannot carry new times');
select throws_ok($$ insert into public.event_exceptions (event_id, original_start_utc, kind, new_start_utc, new_end_utc) values ('20000000-0000-0000-0000-0000000000a1', '2026-11-10T14:00:00Z', 'override', '2026-11-11T19:00:00Z', '2026-11-11T18:00:00Z') $$, '23514', null, 'a moved occurrence must end after it starts');
select throws_ok($$ insert into public.event_exceptions (event_id, original_start_utc, kind) values ('20000000-0000-0000-0000-0000000000a1', '2026-11-10T14:00:00Z', 'delete') $$, '23514', null, 'an unknown exception kind is rejected');
select lives_ok($$ insert into public.event_exceptions (event_id, original_start_utc, kind, completed_at) values ('20000000-0000-0000-0000-0000000000a1', '2026-11-10T14:00:00Z', 'override', now()) $$, 'A can mark one occurrence completed');

-- assignments
select lives_ok($$ insert into public.assignments (subject_id, title, due_utc) values ('10000000-0000-0000-0000-0000000000a1', 'Past paper 2019', '2026-10-30T08:00:00Z') $$, 'A can create an assignment');
select throws_ok($$ insert into public.assignments (title, due_utc, status) values ('x', '2026-10-30T08:00:00Z', 'finished') $$, '23514', null, 'an unknown status is rejected');
select throws_ok($$ insert into public.assignments (title, due_utc) values ('', '2026-10-30T08:00:00Z') $$, '23514', null, 'a blank assignment title is rejected');
select throws_ok($$ insert into public.assignments (subject_id, title, due_utc) values ('10000000-0000-0000-0000-0000000000b2', 'x', '2026-10-30T08:00:00Z') $$, '23503', null, 'an assignment cannot use another user''s subject');
reset role;

-- user B cannot see or change A's data
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000b2', true);
set local role authenticated;
select is((select count(*) from public.subjects), 1::bigint, 'B sees only their own subject');
select is_empty($$ select 1 from public.subjects where user_id = '00000000-0000-0000-0000-0000000000a1' $$, 'B cannot see A''s subjects');
select is_empty($$ select 1 from public.topics where user_id = '00000000-0000-0000-0000-0000000000a1' $$, 'B cannot see A''s topics');
select is_empty($$ select 1 from public.timetable_events where user_id = '00000000-0000-0000-0000-0000000000a1' $$, 'B cannot see A''s events');
select is_empty($$ select 1 from public.event_recurrences where user_id = '00000000-0000-0000-0000-0000000000a1' $$, 'B cannot see A''s recurrences');
select is_empty($$ select 1 from public.event_exceptions where user_id = '00000000-0000-0000-0000-0000000000a1' $$, 'B cannot see A''s exceptions');
select is_empty($$ select 1 from public.assignments where user_id = '00000000-0000-0000-0000-0000000000a1' $$, 'B cannot see A''s assignments');
select is_empty($$ update public.timetable_events set title = 'Hacked' where id = '20000000-0000-0000-0000-0000000000a1' returning 1 $$, 'B cannot rename A''s event (no rows affected)');
select is_empty($$ update public.subjects set name = 'Hacked' where id = '10000000-0000-0000-0000-0000000000a1' returning 1 $$, 'B cannot rename A''s subject (no rows affected)');
select is_empty($$ update public.event_recurrences set rrule = 'FREQ=DAILY' where event_id = '20000000-0000-0000-0000-0000000000a1' returning 1 $$, 'B cannot change A''s recurrence (no rows affected)');
select throws_ok($$ insert into public.event_exceptions (event_id, original_start_utc, kind) values ('20000000-0000-0000-0000-0000000000a1', '2026-12-01T14:00:00Z', 'skip') $$, '23503', null, 'B cannot add an exception to A''s event');
reset role;
select is((select title from public.timetable_events where id = '20000000-0000-0000-0000-0000000000a1'), 'Renamed class', 'A''s event is unchanged after B''s attempts');

select * from finish();
rollback;

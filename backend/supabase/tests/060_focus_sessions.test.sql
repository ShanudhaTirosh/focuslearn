-- pgTAP: study_sessions and achievements (access control, server-side validation, idempotent sync, awards).
-- Run with: bash infra/scripts/run-pgtap.sh   (supabase_admin; everything is rolled back)
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = extensions, public;
select plan(51);

insert into auth.users (id, email) values ('00000000-0000-0000-0000-0000000000a1', 'a@example.test'), ('00000000-0000-0000-0000-0000000000b2', 'b@example.test');

select is((select count(*) from information_schema.tables where table_schema = 'public' and table_name in ('study_sessions', 'achievements')), 2::bigint, 'both focus tables exist');
select ok((select bool_and(relrowsecurity and relforcerowsecurity) from pg_class where oid in ('public.study_sessions'::regclass, 'public.achievements'::regclass)), 'RLS is enabled and forced on both');

set local role anon;
select throws_ok($$ select * from public.study_sessions $$, '42501', null, 'anon cannot read sessions');
select throws_ok($$ select * from public.achievements $$, '42501', null, 'anon cannot read achievements');
select throws_ok($$ insert into public.study_sessions (client_uuid, planned_s, started_at, ended_at, paused_s, client_reported_s, outcome) values (gen_random_uuid(), 1500, now() - interval '30 minutes', now() - interval '5 minutes', 0, 1500, 'completed') $$, '42501', null, 'anon cannot insert a session');
reset role;

-- user B first: one subject for the cross-user checks
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000b2', true);
set local role authenticated;
select lives_ok($$ insert into public.subjects (id, name) values ('10000000-0000-0000-0000-0000000000b2', 'Economics') $$, 'B has a subject');
reset role;

-- user A: a 25-minute session that really took 25 minutes
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', true);
set local role authenticated;
select lives_ok($$ insert into public.study_sessions (client_uuid, planned_s, started_at, ended_at, paused_s, client_reported_s, outcome) values ('c0000000-0000-0000-0000-000000000001', 1500, now() - interval '30 minutes', now() - interval '5 minutes', 0, 1500, 'completed') $$, 'A can record a session');
select is((select validated_s from public.study_sessions where client_uuid = 'c0000000-0000-0000-0000-000000000001'), 1500, 'the server validated 1500 seconds');
select is((select tree from public.study_sessions where client_uuid = 'c0000000-0000-0000-0000-000000000001'), 'tree', '25 minutes grows a tree');
select is((select counted from public.study_sessions where client_uuid = 'c0000000-0000-0000-0000-000000000001'), true, 'and it counts');
select is((select received_at from public.study_sessions where client_uuid = 'c0000000-0000-0000-0000-000000000001'), now(), 'received_at is the server clock');

-- the client claims far more than the clock allows
select lives_ok($$ insert into public.study_sessions (client_uuid, planned_s, started_at, ended_at, paused_s, client_reported_s, outcome) values ('c0000000-0000-0000-0000-000000000002', 3000, now() - interval '40 minutes', now() - interval '30 minutes', 0, 5000, 'completed') $$, 'A can report an inflated session');
select is((select validated_s from public.study_sessions where client_uuid = 'c0000000-0000-0000-0000-000000000002'), 600, 'an inflated report is cut down to the 600 seconds that really passed');

-- an end time in the future
select lives_ok($$ insert into public.study_sessions (client_uuid, planned_s, started_at, ended_at, paused_s, client_reported_s, outcome) values ('c0000000-0000-0000-0000-000000000003', 1500, now() - interval '30 minutes', now() + interval '1 hour', 0, 1500, 'completed') $$, 'a future end time is stored');
select is((select validated_s from public.study_sessions where client_uuid = 'c0000000-0000-0000-0000-000000000003'), 0, 'but earns nothing');
select is((select counted from public.study_sessions where client_uuid = 'c0000000-0000-0000-0000-000000000003'), false, 'and does not count');

-- a short session is kept but does not count (and nothing is taken away)
select lives_ok($$ insert into public.study_sessions (client_uuid, planned_s, started_at, ended_at, paused_s, client_reported_s, outcome) values ('c0000000-0000-0000-0000-000000000004', 600, now() - interval '10 minutes', now() - interval '6 minutes', 0, 240, 'ended_early') $$, 'A can record a short session');
select is((select validated_s from public.study_sessions where client_uuid = 'c0000000-0000-0000-0000-000000000004'), 240, 'a 4-minute session keeps its 240 seconds');
select is((select tree from public.study_sessions where client_uuid = 'c0000000-0000-0000-0000-000000000004'), 'none', 'but grows no tree');

-- an abandoned session that lasted long enough still earns a seedling or better (no punishment)
select lives_ok($$ insert into public.study_sessions (client_uuid, planned_s, started_at, ended_at, paused_s, client_reported_s, outcome) values ('c0000000-0000-0000-0000-000000000005', 1500, now() - interval '20 minutes', now() - interval '8 minutes', 0, 720, 'abandoned') $$, 'A can record an abandoned session');
select is((select tree from public.study_sessions where client_uuid = 'c0000000-0000-0000-0000-000000000005'), 'seedling', 'an abandoned 12-minute session still grows a seedling');

-- idempotent sync: the same client_uuid twice
select throws_ok($$ insert into public.study_sessions (client_uuid, planned_s, started_at, ended_at, paused_s, client_reported_s, outcome) values ('c0000000-0000-0000-0000-000000000001', 1500, now() - interval '30 minutes', now() - interval '5 minutes', 0, 1500, 'completed') $$, '23505', null, 'a plain repeat is a unique violation');
select lives_ok($$ insert into public.study_sessions (client_uuid, planned_s, started_at, ended_at, paused_s, client_reported_s, outcome) values ('c0000000-0000-0000-0000-000000000001', 1500, now() - interval '30 minutes', now() - interval '5 minutes', 0, 1500, 'completed') on conflict (user_id, client_uuid) do nothing $$, 'a retry with ON CONFLICT DO NOTHING succeeds');
select is((select count(*) from public.study_sessions where client_uuid = 'c0000000-0000-0000-0000-000000000001'), 1::bigint, 'and creates no duplicate');

-- the client cannot set server fields
select throws_ok($$ insert into public.study_sessions (client_uuid, planned_s, started_at, ended_at, paused_s, client_reported_s, outcome, validated_s) values (gen_random_uuid(), 1500, now() - interval '30 minutes', now() - interval '5 minutes', 0, 1500, 'completed', 99999) $$, '42501', null, 'validated_s cannot be set by the client');
select throws_ok($$ insert into public.study_sessions (client_uuid, planned_s, started_at, ended_at, paused_s, client_reported_s, outcome, counted) values (gen_random_uuid(), 1500, now() - interval '30 minutes', now() - interval '5 minutes', 0, 1500, 'completed', true) $$, '42501', null, 'counted cannot be set by the client');
select throws_ok($$ insert into public.study_sessions (client_uuid, planned_s, started_at, ended_at, paused_s, client_reported_s, outcome, received_at) values (gen_random_uuid(), 1500, now() - interval '30 minutes', now() - interval '5 minutes', 0, 1500, 'completed', now() - interval '1 day') $$, '42501', null, 'received_at cannot be set by the client');
select throws_ok($$ insert into public.study_sessions (client_uuid, planned_s, started_at, ended_at, paused_s, client_reported_s, outcome, tree) values (gen_random_uuid(), 1500, now() - interval '30 minutes', now() - interval '5 minutes', 0, 1500, 'completed', 'grove') $$, '42501', null, 'tree cannot be set by the client');

-- sessions are immutable
select throws_ok($$ update public.study_sessions set validated_s = 99999 $$, '42501', null, 'sessions cannot be updated');
select throws_ok($$ delete from public.study_sessions $$, '42501', null, 'sessions cannot be deleted by clients');

-- constraints
select throws_ok($$ insert into public.study_sessions (client_uuid, planned_s, started_at, ended_at, paused_s, client_reported_s, outcome) values (gen_random_uuid(), 30, now() - interval '30 minutes', now() - interval '5 minutes', 0, 1500, 'completed') $$, '23514', null, 'a plan under 60 seconds is rejected');
select throws_ok($$ insert into public.study_sessions (client_uuid, planned_s, started_at, ended_at, paused_s, client_reported_s, outcome) values (gen_random_uuid(), 1500, now() - interval '30 minutes', now() - interval '5 minutes', 0, -1, 'completed') $$, '23514', null, 'a negative report is rejected');
select throws_ok($$ insert into public.study_sessions (client_uuid, planned_s, started_at, ended_at, paused_s, client_reported_s, outcome) values (gen_random_uuid(), 1500, now() - interval '30 minutes', now() - interval '5 minutes', 0, 1500, 'cheated') $$, '23514', null, 'an unknown outcome is rejected');
select throws_ok($$ insert into public.study_sessions (client_uuid, planned_s, started_at, ended_at, paused_s, client_reported_s, outcome) values (gen_random_uuid(), 1500, now() - interval '30 minutes', now() - interval '5 minutes', 99999, 1500, 'completed') $$, '23514', null, 'a pause over 8 hours is rejected');
select throws_ok($$ insert into public.study_sessions (user_id, client_uuid, planned_s, started_at, ended_at, paused_s, client_reported_s, outcome) values ('00000000-0000-0000-0000-0000000000b2', gen_random_uuid(), 1500, now() - interval '30 minutes', now() - interval '5 minutes', 0, 1500, 'completed') $$, '42501', null, 'a session cannot be recorded for someone else');
select throws_ok($$ insert into public.study_sessions (subject_id, client_uuid, planned_s, started_at, ended_at, paused_s, client_reported_s, outcome) values ('10000000-0000-0000-0000-0000000000b2', gen_random_uuid(), 1500, now() - interval '30 minutes', now() - interval '5 minutes', 0, 1500, 'completed') $$, '23503', null, 'a session cannot use another user''s subject');

-- achievements are awarded by the server
select is((select count(*) from public.achievements where kind = 'first_session'), 1::bigint, 'the first counted session earned its badge');
select throws_ok($$ insert into public.achievements (user_id, kind) values ('00000000-0000-0000-0000-0000000000a1', 'hours_50') $$, '42501', null, 'a client cannot give itself a badge');
select throws_ok($$ update public.achievements set kind = 'hours_50' $$, '42501', null, 'a client cannot change a badge');
select throws_ok($$ delete from public.achievements $$, '42501', null, 'a client cannot delete a badge');

-- two 8-hour sessions: 57,600 seconds, so the 10-hour badge is earned; one local day, so no streak badge
select lives_ok($$ insert into public.study_sessions (client_uuid, planned_s, started_at, ended_at, paused_s, client_reported_s, outcome) values ('c0000000-0000-0000-0000-000000000006', 28800, now() - interval '9 hours', now() - interval '1 hour', 0, 28800, 'completed'), ('c0000000-0000-0000-0000-000000000007', 28800, now() - interval '9 hours', now() - interval '1 hour', 0, 28800, 'completed') $$, 'A records two long sessions');
select is((select validated_s from public.study_sessions where client_uuid = 'c0000000-0000-0000-0000-000000000006'), 28800, 'an 8-hour session validates to 28800');
select is((select count(*) from public.achievements where kind = 'hours_10'), 1::bigint, 'over 10 counted hours earns the 10-hour badge');
select is((select count(*) from public.achievements where kind = 'streak_3'), 0::bigint, 'one day of work is not a 3-day streak');
select is((select count(*) from public.achievements where kind = 'first_session'), 1::bigint, 'badges are never duplicated');
reset role;

-- user B sees nothing of A's, and earns only their own
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000b2', true);
set local role authenticated;
select is_empty($$ select 1 from public.study_sessions where user_id = '00000000-0000-0000-0000-0000000000a1' $$, 'B cannot see A''s sessions');
select is_empty($$ select 1 from public.achievements where user_id = '00000000-0000-0000-0000-0000000000a1' $$, 'B cannot see A''s badges');
select lives_ok($$ insert into public.study_sessions (client_uuid, planned_s, started_at, ended_at, paused_s, client_reported_s, outcome) values ('c0000000-0000-0000-0000-0000000000b1', 1500, now() - interval '30 minutes', now() - interval '5 minutes', 0, 1500, 'completed') $$, 'B records a session');
select is((select count(*) from public.achievements), 1::bigint, 'B has exactly their own first badge');
reset role;
select is((select count(*) from public.achievements where user_id = '00000000-0000-0000-0000-0000000000b2'), 1::bigint, 'and it belongs to B');
select is((select count(*) from public.achievements where user_id = '00000000-0000-0000-0000-0000000000a1' and kind = 'first_session'), 1::bigint, 'A''s badges are untouched');

select * from finish();
rollback;

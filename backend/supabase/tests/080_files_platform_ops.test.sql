-- pgTAP: files (storage metadata and quotas), notifications, calendar connections,
-- formulas, audit logs, reports, and rate limiting.
-- Run with: bash infra/scripts/run-pgtap.sh
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = extensions, public;
select plan(22);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'a@example.test'),
  ('00000000-0000-0000-0000-0000000000b2', 'b@example.test');

select is((select count(*) from information_schema.tables where table_schema = 'public' and table_name in (
  'file_objects', 'user_quotas', 'notifications', 'calendar_connections', 'formula_entries', 'audit_logs', 'reports', 'rate_limit_events'
)), 8::bigint, 'all eight files, platform and ops tables exist');

select ok((select bool_and(relrowsecurity and relforcerowsecurity) from pg_class where oid in (
  'public.file_objects'::regclass,
  'public.user_quotas'::regclass,
  'public.notifications'::regclass,
  'public.calendar_connections'::regclass,
  'public.formula_entries'::regclass,
  'public.audit_logs'::regclass,
  'public.reports'::regclass,
  'public.rate_limit_events'::regclass
)), 'RLS is enabled and forced on all eight');

-- 1. anonymous is denied across all tables
set local role anon;
select throws_ok($$ select * from public.file_objects $$, '42501', null, 'anon cannot read file_objects');
select throws_ok($$ select * from public.user_quotas $$, '42501', null, 'anon cannot read user_quotas');
select throws_ok($$ select * from public.notifications $$, '42501', null, 'anon cannot read notifications');
select throws_ok($$ select * from public.calendar_connections $$, '42501', null, 'anon cannot read calendar_connections');
select throws_ok($$ select * from public.formula_entries $$, '42501', null, 'anon cannot read formula_entries');
select throws_ok($$ select * from public.audit_logs $$, '42501', null, 'anon cannot read audit_logs');
select throws_ok($$ select * from public.reports $$, '42501', null, 'anon cannot read reports');
select throws_ok($$ select * from public.rate_limit_events $$, '42501', null, 'anon cannot read rate_limit_events');
reset role;

-- 2. user A file objects
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', true);
set local role authenticated;

select lives_ok($$
  insert into public.file_objects (id, r2_key, owner_id, size, sniffed_mime)
  values ('60000000-0000-0000-0000-0000000000a1', 'objects/00000000-0000-0000-0000-0000000000a1/avatar.png', '00000000-0000-0000-0000-0000000000a1', 1024, 'image/png')
$$, 'A can register uploaded file');

select is((select count(*) from public.file_objects where id = '60000000-0000-0000-0000-0000000000a1'), 1::bigint, 'A can see own file object');

-- User A cannot read audit logs
select throws_ok($$ select * from public.audit_logs $$, '42501', null, 'authenticated cannot read audit_logs');

-- User A can submit report
select lives_ok($$
  insert into public.reports (reporter_id, target_type, target_id, reason)
  values ('00000000-0000-0000-0000-0000000000a1', 'user', '00000000-0000-0000-0000-0000000000b2', 'Spam in group chat')
$$, 'A can submit a moderation report');

-- User A can create draft formula
select lives_ok($$
  insert into public.formula_entries (stream, subject, topic, title, latex, created_by, status)
  values ('mathematics', 'Pure Maths', 'Calculus', 'Derivative of sin(x)', '\frac{d}{dx}\sin(x) = \cos(x)', '00000000-0000-0000-0000-0000000000a1', 'draft')
$$, 'A can create draft formula');

reset role;

-- 3. user B cannot see A's file or report
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000b2', true);
set local role authenticated;

select is((select count(*) from public.file_objects where id = '60000000-0000-0000-0000-0000000000a1'), 0::bigint, 'B cannot see A file object');
select is((select count(*) from public.reports where reporter_id = '00000000-0000-0000-0000-0000000000a1'), 0::bigint, 'B cannot see A reports');
select is((select count(*) from public.formula_entries where created_by = '00000000-0000-0000-0000-0000000000a1'), 0::bigint, 'B cannot see A draft formula');

-- Calendar token columns: authenticated cannot select access_token_enc
select throws_ok($$ select access_token_enc from public.calendar_connections $$, '42501', null, 'authenticated cannot select secret access_token_enc');
reset role;

-- 4. server/private helpers
select is((select private.check_sliding_rate_limit('test-key', 'auth_attempt', 2, 60)), true, 'rate limit 1st attempt allowed');
select is((select private.check_sliding_rate_limit('test-key', 'auth_attempt', 2, 60)), true, 'rate limit 2nd attempt allowed');
select is((select private.check_sliding_rate_limit('test-key', 'auth_attempt', 2, 60)), false, 'rate limit 3rd attempt denied');

select * from finish();
rollback;


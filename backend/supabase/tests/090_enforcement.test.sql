-- pgTAP: Enforcement rules, RBAC roles, policy violations, and overrides.
-- Run with: bash infra/scripts/run-pgtap.sh
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = extensions, public;
select plan(18);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'a@example.test'),
  ('00000000-0000-0000-0000-0000000000b2', 'b@example.test');

select is((select count(*) from information_schema.tables where table_schema = 'public' and table_name in (
  'user_roles', 'enforcement_policies', 'policy_violations', 'policy_overrides'
)), 4::bigint, 'all four enforcement tables exist');

select ok((select bool_and(relrowsecurity and relforcerowsecurity) from pg_class where oid in (
  'public.user_roles'::regclass,
  'public.enforcement_policies'::regclass,
  'public.policy_violations'::regclass,
  'public.policy_overrides'::regclass
)), 'RLS is enabled and forced on all four');

-- 1. anonymous is denied across all tables
set local role anon;
select throws_ok($$ select * from public.user_roles $$, '42501', null, 'anon cannot read user_roles');
select throws_ok($$ select * from public.enforcement_policies $$, '42501', null, 'anon cannot read enforcement_policies');
select throws_ok($$ select * from public.policy_violations $$, '42501', null, 'anon cannot read policy_violations');
select throws_ok($$ select * from public.policy_overrides $$, '42501', null, 'anon cannot read policy_overrides');
reset role;

-- 2. user A role and policies
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', true);
set local role authenticated;

select lives_ok($$
  insert into public.user_roles (user_id, role)
  values ('00000000-0000-0000-0000-0000000000a1', 'student')
$$, 'A can insert own role');

select is((select role from public.user_roles where user_id = '00000000-0000-0000-0000-0000000000a1'), 'student', 'A can read own role');

select lives_ok($$
  insert into public.enforcement_policies (id, student_id, creator_id, title, mode, blocked_packages)
  values ('70000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a1', 'Study Focus', 'focus_session_lock', array['com.example.distracting'])
$$, 'A can create policy for self');

select is((select count(*) from public.enforcement_policies where id = '70000000-0000-0000-0000-0000000000a1'), 1::bigint, 'A can see own policy');

select lives_ok($$
  insert into public.policy_violations (id, student_id, policy_id, device_id, package_name, violation_type)
  values ('80000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a1', '70000000-0000-0000-0000-0000000000a1', 'dev-001', 'com.example.distracting', 'distraction_opened')
$$, 'A can log violation');

select is((select count(*) from public.policy_violations where id = '80000000-0000-0000-0000-0000000000a1'), 1::bigint, 'A can read own violation');

select lives_ok($$
  insert into public.policy_overrides (id, student_id, policy_id, reason, duration_minutes)
  values ('90000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a1', '70000000-0000-0000-0000-0000000000a1', 'Urgent family message', 15)
$$, 'A can log emergency override');

select is((select count(*) from public.policy_overrides where id = '90000000-0000-0000-0000-0000000000a1'), 1::bigint, 'A can read own override');

-- 3. user B cannot see user A policies, violations, or overrides
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000b2', true);

select is((select count(*) from public.enforcement_policies where student_id = '00000000-0000-0000-0000-0000000000a1'), 0::bigint, 'B cannot see A policy');
select is((select count(*) from public.policy_violations where student_id = '00000000-0000-0000-0000-0000000000a1'), 0::bigint, 'B cannot see A violation');
select is((select count(*) from public.policy_overrides where student_id = '00000000-0000-0000-0000-0000000000a1'), 0::bigint, 'B cannot see A override');

reset role;
select lives_ok($$ select private.purge_expired_data() $$, 'purge function runs cleanly');

select * from finish();
rollback;

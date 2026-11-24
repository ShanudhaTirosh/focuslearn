-- pgTAP: Families, parent-child links, device configs, remote commands, screen time, heartbeats.
-- Run with: bash infra/scripts/run-pgtap.sh
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = extensions, public;
select plan(19);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000f1', 'parent@example.test'),
  ('00000000-0000-0000-0000-0000000000c1', 'child@example.test'),
  ('00000000-0000-0000-0000-0000000000x1', 'stranger@example.test');

select is((select count(*) from information_schema.tables where table_schema = 'public' and table_name in (
  'families', 'parent_child_links', 'device_configs', 'remote_commands', 'screen_time_records', 'app_usage_records', 'device_heartbeats'
)), 7::bigint, 'all seven family & parental tables exist');

select ok((select bool_and(relrowsecurity and relforcerowsecurity) from pg_class where oid in (
  'public.families'::regclass,
  'public.parent_child_links'::regclass,
  'public.device_configs'::regclass,
  'public.remote_commands'::regclass,
  'public.screen_time_records'::regclass,
  'public.app_usage_records'::regclass,
  'public.device_heartbeats'::regclass
)), 'RLS is enabled and forced on all seven family tables');

-- 1. Anonymous is denied
set local role anon;
select throws_ok($$ select * from public.families $$, '42501', null, 'anon cannot read families');
select throws_ok($$ select * from public.parent_child_links $$, '42501', null, 'anon cannot read parent_child_links');
select throws_ok($$ select * from public.device_configs $$, '42501', null, 'anon cannot read device_configs');
select throws_ok($$ select * from public.remote_commands $$, '42501', null, 'anon cannot read remote_commands');
reset role;

-- 2. Parent F1 creates family and links
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000f1","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000f1', true);
set local role authenticated;

select lives_ok($$
  insert into public.families (id, owner_id, name)
  values ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000f1', 'Silva Family')
$$, 'Parent can create family');

select is((select count(*) from public.families where owner_id = '00000000-0000-0000-0000-0000000000f1'), 1::bigint, 'Parent can read own family');

select lives_ok($$
  insert into public.parent_child_links (id, family_id, parent_id, child_id, display_name, birth_year, pairing_code, status)
  values ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000c1', 'Junior', 2012, '123456', 'active')
$$, 'Parent can link child');

-- 3. Register child device under child account
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000c1","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000c1', true);
set local role authenticated;

select lives_ok($$
  insert into public.devices (id, user_id, install_id, platform, name)
  values ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000c1', '33333333-3333-3333-3333-333333333333', 'android', 'Junior Phone')
$$, 'Child device registers');

select lives_ok($$
  insert into public.screen_time_records (device_id, child_id, record_date, total_minutes)
  values ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000c1', current_date, 120)
$$, 'Child logs screen time');

-- 4. Parent configures child device & sends remote command
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000f1","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000f1', true);
set local role authenticated;

select lives_ok($$
  insert into public.device_configs (device_id, parent_id, daily_screen_time_limit_minutes, focus_mode_enabled)
  values ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000f1', 180, true)
$$, 'Parent sets device configuration');

select lives_ok($$
  insert into public.remote_commands (device_id, parent_id, command_type, idempotency_key, payload)
  values ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000f1', 'lock_device', 'key-test-001', '{"reason":"Bedtime"}'::jsonb)
$$, 'Parent queues remote command');

select is((select count(*) from public.screen_time_records where device_id = '30000000-0000-0000-0000-000000000001'), 1::bigint, 'Parent can view child screen time');

-- 5. Stranger X1 cannot access
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000x1","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000x1', true);
set local role authenticated;

select is((select count(*) from public.families), 0::bigint, 'Stranger sees no families');
select is((select count(*) from public.parent_child_links), 0::bigint, 'Stranger sees no links');
select is((select count(*) from public.device_configs), 0::bigint, 'Stranger sees no configs');
select is((select count(*) from public.remote_commands), 0::bigint, 'Stranger sees no commands');
select is((select count(*) from public.screen_time_records), 0::bigint, 'Stranger sees no screen time');

select * from finish();
rollback;

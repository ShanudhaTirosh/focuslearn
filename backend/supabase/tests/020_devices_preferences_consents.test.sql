-- pgTAP: devices, user_preferences, consents
-- Run with: bash infra/scripts/run-pgtap.sh   (connects as supabase_admin; everything is rolled back)
-- Users are impersonated by setting the JWT claims that auth.uid() reads, then switching to the API roles.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = extensions, public;
select plan(36);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'a@example.test'),
  ('00000000-0000-0000-0000-0000000000b2', 'b@example.test');

select has_table('public', 'devices', 'devices table exists');
select has_table('public', 'user_preferences', 'user_preferences table exists');
select has_table('public', 'consents', 'consents table exists');
select ok((select bool_and(relrowsecurity and relforcerowsecurity) from pg_class where oid in ('public.devices'::regclass, 'public.user_preferences'::regclass, 'public.consents'::regclass)), 'RLS enabled and forced on all three tables');

-- anonymous
set local role anon;
select throws_ok($$ select * from public.devices $$, '42501', null, 'anon cannot read devices');
select throws_ok($$ insert into public.consents (kind, version, action) values ('privacy', '1', 'grant') $$, '42501', null, 'anon cannot insert consents');
select throws_ok($$ select * from public.user_preferences $$, '42501', null, 'anon cannot read preferences');
reset role;

-- user A: devices
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', true);
set local role authenticated;
select lives_ok($$ insert into public.devices (install_id, platform, name, app_version) values ('11111111-1111-1111-1111-111111111111', 'android', ' Redmi 9 ', '1.0.0') $$, 'user can register a device');
select is((select user_id from public.devices where install_id = '11111111-1111-1111-1111-111111111111'), '00000000-0000-0000-0000-0000000000a1'::uuid, 'user_id defaults to the caller');
select is((select name from public.devices where install_id = '11111111-1111-1111-1111-111111111111'), 'Redmi 9', 'device name is trimmed');
select throws_ok($$ insert into public.devices (user_id, install_id, platform, name) values ('00000000-0000-0000-0000-0000000000b2', '22222222-2222-2222-2222-222222222222', 'android', 'Fake') $$, '42501', null, 'user cannot register a device for someone else');
select throws_ok($$ insert into public.devices (install_id, platform, name) values ('33333333-3333-3333-3333-333333333333', 'ios', 'iPhone') $$, '23514', null, 'unsupported platform is rejected');
select throws_ok($$ insert into public.devices (install_id, platform, name) values ('11111111-1111-1111-1111-111111111111', 'android', 'Again') $$, '23505', null, 'the same install cannot be registered twice');
select lives_ok($$ update public.devices set name = 'My phone' where install_id = '11111111-1111-1111-1111-111111111111' $$, 'user can rename a device');
select throws_ok($$ update public.devices set user_id = '00000000-0000-0000-0000-0000000000b2' where install_id = '11111111-1111-1111-1111-111111111111' $$, '42501', null, 'user_id of a device cannot be changed');
select lives_ok($$ update public.devices set revoked_at = now() where install_id = '11111111-1111-1111-1111-111111111111' $$, 'user can remove a device');
select throws_ok($$ update public.devices set revoked_at = null where install_id = '11111111-1111-1111-1111-111111111111' $$, '42501', null, 'a removed device cannot be restored');
select lives_ok($$ insert into public.devices (install_id, platform, name) select gen_random_uuid(), 'windows', 'PC ' || g from generate_series(1, 10) g $$, 'ten active devices are allowed');
select throws_ok($$ insert into public.devices (install_id, platform, name) values (gen_random_uuid(), 'windows', 'One too many') $$, '54000', null, 'the eleventh active device is rejected');

-- user A: preferences
select lives_ok($$ insert into public.user_preferences (language, theme) values ('si', 'dark') $$, 'user can create preferences');
select is((select language from public.user_preferences), 'si', 'preferences are stored');
select throws_ok($$ insert into public.user_preferences (language) values ('en') $$, '23505', null, 'a second preferences row is rejected');
select throws_ok($$ update public.user_preferences set language = 'fr' $$, '23514', null, 'unsupported language is rejected');
select throws_ok($$ update public.user_preferences set quiet_start = '22:00' $$, '23514', null, 'quiet hours need both a start and an end');
select lives_ok($$ update public.user_preferences set quiet_start = '22:00', quiet_end = '06:00' $$, 'quiet hours with both times are accepted');

-- user A: consents (append-only)
select lives_ok($$ insert into public.consents (kind, version, action) values ('privacy', '2026-10', 'grant') $$, 'user can record a consent');
select lives_ok($$ insert into public.consents (kind, version, action) values ('privacy', '2026-10', 'revoke') $$, 'user can record a revocation');
select is((select count(*) from public.consents), 2::bigint, 'both consent events are kept');
select throws_ok($$ update public.consents set action = 'grant' $$, '42501', null, 'consent records cannot be updated');
select throws_ok($$ delete from public.consents $$, '42501', null, 'consent records cannot be deleted');
select throws_ok($$ insert into public.consents (kind, version, action) values ('tracking', '1', 'grant') $$, '23514', null, 'unknown consent kind is rejected');
select throws_ok($$ insert into public.consents (user_id, kind, version, action) values ('00000000-0000-0000-0000-0000000000b2', 'privacy', '1', 'grant') $$, '42501', null, 'user cannot record a consent for someone else');
reset role;

-- user B sees none of A's data
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000b2', true);
set local role authenticated;
select is_empty($$ select 1 from public.devices $$, 'user B sees none of A''s devices');
select is_empty($$ select 1 from public.user_preferences $$, 'user B sees none of A''s preferences');
select is_empty($$ select 1 from public.consents $$, 'user B sees none of A''s consents');
select is_empty($$ update public.devices set name = 'Hacked' returning 1 $$, 'user B cannot rename A''s devices (no rows affected)');
reset role;

select * from finish();
rollback;

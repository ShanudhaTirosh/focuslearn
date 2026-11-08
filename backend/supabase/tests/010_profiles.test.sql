-- pgTAP: profiles
-- Run with: bash infra/scripts/run-pgtap.sh   (connects as supabase_admin; everything is rolled back)
-- Users are impersonated by setting the JWT claims that auth.uid() reads, then switching to the API roles.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = extensions, public;
select plan(25);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'a@example.test'),
  ('00000000-0000-0000-0000-0000000000b2', 'b@example.test');

select has_table('public', 'profiles', 'profiles table exists');
select ok((select relrowsecurity and relforcerowsecurity from pg_class where oid = 'public.profiles'::regclass), 'profiles: RLS enabled and forced');

-- anonymous
set local role anon;
select throws_ok($$ select * from public.profiles $$, '42501', null, 'anon cannot read profiles');
select throws_ok($$ insert into public.profiles (user_id, display_name, birth_year) values ('00000000-0000-0000-0000-0000000000a1', 'Anon', extract(year from now())::integer - 17) $$, '42501', null, 'anon cannot insert a profile');
reset role;

-- user A: a possible minor (age 17 this year; computed from the current year so the test never goes stale)
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', true);
set local role authenticated;
select lives_ok($$ insert into public.profiles (user_id, display_name, birth_year, is_discoverable, stream, tz) values ('00000000-0000-0000-0000-0000000000a1', '  Amal  ', extract(year from now())::integer - 17, true, 'commerce', 'Asia/Colombo') $$, 'user can create their own profile');
select is((select is_discoverable from public.profiles where user_id = '00000000-0000-0000-0000-0000000000a1'), false, 'a possible minor is forced to non-discoverable even when asking for true');
select is((select display_name from public.profiles where user_id = '00000000-0000-0000-0000-0000000000a1'), 'Amal', 'display name is trimmed');
select throws_ok($$ insert into public.profiles (user_id, display_name, birth_year) values ('00000000-0000-0000-0000-0000000000b2', 'Impostor', 1990) $$, '42501', null, 'user cannot create a profile for someone else');
select throws_ok($$ insert into public.profiles (user_id, display_name, birth_year) values ('00000000-0000-0000-0000-0000000000a1', 'Dup', extract(year from now())::integer - 17) $$, '23505', null, 'a second profile for the same user is rejected');
select lives_ok($$ update public.profiles set is_discoverable = true where user_id = '00000000-0000-0000-0000-0000000000a1' $$, 'update of is_discoverable is allowed');
select is((select is_discoverable from public.profiles where user_id = '00000000-0000-0000-0000-0000000000a1'), false, 'still forced to non-discoverable after the update');
select throws_ok($$ update public.profiles set birth_year = 1990 where user_id = '00000000-0000-0000-0000-0000000000a1' $$, '42501', null, 'birth_year cannot be updated by the user');
select throws_ok($$ update public.profiles set tz = 'Mars/Olympus' where user_id = '00000000-0000-0000-0000-0000000000a1' $$, '22023', null, 'unknown time zone is rejected');
select throws_ok($$ update public.profiles set avatar_key = 'objects/00000000-0000-0000-0000-0000000000b2/00000000-0000-0000-0000-000000000001' where user_id = '00000000-0000-0000-0000-0000000000a1' $$, '22023', null, 'avatar in someone else''s folder is rejected');
select lives_ok($$ update public.profiles set avatar_key = 'objects/00000000-0000-0000-0000-0000000000a1/00000000-0000-0000-0000-000000000001' where user_id = '00000000-0000-0000-0000-0000000000a1' $$, 'avatar in the user''s own folder is accepted');
select throws_ok($$ update public.profiles set display_name = '   ' where user_id = '00000000-0000-0000-0000-0000000000a1' $$, '23514', null, 'blank display name is rejected');
select throws_ok($$ update public.profiles set display_name = E'bad\x01name' where user_id = '00000000-0000-0000-0000-0000000000a1' $$, '23514', null, 'display name with a control character is rejected');
select throws_ok($$ update public.profiles set stream = 'astrology' where user_id = '00000000-0000-0000-0000-0000000000a1' $$, '23514', null, 'unknown stream is rejected');
select throws_ok($$ delete from public.profiles where user_id = '00000000-0000-0000-0000-0000000000a1' $$, '42501', null, 'users cannot delete profiles directly');
reset role;

-- user B: an adult (born in 1990, adult for any year this software will run)
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000b2', true);
set local role authenticated;
select lives_ok($$ insert into public.profiles (user_id, display_name, birth_year, is_discoverable) values ('00000000-0000-0000-0000-0000000000b2', 'Bimal', 1990, true) $$, 'adult user can create a profile');
select is((select is_discoverable from public.profiles where user_id = '00000000-0000-0000-0000-0000000000b2'), true, 'an adult may be discoverable');
select is((select count(*) from public.profiles), 1::bigint, 'user B sees only their own profile');
select is_empty($$ select 1 from public.profiles where user_id = '00000000-0000-0000-0000-0000000000a1' $$, 'user B cannot see user A');
select is_empty($$ update public.profiles set display_name = 'Hacked' where user_id = '00000000-0000-0000-0000-0000000000a1' returning 1 $$, 'user B cannot update user A (no rows affected)');
reset role;
select is((select display_name from public.profiles where user_id = '00000000-0000-0000-0000-0000000000a1'), 'Amal', 'user A is unchanged after B''s attempts');

select * from finish();
rollback;

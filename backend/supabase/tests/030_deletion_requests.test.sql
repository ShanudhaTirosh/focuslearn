-- pgTAP: deletion_requests
-- Run with: bash infra/scripts/run-pgtap.sh   (connects as supabase_admin; everything is rolled back)
-- Users are impersonated by setting the JWT claims that auth.uid() reads, then switching to the API roles.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = extensions, public;
select plan(19);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'a@example.test'),
  ('00000000-0000-0000-0000-0000000000b2', 'b@example.test');

select has_table('public', 'deletion_requests', 'deletion_requests table exists');
select ok((select relrowsecurity and relforcerowsecurity from pg_class where oid = 'public.deletion_requests'::regclass), 'deletion_requests: RLS enabled and forced');

set local role anon;
select throws_ok($$ select * from public.deletion_requests $$, '42501', null, 'anon cannot read deletion requests');
reset role;

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', true);
set local role authenticated;
select lives_ok($$ insert into public.deletion_requests (user_id) values ('00000000-0000-0000-0000-0000000000a1') $$, 'user can request deletion of their account');
select is((select status from public.deletion_requests), 'pending', 'a new request is pending');
select ok((select scheduled_for > now() + interval '6 days' from public.deletion_requests), 'deletion is scheduled after a grace period');
select throws_ok($$ insert into public.deletion_requests (user_id) values ('00000000-0000-0000-0000-0000000000a1') $$, '23505', null, 'a second active request is rejected');
select throws_ok($$ insert into public.deletion_requests (user_id) values ('00000000-0000-0000-0000-0000000000b2') $$, '42501', null, 'user cannot request deletion for someone else');
select throws_ok($$ update public.deletion_requests set scheduled_for = now() $$, '42501', null, 'user cannot shorten the grace period');
select throws_ok($$ update public.deletion_requests set status = 'done' $$, '42501', null, 'user cannot mark a request done');
select lives_ok($$ update public.deletion_requests set status = 'cancelled' $$, 'user can cancel a pending request');
select ok((select cancelled_at is not null from public.deletion_requests), 'cancellation time is recorded');
select is_empty($$ update public.deletion_requests set status = 'pending' returning 1 $$, 'a cancelled request cannot be re-opened by the user');
select lives_ok($$ insert into public.deletion_requests (user_id) values ('00000000-0000-0000-0000-0000000000a1') $$, 'a new request is allowed after cancelling');
reset role;

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000b2', true);
set local role authenticated;
select is_empty($$ select 1 from public.deletion_requests $$, 'user B cannot see A''s requests');
select is_empty($$ update public.deletion_requests set status = 'cancelled' returning 1 $$, 'user B cannot cancel A''s request');
reset role;

-- the server job (superuser here, service role in production) follows the allowed transitions only
select lives_ok($$ update public.deletion_requests set status = 'processing' where user_id = '00000000-0000-0000-0000-0000000000a1' and status = 'pending' $$, 'pending can move to processing');
select lives_ok($$ update public.deletion_requests set status = 'done' where user_id = '00000000-0000-0000-0000-0000000000a1' and status = 'processing' $$, 'processing can move to done');
select throws_ok($$ update public.deletion_requests set status = 'pending' where user_id = '00000000-0000-0000-0000-0000000000a1' and status = 'done' $$, '42501', null, 'done cannot go back to pending');

select * from finish();
rollback;

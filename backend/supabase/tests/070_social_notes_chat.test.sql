-- pgTAP: social (friendships, groups), notes, note_shares, and chat (conversations, messages)
-- Run with: bash infra/scripts/run-pgtap.sh
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = extensions, public;
select plan(20);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'a@example.test'),
  ('00000000-0000-0000-0000-0000000000b2', 'b@example.test');

select is((select count(*) from information_schema.tables where table_schema = 'public' and table_name in ('friendships', 'groups', 'group_members', 'notes', 'note_shares', 'conversations', 'conversation_members', 'messages')), 8::bigint, 'all eight social, notes and chat tables exist');
select ok((select bool_and(relrowsecurity and relforcerowsecurity) from pg_class where oid in ('public.friendships'::regclass, 'public.groups'::regclass, 'public.group_members'::regclass, 'public.notes'::regclass, 'public.note_shares'::regclass, 'public.conversations'::regclass, 'public.conversation_members'::regclass, 'public.messages'::regclass)), 'RLS is enabled and forced on all eight');

-- 1. anonymous is denied
set local role anon;
select throws_ok($$ select * from public.friendships $$, '42501', null, 'anon cannot read friendships');
select throws_ok($$ select * from public.notes $$, '42501', null, 'anon cannot read notes');
select throws_ok($$ select * from public.messages $$, '42501', null, 'anon cannot read messages');
reset role;

-- 2. user A creates private note and group
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', true);
set local role authenticated;

select lives_ok($$ insert into public.notes (id, owner_id, title, body) values ('40000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a1', 'Physics Formulas', 'E = mc^2') $$, 'A can create private note');
select lives_ok($$ insert into public.groups (id, name, owner_id) values ('50000000-0000-0000-0000-0000000000a1', 'Combined Maths Group', '00000000-0000-0000-0000-0000000000a1') $$, 'A can create a group');
select lives_ok($$ insert into public.group_members (group_id, user_id, role) values ('50000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a1', 'owner') $$, 'A can join own group as owner');
select is((select count(*) from public.notes where id = '40000000-0000-0000-0000-0000000000a1'), 1::bigint, 'A can see own note');
reset role;

-- 3. user B cannot see A note before sharing
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000b2', true);
set local role authenticated;

select is((select count(*) from public.notes where id = '40000000-0000-0000-0000-0000000000a1'), 0::bigint, 'B cannot see A unshared note');
select throws_ok($$ insert into public.notes (owner_id, title, body) values ('00000000-0000-0000-0000-0000000000a1', 'Sneaky', 'Hacked') $$, '42501', null, 'B cannot insert note under A owner_id');
reset role;

-- 4. user A shares note with user B
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', true);
set local role authenticated;

select lives_ok($$ insert into public.note_shares (note_id, grantee_user_id, permission) values ('40000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b2', 'read') $$, 'A can share note with B');
reset role;

-- 5. user B now sees the shared note
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000b2', true);
set local role authenticated;

select is((select count(*) from public.notes where id = '40000000-0000-0000-0000-0000000000a1'), 1::bigint, 'B can see note after share');
reset role;

-- 6. user A revokes the share
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', true);
set local role authenticated;

select lives_ok($$ update public.note_shares set revoked_at = now() where note_id = '40000000-0000-0000-0000-0000000000a1' and grantee_user_id = '00000000-0000-0000-0000-0000000000b2' $$, 'A can revoke share');
reset role;

-- 7. user B immediately loses access
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000b2', true);
set local role authenticated;

select is((select count(*) from public.notes where id = '40000000-0000-0000-0000-0000000000a1'), 0::bigint, 'B loses access after revoke');
reset role;

-- 8. conversations and chat messages
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', true);
set local role authenticated;

select lives_ok($$ insert into public.conversations (id, title, kind) values ('60000000-0000-0000-0000-0000000000a1', 'Study Chat', 'direct') $$, 'A can create conversation');
select lives_ok($$ insert into public.conversation_members (conversation_id, user_id) values ('60000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a1') $$, 'A joins conversation');
select lives_ok($$ insert into public.messages (conversation_id, sender_id, body) values ('60000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a1', 'Hello peer!') $$, 'A can post message in conversation');
reset role;

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000b2', true);
set local role authenticated;

select is((select count(*) from public.messages where conversation_id = '60000000-0000-0000-0000-0000000000a1'), 0::bigint, 'B cannot read messages from non-member conversation');
select throws_ok($$ insert into public.messages (conversation_id, sender_id, body) values ('60000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b2', 'Intruder message') $$, '42501', null, 'B cannot post into non-member conversation');
reset role;

select * from finish();
rollback;

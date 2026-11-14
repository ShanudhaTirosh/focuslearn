-- pgTAP: AI Notebooks, sources, document chunks, chats, artifacts, and vector RLS.
-- Run with: bash infra/scripts/run-pgtap.sh
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = extensions, public;
select plan(20);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'a@example.test'),
  ('00000000-0000-0000-0000-0000000000b2', 'b@example.test'),
  ('00000000-0000-0000-0000-0000000000c3', 'c@example.test');

select is((select count(*) from information_schema.tables where table_schema = 'public' and table_name in (
  'notebooks', 'notebook_sources', 'document_chunks', 'notebook_chats', 'study_artifacts', 'notebook_shares'
)), 6::bigint, 'all six notebook tables exist');

select ok((select bool_and(relrowsecurity and relforcerowsecurity) from pg_class where oid in (
  'public.notebooks'::regclass,
  'public.notebook_sources'::regclass,
  'public.document_chunks'::regclass,
  'public.notebook_chats'::regclass,
  'public.study_artifacts'::regclass,
  'public.notebook_shares'::regclass
)), 'RLS is enabled and forced on all six');

-- 1. anonymous access is denied
set local role anon;
select throws_ok($$ select * from public.notebooks $$, '42501', null, 'anon cannot read notebooks');
select throws_ok($$ select * from public.notebook_sources $$, '42501', null, 'anon cannot read notebook_sources');
select throws_ok($$ select * from public.document_chunks $$, '42501', null, 'anon cannot read document_chunks');
select throws_ok($$ select * from public.notebook_chats $$, '42501', null, 'anon cannot read notebook_chats');
select throws_ok($$ select * from public.study_artifacts $$, '42501', null, 'anon cannot read study_artifacts');
select throws_ok($$ select * from public.notebook_shares $$, '42501', null, 'anon cannot read notebook_shares');
reset role;

-- 2. authenticated user A creates a notebook and sources
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', true);
set local role authenticated;

select lives_ok($$
  insert into public.notebooks (id, owner_id, title, description)
  values ('80000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a1', 'Physics Mechanics', 'A/L Past Papers')
$$, 'A can create own notebook');

select is((select count(*) from public.notebooks where id = '80000000-0000-0000-0000-0000000000a1'), 1::bigint, 'A can read own notebook');

select lives_ok($$
  insert into public.notebook_sources (id, notebook_id, source_type, title, char_count, page_count)
  values ('81000000-0000-0000-0000-0000000000a1', '80000000-0000-0000-0000-0000000000a1', 'pdf', 'Unit 1 Mechanics.pdf', 5000, 10)
$$, 'A can add source to own notebook');

select lives_ok($$
  insert into public.document_chunks (id, notebook_id, source_id, chunk_index, page_number, content)
  values ('82000000-0000-0000-0000-0000000000a1', '80000000-0000-0000-0000-0000000000a1', '81000000-0000-0000-0000-0000000000a1', 0, 1, 'Newton laws of motion.')
$$, 'A can add document chunk');

select lives_ok($$
  insert into public.notebook_chats (id, notebook_id, user_id, role, content)
  values ('83000000-0000-0000-0000-0000000000a1', '80000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a1', 'user', 'Explain first law.')
$$, 'A can insert chat message');

select lives_ok($$
  insert into public.study_artifacts (id, notebook_id, artifact_type, title, data)
  values ('84000000-0000-0000-0000-0000000000a1', '80000000-0000-0000-0000-0000000000a1', 'flashcards', 'Mechanics Cards', '[]'::jsonb)
$$, 'A can insert study artifact');

select lives_ok($$
  insert into public.notebook_shares (notebook_id, shared_with_user_id, permission)
  values ('80000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b2', 'read')
$$, 'A can share notebook with B');

-- 3. user B reads shared notebook
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000b2', true);

select is((select count(*) from public.notebooks where id = '80000000-0000-0000-0000-0000000000a1'), 1::bigint, 'B can see shared notebook');

select is((select count(*) from public.notebooks where id = '80000000-0000-0000-0000-0000000000a1'), 1::bigint, 'B cannot delete shared notebook');

-- 4. stranger C has no access
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000c3","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000c3', true);

select is((select count(*) from public.notebooks where id = '80000000-0000-0000-0000-0000000000a1'), 0::bigint, 'C cannot see A notebook');

reset role;

select ok(private.can_read_notebook('80000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a1'), 'helper permits owner A');

select has_function('public', 'match_document_chunks', ARRAY['uuid', 'vector', 'integer', 'double precision'], 'match_document_chunks RPC exists');

select * from finish();
rollback;

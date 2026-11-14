-- AI Notebooks & Grounded RAG (NotebookLM-style research notebooks for A/L students)
-- Stores user sources in Cloudflare R2 and 768-dim vector embeddings in Postgres.
-- Forced Row Level Security on all tables.

create extension if not exists vector;

-- 1. Notebooks
create table public.notebooks (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  description text,
  color text not null default '#4F46E5',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.notebooks enable row level security;
alter table public.notebooks force row level security;

create trigger notebooks_updated_at_trg
  before update on public.notebooks
  for each row execute function private.set_updated_at();

create index notebooks_owner_id_idx on public.notebooks (owner_id);

-- 2. Notebook Shares (collaborative group study or peer review)
create table public.notebook_shares (
  id uuid primary key default gen_random_uuid(),
  notebook_id uuid not null references public.notebooks (id) on delete cascade,
  shared_with_user_id uuid not null references auth.users (id) on delete cascade,
  permission text not null default 'read',
  created_at timestamptz not null default now(),
  constraint notebook_shares_permission_chk check (permission in ('read', 'write')),
  constraint notebook_shares_unique_share unique (notebook_id, shared_with_user_id)
);

alter table public.notebook_shares enable row level security;
alter table public.notebook_shares force row level security;

create index notebook_shares_notebook_id_idx on public.notebook_shares (notebook_id);
create index notebook_shares_shared_with_user_id_idx on public.notebook_shares (shared_with_user_id);

-- Helper functions for notebook permissions
create or replace function private.can_read_notebook(p_notebook_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.notebooks
    where id = p_notebook_id and owner_id = p_user_id
  ) or exists (
    select 1 from public.notebook_shares
    where notebook_id = p_notebook_id and shared_with_user_id = p_user_id
  );
$$;

create or replace function private.can_write_notebook(p_notebook_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.notebooks
    where id = p_notebook_id and owner_id = p_user_id
  ) or exists (
    select 1 from public.notebook_shares
    where notebook_id = p_notebook_id and shared_with_user_id = p_user_id and permission = 'write'
  );
$$;

grant select, insert, update, delete on public.notebooks to authenticated;
grant select, insert, update, delete on public.notebook_shares to authenticated;

create policy notebooks_select on public.notebooks
  for select to authenticated
  using (private.can_read_notebook(id, (select auth.uid())));

create policy notebooks_insert on public.notebooks
  for insert to authenticated
  with check (owner_id = (select auth.uid()));

create policy notebooks_update on public.notebooks
  for update to authenticated
  using (owner_id = (select auth.uid()) or private.can_write_notebook(id, (select auth.uid())))
  with check (owner_id = (select auth.uid()) or private.can_write_notebook(id, (select auth.uid())));

create policy notebooks_delete on public.notebooks
  for delete to authenticated
  using (owner_id = (select auth.uid()));

create policy notebook_shares_select on public.notebook_shares
  for select to authenticated
  using (shared_with_user_id = (select auth.uid()) or private.can_read_notebook(notebook_id, (select auth.uid())));

create policy notebook_shares_insert on public.notebook_shares
  for insert to authenticated
  with check (exists (select 1 from public.notebooks where id = notebook_id and owner_id = (select auth.uid())));

create policy notebook_shares_delete on public.notebook_shares
  for delete to authenticated
  using (exists (select 1 from public.notebooks where id = notebook_id and owner_id = (select auth.uid())));

-- 3. Notebook Sources (PDFs, notes, text extracts)
create table public.notebook_sources (
  id uuid primary key default gen_random_uuid(),
  notebook_id uuid not null references public.notebooks (id) on delete cascade,
  source_type text not null,
  title text not null,
  r2_key text,
  char_count integer not null default 0,
  page_count integer not null default 1,
  status text not null default 'ready',
  created_at timestamptz not null default now(),
  constraint notebook_sources_type_chk check (source_type in ('pdf', 'note', 'text', 'url', 'audio')),
  constraint notebook_sources_status_chk check (status in ('pending', 'processing', 'ready', 'failed'))
);

alter table public.notebook_sources enable row level security;
alter table public.notebook_sources force row level security;

create index notebook_sources_notebook_id_idx on public.notebook_sources (notebook_id);

grant select, insert, update, delete on public.notebook_sources to authenticated;

create policy notebook_sources_select on public.notebook_sources
  for select to authenticated
  using (private.can_read_notebook(notebook_id, (select auth.uid())));

create policy notebook_sources_insert on public.notebook_sources
  for insert to authenticated
  with check (private.can_write_notebook(notebook_id, (select auth.uid())));

create policy notebook_sources_update on public.notebook_sources
  for update to authenticated
  using (private.can_write_notebook(notebook_id, (select auth.uid())))
  with check (private.can_write_notebook(notebook_id, (select auth.uid())));

create policy notebook_sources_delete on public.notebook_sources
  for delete to authenticated
  using (private.can_write_notebook(notebook_id, (select auth.uid())));

-- 4. Document Chunks (768-dimensional Matryoshka embeddings)
create table public.document_chunks (
  id uuid primary key default gen_random_uuid(),
  notebook_id uuid not null references public.notebooks (id) on delete cascade,
  source_id uuid not null references public.notebook_sources (id) on delete cascade,
  chunk_index integer not null,
  page_number integer not null default 1,
  content text not null,
  embedding vector(768),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.document_chunks enable row level security;
alter table public.document_chunks force row level security;

create index document_chunks_notebook_id_idx on public.document_chunks (notebook_id);
create index document_chunks_source_id_idx on public.document_chunks (source_id);

grant select, insert, update, delete on public.document_chunks to authenticated;

create policy document_chunks_select on public.document_chunks
  for select to authenticated
  using (private.can_read_notebook(notebook_id, (select auth.uid())));

create policy document_chunks_insert on public.document_chunks
  for insert to authenticated
  with check (private.can_write_notebook(notebook_id, (select auth.uid())));

create policy document_chunks_delete on public.document_chunks
  for delete to authenticated
  using (private.can_write_notebook(notebook_id, (select auth.uid())));

-- 5. Notebook Chats (Multi-turn grounded Q&A with citations)
create table public.notebook_chats (
  id uuid primary key default gen_random_uuid(),
  notebook_id uuid not null references public.notebooks (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null,
  content text not null,
  citations jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  constraint notebook_chats_role_chk check (role in ('user', 'assistant'))
);

alter table public.notebook_chats enable row level security;
alter table public.notebook_chats force row level security;

create index notebook_chats_notebook_id_idx on public.notebook_chats (notebook_id);
create index notebook_chats_user_id_idx on public.notebook_chats (user_id);

grant select, insert, delete on public.notebook_chats to authenticated;

create policy notebook_chats_select on public.notebook_chats
  for select to authenticated
  using (private.can_read_notebook(notebook_id, (select auth.uid())));

create policy notebook_chats_insert on public.notebook_chats
  for insert to authenticated
  with check (user_id = (select auth.uid()) and private.can_read_notebook(notebook_id, (select auth.uid())));

create policy notebook_chats_delete on public.notebook_chats
  for delete to authenticated
  using (user_id = (select auth.uid()));

-- 6. Study Artifacts (Study Guides, Flashcard decks, Quizzes, Audio Overview scripts)
create table public.study_artifacts (
  id uuid primary key default gen_random_uuid(),
  notebook_id uuid not null references public.notebooks (id) on delete cascade,
  artifact_type text not null,
  title text not null,
  data jsonb not null,
  created_at timestamptz not null default now(),
  constraint study_artifacts_type_chk check (artifact_type in ('guide', 'flashcards', 'quiz', 'audio_overview'))
);

alter table public.study_artifacts enable row level security;
alter table public.study_artifacts force row level security;

create index study_artifacts_notebook_id_idx on public.study_artifacts (notebook_id);

grant select, insert, update, delete on public.study_artifacts to authenticated;

create policy study_artifacts_select on public.study_artifacts
  for select to authenticated
  using (private.can_read_notebook(notebook_id, (select auth.uid())));

create policy study_artifacts_insert on public.study_artifacts
  for insert to authenticated
  with check (private.can_write_notebook(notebook_id, (select auth.uid())));

create policy study_artifacts_delete on public.study_artifacts
  for delete to authenticated
  using (private.can_write_notebook(notebook_id, (select auth.uid())));

-- 7. Vector Similarity Search Function (Cosine distance)
-- definer-public-ok: RPC function with explicit can_read_notebook authorization check
create or replace function public.match_document_chunks(
  p_notebook_id uuid,
  p_embedding vector(768),
  p_match_count int default 6,
  p_match_threshold float default 0.60
)
returns table (
  id uuid,
  source_id uuid,
  source_title text,
  page_number int,
  content text,
  similarity float
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  -- Verify caller has read access to the notebook
  if not private.can_read_notebook(p_notebook_id, auth.uid()) then
    raise exception 'Access denied to notebook %', p_notebook_id;
  end if;

  return query
  select
    c.id,
    c.source_id,
    s.title as source_title,
    c.page_number,
    c.content,
    1 - (c.embedding <=> p_embedding) as similarity
  from public.document_chunks c
  join public.notebook_sources s on s.id = c.source_id
  where c.notebook_id = p_notebook_id
    and c.embedding is not null
    and 1 - (c.embedding <=> p_embedding) >= p_match_threshold
  order by c.embedding <=> p_embedding
  limit p_match_count;
end;
$$;

grant execute on function public.match_document_chunks(uuid, vector, int, float) to authenticated;

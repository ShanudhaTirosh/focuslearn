-- Phase 4: Social (friendships, groups), Notes (rich study notes, shares), and Chat (conversations, messages).
-- Deny by default: RLS enabled and forced on every table in `public`.
-- Helper functions live in schema `private` with set search_path = ''.
-- Minors and privacy by default: friendships require mutual consent, notes are private until shared.

-- ---------------------------------------------------------------- friendships
create table public.friendships (
  id uuid primary key default gen_random_uuid(),
  user_a uuid not null references auth.users (id) on delete cascade,
  user_b uuid not null references auth.users (id) on delete cascade,
  status text not null check (status in ('pending', 'accepted', 'blocked')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint friendships_canonical check (user_a < user_b),
  constraint friendships_unique unique (user_a, user_b)
);
alter table public.friendships enable row level security;
alter table public.friendships force row level security;

-- ---------------------------------------------------------------- groups
create table public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 100),
  description text check (description is null or char_length(description) <= 500),
  owner_id uuid not null references auth.users (id) on delete cascade,
  invite_code_hash text,
  invite_expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
alter table public.groups enable row level security;
alter table public.groups force row level security;

create table public.group_members (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'admin', 'moderator', 'member')),
  created_at timestamptz not null default now(),
  revoked_at timestamptz,
  constraint group_members_unique unique (group_id, user_id)
);
alter table public.group_members enable row level security;
alter table public.group_members force row level security;

-- ---------------------------------------------------------------- notes
create table public.notes (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  subject_id uuid references public.subjects (id) on delete set null,
  title text not null check (char_length(title) between 1 and 200),
  body text not null default '',
  folder text check (folder is null or char_length(folder) <= 50),
  tags text[] not null default '{}',
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
alter table public.notes enable row level security;
alter table public.notes force row level security;

create table public.note_shares (
  id uuid primary key default gen_random_uuid(),
  note_id uuid not null references public.notes (id) on delete cascade,
  grantee_user_id uuid references auth.users (id) on delete cascade,
  grantee_group_id uuid references public.groups (id) on delete cascade,
  permission text not null check (permission in ('read', 'edit')),
  created_at timestamptz not null default now(),
  revoked_at timestamptz,
  constraint note_shares_target_chk check (
    (grantee_user_id is not null and grantee_group_id is null)
    or (grantee_user_id is null and grantee_group_id is not null)
  )
);
alter table public.note_shares enable row level security;
alter table public.note_shares force row level security;

-- ---------------------------------------------------------------- chat
create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  group_id uuid references public.groups (id) on delete cascade,
  title text check (title is null or char_length(title) <= 100),
  kind text not null default 'direct' check (kind in ('direct', 'group')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
alter table public.conversations enable row level security;
alter table public.conversations force row level security;

create table public.conversation_members (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  last_read_at timestamptz,
  created_at timestamptz not null default now(),
  constraint conversation_members_unique unique (conversation_id, user_id)
);
alter table public.conversation_members enable row level security;
alter table public.conversation_members force row level security;

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  sender_id uuid not null references auth.users (id) on delete cascade,
  body text not null check (char_length(body) between 1 and 4000),
  created_at timestamptz not null default now(),
  edited_at timestamptz,
  deleted_at timestamptz
);
alter table public.messages enable row level security;
alter table public.messages force row level security;

-- ---------------------------------------------------------------- helpers
create or replace function private.not_blocked(p_a uuid, p_b uuid)
returns boolean
language sql
security definer
stable
set search_path = ''
as $$
  select not exists (
    select 1 from public.friendships
    where user_a = least(p_a, p_b)
      and user_b = greatest(p_a, p_b)
      and status = 'blocked'
  );
$$;

create or replace function private.is_group_member(p_group uuid, p_user uuid)
returns boolean
language sql
security definer
stable
set search_path = ''
as $$
  select exists (
    select 1 from public.group_members
    where group_id = p_group
      and user_id = p_user
      and revoked_at is null
  );
$$;

create or replace function private.is_conversation_member(p_conv uuid, p_user uuid)
returns boolean
language sql
security definer
stable
set search_path = ''
as $$
  select exists (
    select 1 from public.conversation_members
    where conversation_id = p_conv
      and user_id = p_user
  );
$$;

create or replace function private.can_read_note(p_note uuid, p_user uuid)
returns boolean
language sql
security definer
stable
set search_path = ''
as $$
  select exists (
    select 1 from public.notes n
    where n.id = p_note
      and n.deleted_at is null
      and (
        n.owner_id = p_user
        or exists (
          select 1 from public.note_shares s
          where s.note_id = n.id
            and s.revoked_at is null
            and (
              s.grantee_user_id = p_user
              or (s.grantee_group_id is not null and private.is_group_member(s.grantee_group_id, p_user))
            )
        )
      )
  );
$$;

-- ---------------------------------------------------------------- access & policies
grant execute on function private.not_blocked(uuid, uuid) to authenticated;
grant execute on function private.is_group_member(uuid, uuid) to authenticated;
grant execute on function private.is_conversation_member(uuid, uuid) to authenticated;
grant execute on function private.can_read_note(uuid, uuid) to authenticated;

grant select, insert, update on public.friendships to authenticated;
grant select, insert, update on public.groups to authenticated;
grant select, insert, update on public.group_members to authenticated;
grant select, insert, update, delete on public.notes to authenticated;
grant select, insert, update, delete on public.note_shares to authenticated;
grant select, insert, update on public.conversations to authenticated;
grant select, insert, update on public.conversation_members to authenticated;
grant select, insert, update, delete on public.messages to authenticated;

-- Friendships policies
create policy friendships_select_party on public.friendships for select to authenticated
  using (user_a = (select auth.uid()) or user_b = (select auth.uid()));

create policy friendships_insert_party on public.friendships for insert to authenticated
  with check (user_a = (select auth.uid()) or user_b = (select auth.uid()));

create policy friendships_update_party on public.friendships for update to authenticated
  using (user_a = (select auth.uid()) or user_b = (select auth.uid()));

-- Groups policies
create policy groups_select_member on public.groups for select to authenticated
  using (owner_id = (select auth.uid()) or private.is_group_member(id, (select auth.uid())));

create policy groups_insert_owner on public.groups for insert to authenticated
  with check (owner_id = (select auth.uid()));

create policy groups_update_owner on public.groups for update to authenticated
  using (owner_id = (select auth.uid()));

-- Group members policies
create policy group_members_select on public.group_members for select to authenticated
  using (user_id = (select auth.uid()) or private.is_group_member(group_id, (select auth.uid())));

create policy group_members_insert on public.group_members for insert to authenticated
  with check (user_id = (select auth.uid()) or exists (select 1 from public.groups g where g.id = group_id and g.owner_id = (select auth.uid())));

create policy group_members_update on public.group_members for update to authenticated
  using (user_id = (select auth.uid()) or exists (select 1 from public.groups g where g.id = group_id and g.owner_id = (select auth.uid())));

-- Notes policies
create policy notes_select_accessible on public.notes for select to authenticated
  using (private.can_read_note(id, (select auth.uid())));

create policy notes_insert_owner on public.notes for insert to authenticated
  with check (owner_id = (select auth.uid()));

create policy notes_update_owner on public.notes for update to authenticated
  using (owner_id = (select auth.uid()) or exists (
    select 1 from public.note_shares s where s.note_id = id and s.permission = 'edit' and s.revoked_at is null and s.grantee_user_id = (select auth.uid())
  ));

create policy notes_delete_owner on public.notes for delete to authenticated
  using (owner_id = (select auth.uid()));

-- Note shares policies
create policy note_shares_select on public.note_shares for select to authenticated
  using (exists (select 1 from public.notes n where n.id = note_id and n.owner_id = (select auth.uid())) or grantee_user_id = (select auth.uid()));

create policy note_shares_insert on public.note_shares for insert to authenticated
  with check (exists (select 1 from public.notes n where n.id = note_id and n.owner_id = (select auth.uid())));

create policy note_shares_update on public.note_shares for update to authenticated
  using (exists (select 1 from public.notes n where n.id = note_id and n.owner_id = (select auth.uid())));

create policy note_shares_delete on public.note_shares for delete to authenticated
  using (exists (select 1 from public.notes n where n.id = note_id and n.owner_id = (select auth.uid())));

-- Conversations policies
create policy conversations_select on public.conversations for select to authenticated
  using (private.is_conversation_member(id, (select auth.uid())));

create policy conversations_insert on public.conversations for insert to authenticated
  with check (group_id is null or private.is_group_member(group_id, (select auth.uid())));

create policy conversations_update on public.conversations for update to authenticated
  using (private.is_conversation_member(id, (select auth.uid())));

-- Conversation members policies
create policy conversation_members_select on public.conversation_members for select to authenticated
  using (private.is_conversation_member(conversation_id, (select auth.uid())));

create policy conversation_members_insert on public.conversation_members for insert to authenticated
  with check (user_id = (select auth.uid()) or private.is_conversation_member(conversation_id, (select auth.uid())));

create policy conversation_members_update on public.conversation_members for update to authenticated
  using (user_id = (select auth.uid()));

-- Messages policies
create policy messages_select on public.messages for select to authenticated
  using (private.is_conversation_member(conversation_id, (select auth.uid())));

create policy messages_insert on public.messages for insert to authenticated
  with check (sender_id = (select auth.uid()) and private.is_conversation_member(conversation_id, (select auth.uid())));

create policy messages_update on public.messages for update to authenticated
  using (sender_id = (select auth.uid()));

create policy messages_delete on public.messages for delete to authenticated
  using (sender_id = (select auth.uid()));


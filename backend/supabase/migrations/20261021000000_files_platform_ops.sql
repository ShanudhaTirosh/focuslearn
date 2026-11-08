-- Phase 6, 8, 9: files (storage metadata and quotas), notifications, calendar connections,
-- formulas, audit logs, reports, and rate limiting.

-- 1. File objects & storage metadata
create table public.file_objects (
  id uuid primary key default gen_random_uuid(),
  r2_key text not null unique,
  owner_id uuid not null references auth.users (id) on delete cascade,
  size bigint not null default 0,
  sniffed_mime text not null default 'application/octet-stream',
  status text not null default 'pending',
  scan_state text not null default 'unscanned',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint file_objects_size_chk check (size >= 0),
  constraint file_objects_status_chk check (status in ('pending', 'ready', 'failed')),
  constraint file_objects_scan_chk check (scan_state in ('unscanned', 'clean', 'flagged'))
);

alter table public.file_objects enable row level security;
alter table public.file_objects force row level security;

create trigger file_objects_updated_at_trg
  before update on public.file_objects
  for each row execute function private.set_updated_at();

grant select, insert, update (deleted_at) on public.file_objects to authenticated;

create policy file_objects_select_own on public.file_objects
  for select to authenticated
  using (owner_id = (select auth.uid()) and deleted_at is null);

create policy file_objects_insert_own on public.file_objects
  for insert to authenticated
  with check (owner_id = (select auth.uid()));

create policy file_objects_soft_delete_own on public.file_objects
  for update to authenticated
  using (owner_id = (select auth.uid()) and deleted_at is null)
  with check (owner_id = (select auth.uid()) and deleted_at is not null);

-- 2. User quotas
create table public.user_quotas (
  user_id uuid primary key references auth.users (id) on delete cascade,
  bytes_used bigint not null default 0,
  bytes_limit bigint not null default 104857600,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint user_quotas_bytes_chk check (bytes_used >= 0 and bytes_limit >= 0)
);

alter table public.user_quotas enable row level security;
alter table public.user_quotas force row level security;

create trigger user_quotas_updated_at_trg
  before update on public.user_quotas
  for each row execute function private.set_updated_at();

grant select on public.user_quotas to authenticated;

create policy user_quotas_select_own on public.user_quotas
  for select to authenticated
  using (user_id = (select auth.uid()));

-- 3. In-app and push notifications ledger
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null,
  title text not null,
  body text not null,
  data jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.notifications enable row level security;
alter table public.notifications force row level security;

grant select, update (read_at) on public.notifications to authenticated;

create policy notifications_select_own on public.notifications
  for select to authenticated
  using (user_id = (select auth.uid()));

create policy notifications_update_read_own on public.notifications
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- 4. Calendar connections (Google Calendar OAuth)
-- Sensitive tokens (access_token_enc, refresh_token_enc) are NEVER granted to authenticated.
create table public.calendar_connections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  provider text not null default 'google',
  external_calendar_id text not null default 'primary',
  access_token_enc text,
  refresh_token_enc text,
  sync_token text,
  status text not null default 'connected',
  last_synced_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint calendar_connections_user_provider_key unique (user_id, provider),
  constraint calendar_connections_status_chk check (status in ('connected', 'syncing', 'error', 'disconnected'))
);

alter table public.calendar_connections enable row level security;
alter table public.calendar_connections force row level security;

create trigger calendar_connections_updated_at_trg
  before update on public.calendar_connections
  for each row execute function private.set_updated_at();

grant select (id, user_id, provider, external_calendar_id, sync_token, status, last_synced_at, created_at, updated_at)
  on public.calendar_connections to authenticated;

create policy calendar_connections_select_own on public.calendar_connections
  for select to authenticated
  using (user_id = (select auth.uid()));

-- 5. Formula entries (published formulas public to authenticated, draft/review by author)
create table public.formula_entries (
  id uuid primary key default gen_random_uuid(),
  stream text not null,
  subject text not null,
  topic text not null,
  title text not null,
  latex text not null,
  description text,
  status text not null default 'published',
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint formula_entries_status_chk check (status in ('draft', 'review', 'published'))
);

alter table public.formula_entries enable row level security;
alter table public.formula_entries force row level security;

create trigger formula_entries_updated_at_trg
  before update on public.formula_entries
  for each row execute function private.set_updated_at();

grant select, insert on public.formula_entries to authenticated;

create policy formula_entries_select on public.formula_entries
  for select to authenticated
  using (status = 'published' or created_by = (select auth.uid()));

create policy formula_entries_insert on public.formula_entries
  for insert to authenticated
  with check (created_by = (select auth.uid()) and status in ('draft', 'review'));

-- 6. Audit logs (strictly append-only, service-role only, no client grant)
create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references auth.users (id) on delete set null,
  actor_role text not null default 'authenticated',
  action text not null,
  entity_type text not null,
  entity_id text not null,
  before_state jsonb,
  after_state jsonb,
  ip_address text,
  user_agent text,
  created_at timestamptz not null default now()
);

alter table public.audit_logs enable row level security;
alter table public.audit_logs force row level security;

-- 7. Moderation reports
create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users (id) on delete cascade,
  target_type text not null,
  target_id uuid not null,
  reason text not null,
  details text,
  status text not null default 'pending',
  action_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint reports_target_type_chk check (target_type in ('user', 'group', 'note', 'message')),
  constraint reports_status_chk check (status in ('pending', 'reviewed', 'actioned', 'dismissed'))
);

alter table public.reports enable row level security;
alter table public.reports force row level security;

create trigger reports_updated_at_trg
  before update on public.reports
  for each row execute function private.set_updated_at();

grant select, insert on public.reports to authenticated;

create policy reports_select_own on public.reports
  for select to authenticated
  using (reporter_id = (select auth.uid()));

create policy reports_insert_own on public.reports
  for insert to authenticated
  with check (reporter_id = (select auth.uid()) and status = 'pending');

-- 8. Rate limiting events
create table public.rate_limit_events (
  id uuid primary key default gen_random_uuid(),
  key text not null,
  event_type text not null,
  recorded_at timestamptz not null default now()
);

create index rate_limit_events_lookup_idx on public.rate_limit_events (key, recorded_at desc);

alter table public.rate_limit_events enable row level security;
alter table public.rate_limit_events force row level security;

-- 9. Private helper functions for ops and audit
create or replace function private.record_audit_log(
  p_actor_id uuid,
  p_actor_role text,
  p_action text,
  p_entity_type text,
  p_entity_id text,
  p_before jsonb,
  p_after jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  insert into public.audit_logs (actor_id, actor_role, action, entity_type, entity_id, before_state, after_state)
  values (p_actor_id, p_actor_role, p_action, p_entity_type, p_entity_id, p_before, p_after)
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function private.check_sliding_rate_limit(
  p_key text,
  p_event_type text,
  p_max_events integer,
  p_window_seconds integer
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  select count(*) into v_count
  from public.rate_limit_events
  where key = p_key
    and recorded_at >= (now() - (p_window_seconds || ' seconds')::interval);

  if v_count >= p_max_events then
    return false;
  end if;

  insert into public.rate_limit_events (key, event_type)
  values (p_key, p_event_type);
  return true;
end;
$$;


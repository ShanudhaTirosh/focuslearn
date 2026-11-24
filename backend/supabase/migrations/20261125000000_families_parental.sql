-- Migration: 20261125000000_families_parental.sql
-- Description: Core schema for Family groups, Parent-Child links, Device Remote Configurations,
-- Remote Commands queue, Daily Screen Time & App Usage records, and Device Heartbeats.
-- Forced Row Level Security on all tables.

-- 1. Helper functions in private schema
create or replace function private.is_parent_of_device(p_parent_id uuid, p_device_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.parent_child_links pcl
    join public.devices d on d.user_id = pcl.child_id
    where pcl.parent_id = p_parent_id
      and d.id = p_device_id
      and pcl.status = 'active'
  );
$$;

create or replace function private.is_child_device(p_child_id uuid, p_device_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.devices d
    where d.id = p_device_id
      and d.user_id = p_child_id
  );
$$;

-- 2. Families (Family groups created by parent)
create table public.families (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.families enable row level security;
alter table public.families force row level security;

create trigger families_updated_at_trg
  before update on public.families
  for each row execute function private.set_updated_at();

create index families_owner_id_idx on public.families (owner_id);

grant select, insert, update, delete on public.families to authenticated;

create policy families_select_own on public.families
  for select to authenticated
  using (owner_id = (select auth.uid()));

create policy families_insert_own on public.families
  for insert to authenticated
  with check (owner_id = (select auth.uid()));

create policy families_update_own on public.families
  for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

create policy families_delete_own on public.families
  for delete to authenticated
  using (owner_id = (select auth.uid()));

-- 3. Parent-Child Links (Pairing and family membership)
create table public.parent_child_links (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  parent_id uuid not null references auth.users (id) on delete cascade,
  child_id uuid references auth.users (id) on delete cascade,
  display_name text not null check (char_length(btrim(display_name)) between 1 and 60),
  birth_year integer not null check (birth_year between 1950 and 2100),
  pairing_code text check (pairing_code is null or char_length(pairing_code) = 6),
  pairing_expires_at timestamptz,
  status text not null default 'pending' check (status in ('pending', 'active', 'revoked')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint parent_child_links_unique unique (parent_id, child_id)
);

alter table public.parent_child_links enable row level security;
alter table public.parent_child_links force row level security;

create trigger parent_child_links_updated_at_trg
  before update on public.parent_child_links
  for each row execute function private.set_updated_at();

create index pcl_parent_idx on public.parent_child_links (parent_id);
create index pcl_child_idx on public.parent_child_links (child_id);
create index pcl_pairing_code_idx on public.parent_child_links (pairing_code) where pairing_code is not null;

grant select, insert, update, delete on public.parent_child_links to authenticated;

create policy pcl_select on public.parent_child_links
  for select to authenticated
  using (parent_id = (select auth.uid()) or child_id = (select auth.uid()));

create policy pcl_insert_parent on public.parent_child_links
  for insert to authenticated
  with check (parent_id = (select auth.uid()));

create policy pcl_update on public.parent_child_links
  for update to authenticated
  using (parent_id = (select auth.uid()) or child_id = (select auth.uid()))
  with check (parent_id = (select auth.uid()) or child_id = (select auth.uid()));

create policy pcl_delete_parent on public.parent_child_links
  for delete to authenticated
  using (parent_id = (select auth.uid()));

-- 4. Device Configurations (Parental control policies applied to child device)
create table public.device_configs (
  id uuid primary key default gen_random_uuid(),
  device_id uuid not null references public.devices (id) on delete cascade,
  parent_id uuid not null references auth.users (id) on delete cascade,
  daily_screen_time_limit_minutes integer not null default 480 check (daily_screen_time_limit_minutes >= 0),
  bedtime_start time,
  bedtime_end time,
  schedule_days integer[] not null default '{1,2,3,4,5}',
  study_start time,
  study_end time,
  blocked_packages text[] not null default '{}',
  allowed_packages text[] not null default '{}',
  website_blocklist text[] not null default '{}',
  website_allowlist text[] not null default '{}',
  focus_mode_enabled boolean not null default false,
  last_synced_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint device_configs_device_unique unique (device_id)
);

alter table public.device_configs enable row level security;
alter table public.device_configs force row level security;

create trigger device_configs_updated_at_trg
  before update on public.device_configs
  for each row execute function private.set_updated_at();

create index device_configs_device_idx on public.device_configs (device_id);
create index device_configs_parent_idx on public.device_configs (parent_id);

grant select, insert, update, delete on public.device_configs to authenticated;

create policy device_configs_select on public.device_configs
  for select to authenticated
  using (
    parent_id = (select auth.uid())
    or exists (
      select 1 from public.devices d
      where d.id = device_configs.device_id and d.user_id = (select auth.uid())
    )
  );

create policy device_configs_insert on public.device_configs
  for insert to authenticated
  with check (parent_id = (select auth.uid()));

create policy device_configs_update on public.device_configs
  for update to authenticated
  using (
    parent_id = (select auth.uid())
    or exists (
      select 1 from public.devices d
      where d.id = device_configs.device_id and d.user_id = (select auth.uid())
    )
  )
  with check (
    parent_id = (select auth.uid())
    or exists (
      select 1 from public.devices d
      where d.id = device_configs.device_id and d.user_id = (select auth.uid())
    )
  );

create policy device_configs_delete on public.device_configs
  for delete to authenticated
  using (parent_id = (select auth.uid()));

-- 5. Remote Commands Queue (Parent commands to child devices)
create table public.remote_commands (
  id uuid primary key default gen_random_uuid(),
  device_id uuid not null references public.devices (id) on delete cascade,
  parent_id uuid not null references auth.users (id) on delete cascade,
  command_type text not null check (command_type in (
    'update_config', 'lock_device', 'unlock_device',
    'start_focus_session', 'end_focus_session',
    'sync_now', 'revoke_device', 'send_notification'
  )),
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'pending' check (status in ('pending', 'acknowledged', 'executed', 'failed', 'expired')),
  idempotency_key text not null unique,
  expires_at timestamptz not null default (now() + interval '24 hours'),
  created_at timestamptz not null default now(),
  acknowledged_at timestamptz,
  executed_at timestamptz,
  error_message text
);

alter table public.remote_commands enable row level security;
alter table public.remote_commands force row level security;

create index remote_commands_device_status_idx on public.remote_commands (device_id, status);
create index remote_commands_parent_idx on public.remote_commands (parent_id);

grant select, insert, update on public.remote_commands to authenticated;

create policy remote_commands_select on public.remote_commands
  for select to authenticated
  using (
    parent_id = (select auth.uid())
    or exists (
      select 1 from public.devices d
      where d.id = remote_commands.device_id and d.user_id = (select auth.uid())
    )
  );

create policy remote_commands_insert on public.remote_commands
  for insert to authenticated
  with check (parent_id = (select auth.uid()));

create policy remote_commands_update on public.remote_commands
  for update to authenticated
  using (
    parent_id = (select auth.uid())
    or exists (
      select 1 from public.devices d
      where d.id = remote_commands.device_id and d.user_id = (select auth.uid())
    )
  )
  with check (
    parent_id = (select auth.uid())
    or exists (
      select 1 from public.devices d
      where d.id = remote_commands.device_id and d.user_id = (select auth.uid())
    )
  );

-- 6. Screen Time Records (Daily summary totals)
create table public.screen_time_records (
  id uuid primary key default gen_random_uuid(),
  device_id uuid not null references public.devices (id) on delete cascade,
  child_id uuid not null references auth.users (id) on delete cascade,
  record_date date not null,
  total_minutes integer not null default 0 check (total_minutes >= 0),
  app_breakdown jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint screen_time_device_date_unique unique (device_id, record_date)
);

alter table public.screen_time_records enable row level security;
alter table public.screen_time_records force row level security;

create trigger screen_time_records_updated_at_trg
  before update on public.screen_time_records
  for each row execute function private.set_updated_at();

create index screen_time_child_date_idx on public.screen_time_records (child_id, record_date desc);

grant select, insert, update on public.screen_time_records to authenticated;

create policy screen_time_select on public.screen_time_records
  for select to authenticated
  using (
    child_id = (select auth.uid())
    or private.is_parent_of_device((select auth.uid()), device_id)
  );

create policy screen_time_insert on public.screen_time_records
  for insert to authenticated
  with check (child_id = (select auth.uid()));

create policy screen_time_update on public.screen_time_records
  for update to authenticated
  using (child_id = (select auth.uid()))
  with check (child_id = (select auth.uid()));

-- 7. App Usage Records (Per-package detailed logs)
create table public.app_usage_records (
  id uuid primary key default gen_random_uuid(),
  device_id uuid not null references public.devices (id) on delete cascade,
  child_id uuid not null references auth.users (id) on delete cascade,
  package_name text not null,
  app_label text,
  usage_date date not null,
  total_minutes integer not null default 0 check (total_minutes >= 0),
  session_count integer not null default 0 check (session_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint app_usage_device_pkg_date_unique unique (device_id, package_name, usage_date)
);

alter table public.app_usage_records enable row level security;
alter table public.app_usage_records force row level security;

create trigger app_usage_records_updated_at_trg
  before update on public.app_usage_records
  for each row execute function private.set_updated_at();

create index app_usage_child_date_idx on public.app_usage_records (child_id, usage_date desc);

grant select, insert, update on public.app_usage_records to authenticated;

create policy app_usage_select on public.app_usage_records
  for select to authenticated
  using (
    child_id = (select auth.uid())
    or private.is_parent_of_device((select auth.uid()), device_id)
  );

create policy app_usage_insert on public.app_usage_records
  for insert to authenticated
  with check (child_id = (select auth.uid()));

create policy app_usage_update on public.app_usage_records
  for update to authenticated
  using (child_id = (select auth.uid()))
  with check (child_id = (select auth.uid()));

-- 8. Device Heartbeats (Periodic device status)
create table public.device_heartbeats (
  id uuid primary key default gen_random_uuid(),
  device_id uuid not null references public.devices (id) on delete cascade,
  battery_level integer check (battery_level is null or (battery_level between 0 and 100)),
  is_charging boolean,
  is_connected boolean not null default true,
  network_type text,
  os_version text,
  app_version text,
  reported_at timestamptz not null default now()
);

alter table public.device_heartbeats enable row level security;
alter table public.device_heartbeats force row level security;

create index device_heartbeats_device_idx on public.device_heartbeats (device_id, reported_at desc);

grant select, insert on public.device_heartbeats to authenticated;

create policy device_heartbeats_select on public.device_heartbeats
  for select to authenticated
  using (
    exists (
      select 1 from public.devices d
      where d.id = device_heartbeats.device_id and d.user_id = (select auth.uid())
    )
    or private.is_parent_of_device((select auth.uid()), device_id)
  );

create policy device_heartbeats_insert on public.device_heartbeats
  for insert to authenticated
  with check (
    exists (
      select 1 from public.devices d
      where d.id = device_heartbeats.device_id and d.user_id = (select auth.uid())
    )
  );

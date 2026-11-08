-- Phase 1: devices, user preferences, consent records.

-- ---------------------------------------------------------------- devices
-- A device row is the user-facing "my devices" list. Supabase Auth keeps the real sessions in auth.sessions, which the API does not expose.
create table public.devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  install_id uuid not null,
  platform text not null,
  name text not null,
  app_version text,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  revoked_at timestamptz,
  constraint devices_platform_chk check (platform in ('android', 'windows')),
  constraint devices_name_chk check (char_length(btrim(name)) between 1 and 60 and name !~ '[[:cntrl:]]'),
  constraint devices_app_version_chk check (app_version is null or char_length(app_version) <= 32),
  constraint devices_install_unique unique (user_id, install_id)
);
create index devices_active_idx on public.devices (user_id) where revoked_at is null;

alter table public.devices enable row level security;
alter table public.devices force row level security;

create or replace function private.devices_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    -- At most 10 active devices per user (stops table stuffing).
    if (select count(*) from public.devices d where d.user_id = new.user_id and d.revoked_at is null) >= 10 then
      raise exception 'too many active devices' using errcode = '54000';
    end if;
  else
    -- A removed device stays removed.
    if old.revoked_at is not null and new.revoked_at is distinct from old.revoked_at then
      raise exception 'a removed device cannot be restored' using errcode = '42501';
    end if;
  end if;
  new.name := btrim(new.name);
  return new;
end;
$$;

create trigger devices_guard_trg
  before insert or update on public.devices
  for each row execute function private.devices_guard();

grant select on public.devices to authenticated;
grant insert (user_id, install_id, platform, name, app_version) on public.devices to authenticated;
grant update (name, app_version, last_seen_at, revoked_at) on public.devices to authenticated;

create policy devices_select_own on public.devices
  for select to authenticated using (user_id = (select auth.uid()));
create policy devices_insert_own on public.devices
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy devices_update_own on public.devices
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- ---------------------------------------------------------------- user_preferences
create table public.user_preferences (
  user_id uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  language text not null default 'en',
  theme text not null default 'system',
  low_resource_mode boolean not null default false,
  lock_screen_privacy boolean not null default true,
  quiet_start time,
  quiet_end time,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint user_preferences_language_chk check (language in ('en', 'si', 'ta')),
  constraint user_preferences_theme_chk check (theme in ('light', 'dark', 'system')),
  constraint user_preferences_quiet_chk check ((quiet_start is null) = (quiet_end is null))
);

alter table public.user_preferences enable row level security;
alter table public.user_preferences force row level security;

create trigger user_preferences_updated_at
  before update on public.user_preferences
  for each row execute function private.set_updated_at();

grant select on public.user_preferences to authenticated;
grant insert (user_id, language, theme, low_resource_mode, lock_screen_privacy, quiet_start, quiet_end) on public.user_preferences to authenticated;
grant update (language, theme, low_resource_mode, lock_screen_privacy, quiet_start, quiet_end) on public.user_preferences to authenticated;

create policy user_preferences_select_own on public.user_preferences
  for select to authenticated using (user_id = (select auth.uid()));
create policy user_preferences_insert_own on public.user_preferences
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy user_preferences_update_own on public.user_preferences
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- ---------------------------------------------------------------- consents (append-only)
-- One row per grant or revoke event. There is deliberately no UPDATE or DELETE grant and no such policy for any API role.
create table public.consents (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  kind text not null,
  version text not null,
  action text not null,
  created_at timestamptz not null default now(),
  constraint consents_kind_chk check (kind in ('terms', 'privacy', 'usage_monitor', 'calendar_sync', 'managed_device')),
  constraint consents_version_chk check (char_length(version) between 1 and 20),
  constraint consents_action_chk check (action in ('grant', 'revoke'))
);
create index consents_user_kind_idx on public.consents (user_id, kind, created_at desc);

alter table public.consents enable row level security;
alter table public.consents force row level security;

grant select on public.consents to authenticated;
grant insert (user_id, kind, version, action) on public.consents to authenticated;

create policy consents_select_own on public.consents
  for select to authenticated using (user_id = (select auth.uid()));
create policy consents_insert_own on public.consents
  for insert to authenticated with check (user_id = (select auth.uid()));

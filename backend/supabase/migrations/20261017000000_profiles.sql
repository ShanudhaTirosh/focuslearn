-- Phase 1: profiles. One row per user, created by the client during onboarding (not by a trigger on auth.users).
-- Visibility in Phase 1: owner only. Phase 4 adds friend / group / discoverable visibility in a NEW migration.

create table public.profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null,
  avatar_key text,
  stream text not null default 'other',
  subjects text[] not null default '{}',
  birth_year integer not null,
  is_discoverable boolean not null default false,
  tz text not null default 'Asia/Colombo',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_display_name_chk check (char_length(btrim(display_name)) between 1 and 40 and display_name !~ '[[:cntrl:]]'),
  constraint profiles_stream_chk check (stream in ('technology', 'commerce', 'science', 'mathematics', 'arts', 'other')),
  constraint profiles_subjects_chk check (cardinality(subjects) <= 12 and char_length(array_to_string(subjects, ',')) <= 720),
  constraint profiles_avatar_key_chk check (avatar_key is null or avatar_key ~ '^objects/[0-9a-f-]{36}/[0-9a-f-]{36}$'),
  constraint profiles_birth_year_chk check (birth_year between 1950 and 2100)
);

alter table public.profiles enable row level security;
alter table public.profiles force row level security;

-- Server-side rules the client cannot bypass.
create or replace function private.profiles_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    if new.birth_year is distinct from old.birth_year then
      raise exception 'birth_year cannot be changed' using errcode = '42501';
    end if;
    if new.user_id is distinct from old.user_id then
      raise exception 'user_id cannot be changed' using errcode = '42501';
    end if;
  end if;

  -- Possibly a minor: anyone who could still be under 18 this calendar year (a year of birth cannot tell exactly).
  -- Possible minors are never discoverable by strangers, whatever the client asks for. (Age of majority: lawyer to confirm.)
  if extract(year from (now() at time zone 'utc'))::integer - new.birth_year < 19 then
    new.is_discoverable := false;
  end if;

  if not exists (select 1 from pg_catalog.pg_timezone_names where name = new.tz) then
    raise exception 'unknown time zone' using errcode = '22023';
  end if;

  -- An avatar key must point into the user's own folder, otherwise a later signed-URL function could expose another user's file.
  if new.avatar_key is not null and split_part(new.avatar_key, '/', 2) <> new.user_id::text then
    raise exception 'avatar_key must be in your own folder' using errcode = '22023';
  end if;

  new.display_name := btrim(new.display_name);
  return new;
end;
$$;

create trigger a_profiles_guard
  before insert or update on public.profiles
  for each row execute function private.profiles_guard();

create trigger b_profiles_updated_at
  before update on public.profiles
  for each row execute function private.set_updated_at();

-- Column-level grants: birth_year and user_id are insert-only. No delete: accounts are removed by the deletion flow.
grant select on public.profiles to authenticated;
grant insert (user_id, display_name, avatar_key, stream, subjects, birth_year, is_discoverable, tz) on public.profiles to authenticated;
grant update (display_name, avatar_key, stream, subjects, is_discoverable, tz) on public.profiles to authenticated;

create policy profiles_select_own on public.profiles
  for select to authenticated
  using (user_id = (select auth.uid()));

create policy profiles_insert_own on public.profiles
  for insert to authenticated
  with check (user_id = (select auth.uid()));

create policy profiles_update_own on public.profiles
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

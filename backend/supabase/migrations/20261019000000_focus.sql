-- Phase 3: focus sessions, server-side validation, trees, streaks and achievements.
-- The client REPORTS a session; the server decides what counts. validated_s, counted, tree and received_at are computed in a trigger and
-- are not in any client grant. Rewards are computed here, never trusted from the app.
-- The rules mirror packages/core/tools/focus_reference.py; backend/supabase/tests/050_focus_rules.test.sql is generated from the SAME vectors.
-- Trigger functions that call other private functions are SECURITY DEFINER with an empty search_path, because API roles have no EXECUTE on `private`.

-- ---------------------------------------------------------------- pure rules
create or replace function private.focus_validated_seconds(p_planned integer, p_started timestamptz, p_ended timestamptz, p_paused integer, p_reported integer, p_received timestamptz)
returns integer
language sql
stable
set search_path = ''
as $$
  select case
    when p_ended <= p_started
      or p_ended > p_received + interval '300 seconds'
      or p_received - p_ended > interval '14 days' then 0
    else greatest(0, least(
      greatest(p_reported, 0)::bigint,
      x.el - least(greatest(p_paused, 0)::bigint, x.el),
      (p_planned + 300)::bigint,
      28800::bigint))::integer
  end
  from (select floor(extract(epoch from (p_ended - p_started)))::bigint as el) x;
$$;

create or replace function private.focus_is_counted(p_validated integer)
returns boolean language sql immutable set search_path = ''
as $$ select p_validated >= 300; $$;

create or replace function private.focus_tree_stage(p_validated integer)
returns text language sql immutable set search_path = ''
as $$
  select case when p_validated >= 3000 then 'grove' when p_validated >= 1500 then 'tree' when p_validated >= 900 then 'sapling' when p_validated >= 300 then 'seedling' else 'none' end;
$$;

create or replace function private.focus_day_met(p_days date[], p_secs integer[], p_day date, p_goal integer)
returns boolean language sql immutable set search_path = ''
as $$ select coalesce((select sum(t.s) from unnest(p_days, p_secs) as t(d, s) where t.d = p_day), 0) >= p_goal; $$;

-- Current streak of days that reached the goal, ending today (or yesterday while today is still open). A single unmet day between two met days
-- is a rest day: it neither breaks nor adds to the streak, and at most one rest day is allowed in any 7 consecutive days.
create or replace function private.focus_streak_from(p_days date[], p_secs integer[], p_today date, p_goal integer)
returns table (streak integer, rest_days integer)
language plpgsql
stable
set search_path = ''
as $$
declare
  d date;
  cnt integer := 0;
  rest integer := 0;
  last_forgiven date := null;
  guard integer := 0;
begin
  d := case when private.focus_day_met(p_days, p_secs, p_today, p_goal) then p_today else p_today - 1 end;
  loop
    guard := guard + 1;
    exit when guard > 4000;
    if private.focus_day_met(p_days, p_secs, d, p_goal) then
      cnt := cnt + 1;
    elsif private.focus_day_met(p_days, p_secs, d - 1, p_goal) and (last_forgiven is null or last_forgiven - d >= 7) then
      rest := rest + 1;
      last_forgiven := d;
    else
      exit;
    end if;
    d := d - 1;
  end loop;
  return query select cnt, rest;
end;
$$;

create or replace function private.focus_longest_streak_from(p_days date[], p_secs integer[], p_goal integer)
returns integer
language sql
stable
set search_path = ''
as $$
  select coalesce(max((select s.streak from private.focus_streak_from(p_days, p_secs, x.d, p_goal) s)), 0)
  from (select distinct u.d from unnest(p_days) as u(d)) x
  where private.focus_day_met(p_days, p_secs, x.d, p_goal);
$$;

create or replace function private.focus_achievements_for(p_sessions bigint, p_total bigint, p_longest integer)
returns text[] language sql immutable set search_path = ''
as $$
  select array_remove(array[
    case when p_sessions >= 1 then 'first_session' end,
    case when p_sessions >= 25 then 'sessions_25' end,
    case when p_total >= 36000 then 'hours_10' end,
    case when p_total >= 180000 then 'hours_50' end,
    case when p_longest >= 3 then 'streak_3' end,
    case when p_longest >= 7 then 'streak_7' end,
    case when p_longest >= 30 then 'streak_30' end
  ], null);
$$;

-- ---------------------------------------------------------------- study_sessions
create table public.study_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  client_uuid uuid not null,
  subject_id uuid,
  mode text not null default 'solo',
  planned_s integer not null,
  started_at timestamptz not null,
  ended_at timestamptz not null,
  paused_s integer not null default 0,
  client_reported_s integer not null,
  outcome text not null,
  received_at timestamptz not null default now(),
  validated_s integer not null default 0,
  counted boolean not null default false,
  tree text not null default 'none',
  created_at timestamptz not null default now(),
  constraint study_sessions_mode_chk check (mode = 'solo'),  -- Phase 3 group rooms add 'group'
  constraint study_sessions_planned_chk check (planned_s between 60 and 28800),
  constraint study_sessions_paused_chk check (paused_s between 0 and 28800),
  constraint study_sessions_reported_chk check (client_reported_s between 0 and 86400),
  constraint study_sessions_outcome_chk check (outcome in ('completed', 'ended_early', 'abandoned')),
  constraint study_sessions_tree_chk check (tree in ('none', 'seedling', 'sapling', 'tree', 'grove')),
  constraint study_sessions_client_unique unique (user_id, client_uuid),
  -- ON DELETE SET NULL with a column list needs PostgreSQL 15 or newer (verify on the Supabase image). A removed subject must not delete study history.
  constraint study_sessions_subject_fk foreign key (subject_id, user_id) references public.subjects (id, user_id) on delete set null (subject_id)
);
create index study_sessions_user_started_idx on public.study_sessions (user_id, started_at desc);
alter table public.study_sessions enable row level security;
alter table public.study_sessions force row level security;

create or replace function private.study_sessions_before_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.received_at := now();
  new.validated_s := private.focus_validated_seconds(new.planned_s, new.started_at, new.ended_at, new.paused_s, new.client_reported_s, new.received_at);
  new.counted := private.focus_is_counted(new.validated_s);
  new.tree := private.focus_tree_stage(new.validated_s);
  return new;
end;
$$;
create trigger a_study_sessions_before_insert before insert on public.study_sessions for each row execute function private.study_sessions_before_insert();

-- ---------------------------------------------------------------- achievements (written only by the server)
create table public.achievements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null,
  earned_at timestamptz not null default now(),
  constraint achievements_kind_chk check (kind in ('first_session', 'sessions_25', 'hours_10', 'hours_50', 'streak_3', 'streak_7', 'streak_30')),
  constraint achievements_user_kind_unique unique (user_id, kind)
);
alter table public.achievements enable row level security;
alter table public.achievements force row level security;

create or replace function private.focus_daily_totals(p_user uuid)
returns table (day date, secs integer)
language sql
stable
set search_path = ''
as $$
  select (s.started_at at time zone coalesce(p.tz, 'Asia/Colombo'))::date as day, sum(s.validated_s)::integer as secs
  from public.study_sessions s
  left join public.profiles p on p.user_id = s.user_id
  where s.user_id = p_user and s.counted
  group by 1;
$$;

create or replace function private.focus_award(p_user uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_sessions bigint;
  v_total bigint;
  v_days date[];
  v_secs integer[];
  v_longest integer;
begin
  select count(*), coalesce(sum(s.validated_s), 0) into v_sessions, v_total
  from public.study_sessions s where s.user_id = p_user and s.counted;
  select coalesce(array_agg(t.day order by t.day), '{}'), coalesce(array_agg(t.secs order by t.day), '{}') into v_days, v_secs
  from private.focus_daily_totals(p_user) t;
  v_longest := private.focus_longest_streak_from(v_days, v_secs, 1800);
  insert into public.achievements (user_id, kind)
  select p_user, k from unnest(private.focus_achievements_for(v_sessions, v_total, v_longest)) as k
  on conflict (user_id, kind) do nothing;
end;
$$;

create or replace function private.study_sessions_after_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.counted then
    perform private.focus_award(new.user_id);
  end if;
  return null;
end;
$$;
create trigger b_study_sessions_after_insert after insert on public.study_sessions for each row execute function private.study_sessions_after_insert();

-- ---------------------------------------------------------------- access
grant select on public.study_sessions to authenticated;
grant insert (user_id, client_uuid, subject_id, planned_s, started_at, ended_at, paused_s, client_reported_s, outcome) on public.study_sessions to authenticated;
grant select on public.achievements to authenticated;

create policy study_sessions_select_own on public.study_sessions for select to authenticated using (user_id = (select auth.uid()));
create policy study_sessions_insert_own on public.study_sessions for insert to authenticated with check (user_id = (select auth.uid()));
create policy achievements_select_own on public.achievements for select to authenticated using (user_id = (select auth.uid()));

-- The SECURITY DEFINER functions above run as the table owner (postgres). With FORCE ROW LEVEL SECURITY the owner is subject to policies
-- unless it has BYPASSRLS, so it gets explicit policies. They apply to the `postgres` role only, never to an API role.
-- policy-open-ok: the server's own award function must read all of one user's sessions (it filters by user id itself)
create policy study_sessions_server_read on public.study_sessions for select to postgres using (true);
-- policy-open-ok: the award function needs the user's time zone to group sessions into local days
create policy profiles_server_read on public.profiles for select to postgres using (true);
-- policy-open-ok: only the server's award function writes achievements
create policy achievements_server_write on public.achievements for insert to postgres with check (true);
-- policy-open-ok: the award function reads achievements to avoid duplicates (on conflict)
create policy achievements_server_read on public.achievements for select to postgres using (true);

-- Phase 7 & Enforcement: User roles, enforcement policies, violations, and overrides.
-- Enables supervised and voluntary anti-distraction study rules.
-- Forced Row Level Security on all tables.

-- 1. User Roles (RBAC for admin, teacher, parent, student)
create table public.user_roles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  role text not null default 'student',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint user_roles_role_chk check (role in ('admin', 'teacher', 'parent', 'student'))
);

alter table public.user_roles enable row level security;
alter table public.user_roles force row level security;

create trigger user_roles_updated_at_trg
  before update on public.user_roles
  for each row execute function private.set_updated_at();

-- Helper in private to check admin status
create or replace function private.is_admin(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.user_roles
    where user_id = p_user_id and role = 'admin'
  );
$$;

grant select on public.user_roles to authenticated;

create policy user_roles_select_own on public.user_roles
  for select to authenticated
  using (user_id = (select auth.uid()) or private.is_admin((select auth.uid())));

create policy user_roles_insert_own on public.user_roles
  for insert to authenticated
  with check (user_id = (select auth.uid()));

-- 2. Enforcement Policies (rules set by student, parent, or teacher)
create table public.enforcement_policies (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references auth.users (id) on delete cascade,
  creator_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  mode text not null,
  blocked_packages text[] not null default '{}',
  allowed_packages text[] not null default '{}',
  schedule_days integer[] not null default '{}',
  start_time time,
  end_time time,
  daily_limit_minutes integer not null default 0,
  allow_emergency_override boolean not null default true,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint enforcement_policies_mode_chk check (mode in ('focus_session_lock', 'scheduled_window', 'daily_limit', 'strict_kiosk')),
  constraint enforcement_policies_limit_chk check (daily_limit_minutes >= 0)
);

alter table public.enforcement_policies enable row level security;
alter table public.enforcement_policies force row level security;

create trigger enforcement_policies_updated_at_trg
  before update on public.enforcement_policies
  for each row execute function private.set_updated_at();

grant select, insert, update, delete on public.enforcement_policies to authenticated;

create policy enforcement_policies_select on public.enforcement_policies
  for select to authenticated
  using (
    student_id = (select auth.uid())
    or creator_id = (select auth.uid())
    or private.is_admin((select auth.uid()))
  );

create policy enforcement_policies_insert on public.enforcement_policies
  for insert to authenticated
  with check (
    creator_id = (select auth.uid())
    and (student_id = (select auth.uid()) or private.is_admin((select auth.uid())))
  );

create policy enforcement_policies_update on public.enforcement_policies
  for update to authenticated
  using (
    creator_id = (select auth.uid())
    or private.is_admin((select auth.uid()))
  )
  with check (
    creator_id = (select auth.uid())
    or private.is_admin((select auth.uid()))
  );

create policy enforcement_policies_delete on public.enforcement_policies
  for delete to authenticated
  using (
    creator_id = (select auth.uid())
    or private.is_admin((select auth.uid()))
  );

-- 3. Policy Violations (transparent audit log of distractions and breaches)
create table public.policy_violations (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references auth.users (id) on delete cascade,
  policy_id uuid references public.enforcement_policies (id) on delete set null,
  device_id text not null,
  package_name text not null,
  violation_type text not null,
  occurred_at timestamptz not null default now(),
  synced boolean not null default true,
  constraint policy_violations_type_chk check (
    violation_type in ('distraction_opened', 'schedule_breach', 'daily_limit_reached', 'session_aborted')
  )
);

alter table public.policy_violations enable row level security;
alter table public.policy_violations force row level security;

create index policy_violations_student_idx on public.policy_violations (student_id, occurred_at desc);

grant select, insert on public.policy_violations to authenticated;

create policy policy_violations_select on public.policy_violations
  for select to authenticated
  using (
    student_id = (select auth.uid())
    or private.is_admin((select auth.uid()))
    or exists (
      select 1 from public.enforcement_policies ep
      where ep.id = policy_violations.policy_id and ep.creator_id = (select auth.uid())
    )
  );

create policy policy_violations_insert on public.policy_violations
  for insert to authenticated
  with check (student_id = (select auth.uid()));

-- 4. Policy Overrides (emergency exceptions with mandatory reason)
create table public.policy_overrides (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references auth.users (id) on delete cascade,
  policy_id uuid references public.enforcement_policies (id) on delete set null,
  reason text not null,
  duration_minutes integer not null default 15,
  created_at timestamptz not null default now(),
  constraint policy_overrides_duration_chk check (duration_minutes between 1 and 120),
  constraint policy_overrides_reason_len check (length(trim(reason)) >= 3)
);

alter table public.policy_overrides enable row level security;
alter table public.policy_overrides force row level security;

create index policy_overrides_student_idx on public.policy_overrides (student_id, created_at desc);

grant select, insert on public.policy_overrides to authenticated;

create policy policy_overrides_select on public.policy_overrides
  for select to authenticated
  using (
    student_id = (select auth.uid())
    or private.is_admin((select auth.uid()))
    or exists (
      select 1 from public.enforcement_policies ep
      where ep.id = policy_overrides.policy_id and ep.creator_id = (select auth.uid())
    )
  );

create policy policy_overrides_insert on public.policy_overrides
  for insert to authenticated
  with check (student_id = (select auth.uid()));

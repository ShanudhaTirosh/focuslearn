-- Migration: 20261125000100_classrooms_teacher.sql
-- Description: Teacher dashboards, Classrooms, Student Enrollment, Homework and Learning Goals.
-- Forced Row Level Security on all tables.

-- 1. Helper function in private schema to check student enrollment
create or replace function private.is_enrolled_in_classroom(p_student_id uuid, p_classroom_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.classroom_students cs
    where cs.classroom_id = p_classroom_id
      and cs.child_id = p_student_id
      and cs.status = 'active'
  );
$$;

create or replace function private.is_classroom_teacher(p_teacher_id uuid, p_classroom_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.classrooms c
    where c.id = p_classroom_id
      and c.teacher_id = p_teacher_id
  );
$$;

-- 2. Classrooms (Created and managed by teachers)
create table public.classrooms (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid not null references auth.users (id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 100),
  subject text check (subject is null or char_length(subject) <= 100),
  school_name text check (school_name is null or char_length(school_name) <= 120),
  invite_code text unique check (invite_code is null or char_length(invite_code) = 6),
  invite_expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.classrooms enable row level security;
alter table public.classrooms force row level security;

create trigger classrooms_updated_at_trg
  before update on public.classrooms
  for each row execute function private.set_updated_at();

create index classrooms_teacher_id_idx on public.classrooms (teacher_id);
create index classrooms_invite_code_idx on public.classrooms (invite_code) where invite_code is not null;

grant select, insert, update, delete on public.classrooms to authenticated;

create policy classrooms_select on public.classrooms
  for select to authenticated
  using (
    teacher_id = (select auth.uid())
    or private.is_enrolled_in_classroom((select auth.uid()), id)
  );

create policy classrooms_insert on public.classrooms
  for insert to authenticated
  with check (teacher_id = (select auth.uid()));

create policy classrooms_update on public.classrooms
  for update to authenticated
  using (teacher_id = (select auth.uid()))
  with check (teacher_id = (select auth.uid()));

create policy classrooms_delete on public.classrooms
  for delete to authenticated
  using (teacher_id = (select auth.uid()));

-- 3. Classroom Students (Membership with parent consent audit)
create table public.classroom_students (
  id uuid primary key default gen_random_uuid(),
  classroom_id uuid not null references public.classrooms (id) on delete cascade,
  child_id uuid not null references auth.users (id) on delete cascade,
  enrolled_by_parent_id uuid references auth.users (id) on delete set null,
  status text not null default 'active' check (status in ('active', 'removed')),
  joined_at timestamptz not null default now(),
  constraint classroom_students_unique unique (classroom_id, child_id)
);

alter table public.classroom_students enable row level security;
alter table public.classroom_students force row level security;

create index classroom_students_class_idx on public.classroom_students (classroom_id);
create index classroom_students_child_idx on public.classroom_students (child_id);

grant select, insert, update, delete on public.classroom_students to authenticated;

create policy classroom_students_select on public.classroom_students
  for select to authenticated
  using (
    child_id = (select auth.uid())
    or enrolled_by_parent_id = (select auth.uid())
    or private.is_classroom_teacher((select auth.uid()), classroom_id)
  );

create policy classroom_students_insert on public.classroom_students
  for insert to authenticated
  with check (
    child_id = (select auth.uid())
    or enrolled_by_parent_id = (select auth.uid())
    or private.is_classroom_teacher((select auth.uid()), classroom_id)
  );

create policy classroom_students_update on public.classroom_students
  for update to authenticated
  using (
    private.is_classroom_teacher((select auth.uid()), classroom_id)
    or enrolled_by_parent_id = (select auth.uid())
  )
  with check (
    private.is_classroom_teacher((select auth.uid()), classroom_id)
    or enrolled_by_parent_id = (select auth.uid())
  );

create policy classroom_students_delete on public.classroom_students
  for delete to authenticated
  using (
    private.is_classroom_teacher((select auth.uid()), classroom_id)
    or enrolled_by_parent_id = (select auth.uid())
  );

-- 4. Homework Assignments (Created by teacher for classroom)
create table public.homework (
  id uuid primary key default gen_random_uuid(),
  classroom_id uuid not null references public.classrooms (id) on delete cascade,
  teacher_id uuid not null references auth.users (id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 1 and 150),
  description text,
  due_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.homework enable row level security;
alter table public.homework force row level security;

create trigger homework_updated_at_trg
  before update on public.homework
  for each row execute function private.set_updated_at();

create index homework_class_idx on public.homework (classroom_id);

grant select, insert, update, delete on public.homework to authenticated;

create policy homework_select on public.homework
  for select to authenticated
  using (
    teacher_id = (select auth.uid())
    or private.is_enrolled_in_classroom((select auth.uid()), classroom_id)
  );

create policy homework_insert on public.homework
  for insert to authenticated
  with check (
    teacher_id = (select auth.uid())
    and private.is_classroom_teacher((select auth.uid()), classroom_id)
  );

create policy homework_update on public.homework
  for update to authenticated
  using (teacher_id = (select auth.uid()))
  with check (teacher_id = (select auth.uid()));

create policy homework_delete on public.homework
  for delete to authenticated
  using (teacher_id = (select auth.uid()));

-- 5. Learning Goals (Individual goals set with student/teacher)
create table public.learning_goals (
  id uuid primary key default gen_random_uuid(),
  classroom_id uuid not null references public.classrooms (id) on delete cascade,
  child_id uuid not null references auth.users (id) on delete cascade,
  teacher_id uuid not null references auth.users (id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 1 and 150),
  target_date date,
  status text not null default 'active' check (status in ('active', 'achieved', 'cancelled')),
  created_at timestamptz not null default now()
);

alter table public.learning_goals enable row level security;
alter table public.learning_goals force row level security;

create index learning_goals_child_idx on public.learning_goals (child_id);
create index learning_goals_class_idx on public.learning_goals (classroom_id);

grant select, insert, update, delete on public.learning_goals to authenticated;

create policy learning_goals_select on public.learning_goals
  for select to authenticated
  using (
    child_id = (select auth.uid())
    or teacher_id = (select auth.uid())
  );

create policy learning_goals_insert on public.learning_goals
  for insert to authenticated
  with check (
    teacher_id = (select auth.uid())
    or child_id = (select auth.uid())
  );

create policy learning_goals_update on public.learning_goals
  for update to authenticated
  using (
    teacher_id = (select auth.uid())
    or child_id = (select auth.uid())
  )
  with check (
    teacher_id = (select auth.uid())
    or child_id = (select auth.uid())
  );

create policy learning_goals_delete on public.learning_goals
  for delete to authenticated
  using (teacher_id = (select auth.uid()));

-- ==============================================================================
-- Migration: Parent and Teacher RLS Access to Student Profiles, Sessions, and Violations
-- ==============================================================================

-- 1. Profiles: allow parents to read linked children and teachers to read enrolled students
create policy profiles_parent_select on public.profiles
  for select to authenticated
  using (
    exists (
      select 1 from public.parent_child_links pcl
      where pcl.child_id = profiles.user_id
        and pcl.parent_id = (select auth.uid())
    )
  );

create policy profiles_teacher_select on public.profiles
  for select to authenticated
  using (
    exists (
      select 1 from public.classroom_students cs
      join public.classrooms c on c.id = cs.classroom_id
      where cs.student_id = profiles.user_id
        and c.teacher_id = (select auth.uid())
    )
  );

-- 2. Study Sessions: allow parents and teachers to view study logs
create policy study_sessions_parent_select on public.study_sessions
  for select to authenticated
  using (
    exists (
      select 1 from public.parent_child_links pcl
      where pcl.child_id = study_sessions.user_id
        and pcl.parent_id = (select auth.uid())
    )
  );

create policy study_sessions_teacher_select on public.study_sessions
  for select to authenticated
  using (
    exists (
      select 1 from public.classroom_students cs
      join public.classrooms c on c.id = cs.classroom_id
      where cs.student_id = study_sessions.user_id
        and c.teacher_id = (select auth.uid())
    )
  );

-- 3. Policy Violations & Overrides: allow parents to monitor distraction attempts & emergencies
create policy policy_violations_parent_select on public.policy_violations
  for select to authenticated
  using (
    exists (
      select 1 from public.parent_child_links pcl
      where pcl.child_id = policy_violations.student_id
        and pcl.parent_id = (select auth.uid())
    )
  );

create policy policy_overrides_parent_select on public.policy_overrides
  for select to authenticated
  using (
    exists (
      select 1 from public.parent_child_links pcl
      where pcl.child_id = policy_overrides.student_id
        and pcl.parent_id = (select auth.uid())
    )
  );

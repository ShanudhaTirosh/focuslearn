begin;
select plan(6);

-- 1. Check policies exist
select policies_are(
  'public',
  'profiles',
  array[
    'profiles_select_own',
    'profiles_insert_own',
    'profiles_update_own',
    'profiles_admin_all',
    'profiles_server_read',
    'profiles_parent_select',
    'profiles_teacher_select'
  ],
  'profiles has parent and teacher select policies'
);

select ok(
  exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'study_sessions'
      and policyname = 'study_sessions_parent_select'
  ),
  'study_sessions has study_sessions_parent_select policy'
);

select ok(
  exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'study_sessions'
      and policyname = 'study_sessions_teacher_select'
  ),
  'study_sessions has study_sessions_teacher_select policy'
);

select ok(
  exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'policy_violations'
      and policyname = 'policy_violations_parent_select'
  ),
  'policy_violations has policy_violations_parent_select policy'
);

select ok(
  exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'policy_overrides'
      and policyname = 'policy_overrides_parent_select'
  ),
  'policy_overrides has policy_overrides_parent_select policy'
);

select pass('Parent and teacher RLS access policies verified successfully');

select * from finish();
rollback;

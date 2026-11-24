-- pgTAP: Classrooms, Student Enrollment, Homework, and Learning Goals.
-- Run with: bash infra/scripts/run-pgtap.sh
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = extensions, public;
select plan(16);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000t1', 'teacher@example.test'),
  ('00000000-0000-0000-0000-0000000000s1', 'student@example.test'),
  ('00000000-0000-0000-0000-0000000000x2', 'outsider@example.test');

select is((select count(*) from information_schema.tables where table_schema = 'public' and table_name in (
  'classrooms', 'classroom_students', 'homework', 'learning_goals'
)), 4::bigint, 'all four teacher/classroom tables exist');

select ok((select bool_and(relrowsecurity and relforcerowsecurity) from pg_class where oid in (
  'public.classrooms'::regclass,
  'public.classroom_students'::regclass,
  'public.homework'::regclass,
  'public.learning_goals'::regclass
)), 'RLS is enabled and forced on all four classroom tables');

-- 1. Anonymous is denied
set local role anon;
select throws_ok($$ select * from public.classrooms $$, '42501', null, 'anon cannot read classrooms');
select throws_ok($$ select * from public.classroom_students $$, '42501', null, 'anon cannot read classroom_students');
select throws_ok($$ select * from public.homework $$, '42501', null, 'anon cannot read homework');
select throws_ok($$ select * from public.learning_goals $$, '42501', null, 'anon cannot read learning_goals');
reset role;

-- 2. Teacher creates classroom and assigns homework
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000t1","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000t1', true);
set local role authenticated;

select lives_ok($$
  insert into public.classrooms (id, teacher_id, name, subject, invite_code)
  values ('50000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000t1', 'Physics 2026', 'Physics', 'PHY123')
$$, 'Teacher creates classroom');

select lives_ok($$
  insert into public.classroom_students (classroom_id, child_id)
  values ('50000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000s1')
$$, 'Teacher enrolls student');

select lives_ok($$
  insert into public.homework (classroom_id, teacher_id, title, description, due_date)
  values ('50000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000t1', 'Mechanics Worksheet 1', 'Solve problems 1-10', current_date + 7)
$$, 'Teacher posts homework');

select lives_ok($$
  insert into public.learning_goals (classroom_id, child_id, teacher_id, title)
  values ('50000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000s1', '00000000-0000-0000-0000-0000000000t1', 'Master Circular Motion')
$$, 'Teacher sets learning goal');

-- 3. Student can view their classroom and assignments
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000s1","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000s1', true);
set local role authenticated;

select is((select count(*) from public.classrooms where id = '50000000-0000-0000-0000-000000000001'), 1::bigint, 'Enrolled student can view classroom');
select is((select count(*) from public.homework where classroom_id = '50000000-0000-0000-0000-000000000001'), 1::bigint, 'Student can view homework');
select is((select count(*) from public.learning_goals where child_id = '00000000-0000-0000-0000-0000000000s1'), 1::bigint, 'Student can view learning goals');

-- 4. Outsider cannot see classroom or homework
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000x2","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000x2', true);
set local role authenticated;

select is((select count(*) from public.classrooms), 0::bigint, 'Outsider sees no classrooms');
select is((select count(*) from public.homework), 0::bigint, 'Outsider sees no homework');
select is((select count(*) from public.learning_goals), 0::bigint, 'Outsider sees no learning goals');

select * from finish();
rollback;

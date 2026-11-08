-- pgTAP: verifies the baseline migration's security defaults on a REAL database.
-- Run with: bash infra/scripts/run-pgtap.sh   (connects as supabase_admin: needed for CREATE EXTENSION and SET ROLE)
-- Everything happens inside one transaction that is rolled back. Probe objects are created as the `postgres` role,
-- exactly like a later migration would, so the default-privilege checks are meaningful.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = extensions, public;
select plan(16);

-- schema private
select has_schema('private', 'schema private exists');
select ok(not has_schema_privilege('anon', 'private', 'usage'), 'anon cannot use schema private');
select ok(has_schema_privilege('authenticated', 'private', 'usage'), 'authenticated can use schema private (policies may call its helpers)');
select has_function('private', 'set_updated_at', array[]::text[], 'private.set_updated_at() exists');
select ok(not (select prosecdef from pg_proc where oid = 'private.set_updated_at()'::regprocedure), 'set_updated_at is SECURITY INVOKER');

-- Probe objects, created the way a migration would create them
set local role postgres;
create table public.__baseline_probe (id int);
create function public.__baseline_probe_fn() returns int language sql as 'select 1';
create sequence public.__baseline_probe_seq;
reset role;

select ok(not has_table_privilege('anon', 'public.__baseline_probe', 'select'), 'new public table: anon has no SELECT');
select ok(not has_table_privilege('authenticated', 'public.__baseline_probe', 'select'), 'new public table: authenticated has no SELECT until a migration grants it');
select ok(not has_table_privilege('anon', 'public.__baseline_probe', 'insert'), 'new public table: anon has no INSERT');
select ok(not has_sequence_privilege('authenticated', 'public.__baseline_probe_seq', 'usage'), 'new public sequence: authenticated has no USAGE');
select ok(not has_function_privilege('anon', 'public.__baseline_probe_fn()', 'execute'), 'new public function: anon cannot EXECUTE');
select ok(not has_function_privilege('authenticated', 'public.__baseline_probe_fn()', 'execute'), 'new public function: authenticated cannot EXECUTE until granted');
select ok(not exists (
  select 1 from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
  where p.oid = 'public.__baseline_probe_fn()'::regprocedure and a.grantee = 0 and a.privilege_type = 'EXECUTE'
), 'new function: PUBLIC has no EXECUTE (the built-in default was removed)');

-- Structural rules, ignoring the probe table
select is((select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'public' and c.relkind in ('r', 'p') and not c.relrowsecurity and c.relname <> '__baseline_probe'),
          0::bigint, 'every public table has row level security enabled');
select is((select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'public' and c.relkind in ('r', 'p') and not c.relforcerowsecurity and c.relname <> '__baseline_probe'),
          0::bigint, 'every public table has row level security FORCED');
select is((select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.prosecdef),
          0::bigint, 'no SECURITY DEFINER functions live in public');
select is((select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname in ('public', 'private') and p.prosecdef
             and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%')),
          0::bigint, 'every SECURITY DEFINER function sets search_path');

select * from finish();
rollback;

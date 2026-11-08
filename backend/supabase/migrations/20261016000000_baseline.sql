-- FocusLearn baseline: secure defaults only. No application tables.
-- Applied by infra/scripts/migrate.sh as the `postgres` role, inside one transaction (do not add begin/commit).
-- Every statement is idempotent so a re-run on an already-initialised database is harmless.

-- 1. A schema for helper functions that must NOT be callable through the API.
--    PostgREST exposes only the schemas it is configured with (public and graphql_public by default): `private` is not one of them.
create schema if not exists private;
revoke all on schema private from public;
revoke all on schema private from anon;
grant usage on schema private to authenticated, service_role;

-- 2. Deny by default. Supabase's initial setup grants the API roles everything on future objects in `public`.
--    Remove that for tables, sequences and functions: every later migration must GRANT exactly what its policies need.
--    Schema-scoped entries (IN SCHEMA) can be revoked per schema:
alter default privileges for role postgres in schema public revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema public revoke all on sequences from anon, authenticated;
alter default privileges for role postgres in schema public revoke all on functions from anon, authenticated;
--    But PostgreSQL itself grants EXECUTE on every new function to PUBLIC. That built-in default can only be removed with the
--    GLOBAL form (no IN SCHEMA). Without this line a SECURITY DEFINER function would be callable by anon through the REST API.
alter default privileges for role postgres revoke execute on functions from public;

-- 3. Shared trigger function for updated_at columns. SECURITY INVOKER, empty search_path, lives in `private`.
create or replace function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

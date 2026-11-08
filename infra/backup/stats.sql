-- Prints ONE line of JSON describing the database: version, public tables without RLS, exact row counts for public and auth tables.
-- Run with: psql -At -f stats.sql . Used before and after each dump, and again on the restored copy.
select json_build_object(
  'pg_version', current_setting('server_version'),
  'taken_at', to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
  'public_tables_without_rls', (
    select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p') and not c.relrowsecurity
  ),
  'row_counts', coalesce((
    select json_object_agg(
      table_schema || '.' || table_name,
      (xpath('/row/c/text()',
             query_to_xml(format('select count(*) as c from %I.%I', table_schema, table_name), false, true, '')))[1]::text::bigint)
    from information_schema.tables
    where table_type = 'BASE TABLE' and table_schema in ('public', 'auth')
  ), '{}'::json)
)::text;

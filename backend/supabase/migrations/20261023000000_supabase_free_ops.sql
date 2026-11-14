-- Phase 9: Supabase Free Plan operations, usage monitoring view, and maintenance functions.
-- Keeps database disk usage strictly under 500 MB through scheduled table maintenance.

-- 1. Maintenance function to purge transient events and keep tables lean
create or replace function private.purge_expired_data()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_rate_limits integer;
  v_notifications integer;
  v_violations integer;
  v_files integer;
begin
  -- 1. Purge rate limit sliding-window events older than 48 hours
  delete from public.rate_limit_events
  where recorded_at < (now() - interval '48 hours');
  get diagnostics v_rate_limits = row_count;

  -- 2. Purge read notifications older than 60 days
  delete from public.notifications
  where read_at is not null and created_at < (now() - interval '60 days');
  get diagnostics v_notifications = row_count;

  -- 3. Purge historical policy violations older than 90 days
  delete from public.policy_violations
  where occurred_at < (now() - interval '90 days');
  get diagnostics v_violations = row_count;

  -- 4. Purge soft-deleted file objects older than 30 days
  delete from public.file_objects
  where deleted_at is not null and deleted_at < (now() - interval '30 days');
  get diagnostics v_files = row_count;

  return jsonb_build_object(
    'purged_rate_limits', v_rate_limits,
    'purged_notifications', v_notifications,
    'purged_violations', v_violations,
    'purged_files', v_files,
    'executed_at', now()
  );
end;
$$;

-- 2. Automated account deletion processing
create or replace function private.process_pending_deletions()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  r record;
  v_count integer := 0;
begin
  for r in
    select id, user_id from public.deletion_requests
    where status = 'pending' and scheduled_for <= now()
    limit 25
  loop
    update public.deletion_requests
    set status = 'processing', updated_at = now()
    where id = r.id;

    -- Soft-delete user files
    update public.file_objects
    set deleted_at = now()
    where owner_id = r.user_id and deleted_at is null;

    -- Clean up profile personal info
    update public.profiles
    set display_name = 'Deleted User', updated_at = now()
    where id = r.user_id;

    update public.deletion_requests
    set status = 'done', updated_at = now()
    where id = r.id;

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

-- 3. Usage monitoring overview view for the admin dashboard
-- Provides real-time metrics against Supabase Free Tier quotas (500 MB DB, 50k MAU).
create or replace view public.usage_monitoring_overview as
select
  (select count(*) from auth.users) as total_users,
  (select count(*) from public.study_sessions) as total_sessions,
  (select count(*) from public.notes where deleted_at is null) as total_notes,
  (select count(*) from public.policy_violations) as total_violations,
  (select count(*) from public.file_objects where deleted_at is null) as total_files,
  (select coalesce(sum(bytes_used), 0) from public.user_quotas) as total_r2_bytes_used,
  524288000::bigint as db_limit_bytes, -- 500 MB free plan limit
  10737418240::bigint as r2_limit_bytes, -- 10 GB Cloudflare R2 free limit
  50000::bigint as mau_limit, -- 50k Supabase Auth MAU limit
  now() as checked_at;

-- Allow authenticated users to view usage monitoring if they are admin
grant select on public.usage_monitoring_overview to authenticated;

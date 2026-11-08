-- Phase 1: account deletion requests. The user asks, waits a grace period, may cancel; a server job (a later phase) does the deleting.
-- Deliberately NO foreign key to auth.users: when the account is finally removed the row stays as a minimal tombstone (a random uuid only).

create table public.deletion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid(),
  status text not null default 'pending',
  requested_at timestamptz not null default now(),
  scheduled_for timestamptz not null default (now() + interval '7 days'),
  cancelled_at timestamptz,
  constraint deletion_requests_status_chk check (status in ('pending', 'cancelled', 'processing', 'done'))
);
create unique index deletion_requests_one_active on public.deletion_requests (user_id) where status in ('pending', 'processing');

alter table public.deletion_requests enable row level security;
alter table public.deletion_requests force row level security;

create or replace function private.deletion_requests_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.user_id is distinct from old.user_id or new.scheduled_for is distinct from old.scheduled_for or new.requested_at is distinct from old.requested_at then
    raise exception 'only the status can change' using errcode = '42501';
  end if;
  if new.status is distinct from old.status then
    if old.status = 'pending' and new.status = 'cancelled' then
      new.cancelled_at := now();
    elsif old.status = 'pending' and new.status = 'processing' then
      null;  -- the server job (service role) starts processing after scheduled_for
    elsif old.status = 'processing' and new.status = 'done' then
      null;
    else
      raise exception 'invalid status change % -> %', old.status, new.status using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

create trigger deletion_requests_guard_trg
  before update on public.deletion_requests
  for each row execute function private.deletion_requests_guard();

grant select on public.deletion_requests to authenticated;
grant insert (user_id) on public.deletion_requests to authenticated;
grant update (status) on public.deletion_requests to authenticated;

create policy deletion_requests_select_own on public.deletion_requests
  for select to authenticated using (user_id = (select auth.uid()));
create policy deletion_requests_insert_own on public.deletion_requests
  for insert to authenticated with check (user_id = (select auth.uid()));
-- The user may only cancel their own pending request. Moving to processing or done is done by the server job (service role bypasses RLS).
create policy deletion_requests_cancel_own on public.deletion_requests
  for update to authenticated
  using (user_id = (select auth.uid()) and status = 'pending')
  with check (user_id = (select auth.uid()) and status = 'cancelled');

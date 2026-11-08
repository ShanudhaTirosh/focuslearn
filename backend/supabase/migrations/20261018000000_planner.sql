-- Phase 2: subjects, topics, timetable events (with recurrence and per-occurrence exceptions), assignments.
-- Owner-only for now (group visibility arrives with Phase 4 in a new migration).
-- Clients generate the row ids (so a device can create an event and its recurrence while offline), hence `id` is in the insert grants.
-- Clients never hard-delete: `deleted_at` is a tombstone so that offline devices can synchronise deletions.
-- Client rules mirror these constraints and may be stricter, never looser (packages/core/tools/test_planner_contract.py checks the patterns).

-- ---------------------------------------------------------------- subjects
create table public.subjects (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null,
  color text not null default 'primary',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint subjects_name_chk check (char_length(btrim(name)) between 1 and 60 and name !~ '[[:cntrl:]]'),
  constraint subjects_color_chk check (color in ('primary', 'secondary', 'success', 'warning', 'error', 'info')),
  constraint subjects_id_user_unique unique (id, user_id)
);
create unique index subjects_user_name_idx on public.subjects (user_id, lower(btrim(name))) where deleted_at is null;
create index subjects_user_updated_idx on public.subjects (user_id, updated_at);
alter table public.subjects enable row level security;
alter table public.subjects force row level security;
create trigger subjects_updated_at before update on public.subjects for each row execute function private.set_updated_at();
grant select on public.subjects to authenticated;
grant insert (id, user_id, name, color) on public.subjects to authenticated;
grant update (name, color, deleted_at) on public.subjects to authenticated;
create policy subjects_select_own on public.subjects for select to authenticated using (user_id = (select auth.uid()));
create policy subjects_insert_own on public.subjects for insert to authenticated with check (user_id = (select auth.uid()));
create policy subjects_update_own on public.subjects for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- ---------------------------------------------------------------- topics
create table public.topics (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  subject_id uuid not null,
  name text not null,
  position integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint topics_name_chk check (char_length(btrim(name)) between 1 and 80 and name !~ '[[:cntrl:]]'),
  constraint topics_position_chk check (position between 0 and 10000),
  -- Composite foreign key: a topic can only point at a subject of the SAME user.
  constraint topics_subject_fk foreign key (subject_id, user_id) references public.subjects (id, user_id) on delete cascade,
  constraint topics_id_user_unique unique (id, user_id)
);
create index topics_user_updated_idx on public.topics (user_id, updated_at);
alter table public.topics enable row level security;
alter table public.topics force row level security;
create trigger topics_updated_at before update on public.topics for each row execute function private.set_updated_at();
grant select on public.topics to authenticated;
grant insert (id, user_id, subject_id, name, position) on public.topics to authenticated;
grant update (name, position, deleted_at) on public.topics to authenticated;
create policy topics_select_own on public.topics for select to authenticated using (user_id = (select auth.uid()));
create policy topics_insert_own on public.topics for insert to authenticated with check (user_id = (select auth.uid()));
create policy topics_update_own on public.topics for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- ---------------------------------------------------------------- timetable_events
create table public.timetable_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  subject_id uuid,
  topic_id uuid,
  title text not null,
  category text not null default 'study',
  visibility text not null default 'personal',
  start_utc timestamptz not null,
  end_utc timestamptz not null,
  iana_tz text not null default 'Asia/Colombo',
  meeting_url text,
  location text,
  notes text,
  reminder_offsets integer[] not null default '{10}',
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint events_title_chk check (char_length(btrim(title)) between 1 and 80 and title !~ '[[:cntrl:]]'),
  constraint events_category_chk check (category in ('study', 'revision', 'homework', 'break', 'online_class')),
  constraint events_visibility_chk check (visibility = 'personal'),  -- Phase 4 adds 'group'
  constraint events_time_chk check (end_utc > start_utc and (end_utc - start_utc) <= interval '24 hours'),
  constraint events_meeting_url_chk check (meeting_url is null or (char_length(meeting_url) <= 500 and meeting_url ~ '^https://[a-z0-9.-]+(:[0-9]{1,5})?(/[^[:space:][:cntrl:]]*)?$')),
  constraint events_location_chk check (location is null or (char_length(location) <= 120 and location !~ '[[:cntrl:]]')),
  constraint events_notes_chk check (notes is null or char_length(notes) <= 2000),
  constraint events_reminders_chk check (cardinality(reminder_offsets) <= 5 and 0 <= all (reminder_offsets) and 10080 >= all (reminder_offsets)),
  constraint events_subject_fk foreign key (subject_id, user_id) references public.subjects (id, user_id) on delete cascade,
  constraint events_topic_fk foreign key (topic_id, user_id) references public.topics (id, user_id) on delete cascade,
  constraint events_id_user_unique unique (id, user_id)
);
create index events_user_start_idx on public.timetable_events (user_id, start_utc) where deleted_at is null;
create index events_user_updated_idx on public.timetable_events (user_id, updated_at);
alter table public.timetable_events enable row level security;
alter table public.timetable_events force row level security;

create or replace function private.timetable_events_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not exists (select 1 from pg_catalog.pg_timezone_names where name = new.iana_tz) then
    raise exception 'unknown time zone' using errcode = '22023';
  end if;
  new.title := btrim(new.title);
  return new;
end;
$$;
create trigger a_events_guard before insert or update on public.timetable_events for each row execute function private.timetable_events_guard();
create trigger b_events_updated_at before update on public.timetable_events for each row execute function private.set_updated_at();
grant select on public.timetable_events to authenticated;
grant insert (id, user_id, subject_id, topic_id, title, category, start_utc, end_utc, iana_tz, meeting_url, location, notes, reminder_offsets, completed_at) on public.timetable_events to authenticated;
grant update (subject_id, topic_id, title, category, start_utc, end_utc, iana_tz, meeting_url, location, notes, reminder_offsets, completed_at, deleted_at) on public.timetable_events to authenticated;
create policy events_select_own on public.timetable_events for select to authenticated using (user_id = (select auth.uid()));
create policy events_insert_own on public.timetable_events for insert to authenticated with check (user_id = (select auth.uid()));
create policy events_update_own on public.timetable_events for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- ---------------------------------------------------------------- event_recurrences (one rule per event)
-- The rule is stored in canonical form (the client serialises it). Cross-field rules are separate constraints.
create table public.event_recurrences (
  event_id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  rrule text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint event_recurrences_event_fk foreign key (event_id, user_id) references public.timetable_events (id, user_id) on delete cascade,
  constraint event_recurrences_rrule_chk check (char_length(rrule) <= 200 and rrule ~ '^FREQ=(DAILY|WEEKLY|MONTHLY)(;INTERVAL=[1-9][0-9]{0,2})?(;BYDAY=(MO|TU|WE|TH|FR|SA|SU)(,(MO|TU|WE|TH|FR|SA|SU)){0,6})?(;BYMONTHDAY=(-1|[1-9]|[12][0-9]|3[01])(,(-1|[1-9]|[12][0-9]|3[01])){0,30})?(;COUNT=([1-9][0-9]{0,2}|1000))?(;UNTIL=[0-9]{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])T([01][0-9]|2[0-3])[0-5][0-9][0-5][0-9]Z)?$'),
  constraint event_recurrences_count_until_chk check (not (rrule ~ ';COUNT=' and rrule ~ ';UNTIL=')),
  constraint event_recurrences_byday_chk check (rrule !~ ';BYDAY=' or rrule ~ '^FREQ=WEEKLY'),
  constraint event_recurrences_bymonthday_chk check (rrule !~ ';BYMONTHDAY=' or rrule ~ '^FREQ=MONTHLY')
);
alter table public.event_recurrences enable row level security;
alter table public.event_recurrences force row level security;
create trigger event_recurrences_updated_at before update on public.event_recurrences for each row execute function private.set_updated_at();
grant select on public.event_recurrences to authenticated;
grant insert (event_id, user_id, rrule) on public.event_recurrences to authenticated;
grant update (rrule) on public.event_recurrences to authenticated;
create policy event_recurrences_select_own on public.event_recurrences for select to authenticated using (user_id = (select auth.uid()));
create policy event_recurrences_insert_own on public.event_recurrences for insert to authenticated with check (user_id = (select auth.uid()));
create policy event_recurrences_update_own on public.event_recurrences for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- ---------------------------------------------------------------- event_exceptions (edit or skip ONE occurrence)
create table public.event_exceptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  event_id uuid not null,
  original_start_utc timestamptz not null,
  kind text not null,
  new_start_utc timestamptz,
  new_end_utc timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint event_exceptions_event_fk foreign key (event_id, user_id) references public.timetable_events (id, user_id) on delete cascade,
  constraint event_exceptions_kind_chk check (kind in ('skip', 'override')),
  constraint event_exceptions_fields_chk check (
    (kind = 'skip' and new_start_utc is null and new_end_utc is null)
    or (kind = 'override' and ((new_start_utc is null) = (new_end_utc is null)) and (new_start_utc is null or new_end_utc > new_start_utc))
  ),
  constraint event_exceptions_occurrence_unique unique (event_id, original_start_utc)
);
create index event_exceptions_user_updated_idx on public.event_exceptions (user_id, updated_at);
alter table public.event_exceptions enable row level security;
alter table public.event_exceptions force row level security;
create trigger event_exceptions_updated_at before update on public.event_exceptions for each row execute function private.set_updated_at();
grant select on public.event_exceptions to authenticated;
grant insert (id, user_id, event_id, original_start_utc, kind, new_start_utc, new_end_utc, completed_at) on public.event_exceptions to authenticated;
grant update (kind, new_start_utc, new_end_utc, completed_at, deleted_at) on public.event_exceptions to authenticated;
create policy event_exceptions_select_own on public.event_exceptions for select to authenticated using (user_id = (select auth.uid()));
create policy event_exceptions_insert_own on public.event_exceptions for insert to authenticated with check (user_id = (select auth.uid()));
create policy event_exceptions_update_own on public.event_exceptions for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- ---------------------------------------------------------------- assignments
create table public.assignments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  subject_id uuid,
  title text not null,
  due_utc timestamptz not null,
  status text not null default 'todo',
  notes text,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint assignments_title_chk check (char_length(btrim(title)) between 1 and 120 and title !~ '[[:cntrl:]]'),
  constraint assignments_status_chk check (status in ('todo', 'doing', 'done')),
  constraint assignments_notes_chk check (notes is null or char_length(notes) <= 2000),
  constraint assignments_subject_fk foreign key (subject_id, user_id) references public.subjects (id, user_id) on delete cascade
);
create index assignments_user_due_idx on public.assignments (user_id, due_utc) where deleted_at is null;
create index assignments_user_updated_idx on public.assignments (user_id, updated_at);
alter table public.assignments enable row level security;
alter table public.assignments force row level security;
create trigger assignments_updated_at before update on public.assignments for each row execute function private.set_updated_at();
grant select on public.assignments to authenticated;
grant insert (id, user_id, subject_id, title, due_utc, status, notes, completed_at) on public.assignments to authenticated;
grant update (subject_id, title, due_utc, status, notes, completed_at, deleted_at) on public.assignments to authenticated;
create policy assignments_select_own on public.assignments for select to authenticated using (user_id = (select auth.uid()));
create policy assignments_insert_own on public.assignments for insert to authenticated with check (user_id = (select auth.uid()));
create policy assignments_update_own on public.assignments for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

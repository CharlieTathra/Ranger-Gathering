-- ============================================================
-- Ngarringilanha Ranger Gathering — photo reports
--
-- A way for anyone at the Gathering to flag a photo that breaches
-- cultural protocol: ceremony, restricted or sacred places, a person
-- who did not agree, or a person who has passed away.
--
-- A reported photo disappears from the album immediately, before any
-- review happens. That is deliberate. A photo wrongly hidden for a day
-- costs very little; a restricted image sitting in a shared album seen
-- by 200 people cannot be undone. Community authority decides what
-- comes back, and the app waits for that answer rather than guessing.
--
-- The photos table deliberately grants anon no update or delete, so
-- reports live in their own table instead of a flag on the photo.
-- Removing a photo for good, or dismissing a report, is done by TLALC
-- through the Supabase dashboard.
--
-- Safe to re-run: every statement is idempotent.
-- ============================================================

create table if not exists public.photo_reports (
  id          bigint generated always as identity primary key,
  photo_id    bigint not null references public.photos(id) on delete cascade,
  reason      text,
  reported_by text,
  created_at  timestamptz not null default now()
);

-- The gallery asks "which photos are reported?" on every load.
create index if not exists photo_reports_photo_id_idx
  on public.photo_reports (photo_id);

alter table public.photo_reports enable row level security;

-- Anyone can report.
drop policy if exists "anon can report a photo" on public.photo_reports;
create policy "anon can report a photo"
  on public.photo_reports for insert to anon with check (true);

-- Anyone can read which photos are reported, because the album has to
-- hide them on every device, not just the reporter's. Only the photo_id
-- matters for that; the reason and reporter are read by TLALC in the
-- dashboard. Keep it that way — do not surface reasons in the app, so
-- nobody can browse what was flagged and why.
drop policy if exists "anon can see which photos are reported" on public.photo_reports;
create policy "anon can see which photos are reported"
  on public.photo_reports for select to anon using (true);

-- No update or delete for anon: a report cannot be quietly withdrawn by
-- whoever uploaded the photo. TLALC clears it from the dashboard.

-- Convenience view for whoever is reviewing: every reported photo with
-- its reasons, newest first. Dashboard-only; anon has no rights on it.
create or replace view public.photo_reports_review as
  select p.id, p.name, p.station, p.url, p.path,
         count(r.id)                as reports,
         min(r.created_at)          as first_reported,
         array_agg(r.reason order by r.created_at) filter (where r.reason is not null) as reasons
  from public.photos p
  join public.photo_reports r on r.photo_id = p.id
  group by p.id, p.name, p.station, p.url, p.path
  order by min(r.created_at) desc;

revoke all on public.photo_reports_review from anon;

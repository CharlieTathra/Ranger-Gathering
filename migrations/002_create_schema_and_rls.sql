-- ============================================================
-- Ngarringilanha Ranger Gathering — backend setup
--
-- Creates the two tables the app writes to, the storage bucket
-- for the shared album, and the Row Level Security policies
-- that decide who can read and write what.
--
-- Safe to re-run: every statement is idempotent.
-- ============================================================


-- ---------- PHOTOS ----------
-- The shared Gathering album. Anyone on site can add and view.

create table if not exists public.photos (
  id          bigint generated always as identity primary key,
  name        text,
  station     text,
  path        text,
  url         text not null,
  created_at  timestamptz not null default now()
);

-- The gallery orders by created_at desc, limit 120.
create index if not exists photos_created_at_idx
  on public.photos (created_at desc);

alter table public.photos enable row level security;

drop policy if exists "anon can add photos" on public.photos;
create policy "anon can add photos"
  on public.photos for insert to anon with check (true);

drop policy if exists "anyone can view photos" on public.photos;
create policy "anyone can view photos"
  on public.photos for select to anon using (true);

-- Deliberately no update or delete policy. Photos that breach
-- cultural protocol are removed from the Supabase dashboard by
-- TLALC, not by whoever happens to be holding a phone.


-- ---------- FEEDBACK ----------
-- Evaluation responses. Anyone can submit; nobody can read back.

create table if not exists public.feedback (
  id                 bigint generated always as identity primary key,
  rating             smallint,
  best               text,
  well               text,
  improve            text,
  cultural_safety    text,
  return_next        text,
  pay_accommodation  text,
  name               text,
  comments           text,
  created_at         timestamptz not null default now()
);

alter table public.feedback enable row level security;

drop policy if exists "anon can submit feedback" on public.feedback;
create policy "anon can submit feedback"
  on public.feedback for insert to anon with check (true);

-- There is deliberately NO select policy on feedback.
--
-- People answer "Did you feel culturally safe and respected?"
-- believing it is anonymous. Without a select policy, the anon
-- key cannot read a single row back — responses are visible only
-- through the Supabase dashboard to those who hold the project
-- login. Do not add a select policy for anon.


-- ---------- STORAGE ----------
-- Public bucket so getPublicUrl() links resolve in the gallery.

insert into storage.buckets (id, name, public)
values ('photos', 'photos', true)
on conflict (id) do nothing;

drop policy if exists "anon can upload gathering photos" on storage.objects;
create policy "anon can upload gathering photos"
  on storage.objects for insert to anon
  with check (bucket_id = 'photos');

-- As above: no delete policy, so uploads cannot be wiped by
-- anyone holding the public key.

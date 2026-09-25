-- ============================================================
-- Ngarringilanha Ranger Gathering — push notifications
--
-- Two tables. Neither holds anything about a person: a push
-- subscription is an opaque URL the phone's own push service
-- issues, with no name, number or device identity attached.
--
-- The important rule here is that anon can INSERT a subscription
-- and never SELECT one. If anon could read this table, anyone
-- with the publishable key — which is in the page source of a
-- public repo — could pull every ranger's push endpoint and
-- notify all of them. Only the Edge Function, running on the
-- service role, ever reads it.
--
-- Safe to re-run. Rollback: see 005_rollback.sql.
-- ============================================================


-- ---------- SUBSCRIPTIONS ----------
create table if not exists public.push_subscriptions (
  endpoint    text primary key,
  p256dh      text,
  auth        text,
  created_at  timestamptz not null default now()
);

alter table public.push_subscriptions enable row level security;

drop policy if exists "anon can subscribe" on public.push_subscriptions;
create policy "anon can subscribe"
  on public.push_subscriptions for insert to anon
  with check (
        endpoint like 'https://%'
    and length(endpoint)                 <= 1000
    and length(coalesce(p256dh,''))      <=  200
    and length(coalesce(auth,''))        <=  100
  );
-- Deliberately no select / update / delete policy for anon.


-- ---------- THE MESSAGE TO SHOW ----------
-- The push itself is sent with no payload, so the phone is only told
-- "something is waiting". The service worker then reads the newest row
-- here to find out what to actually put on the screen. That means the
-- wording can be changed by adding a row — no app release, no cache bump.
create table if not exists public.push_messages (
  id          bigint generated always as identity primary key,
  title       text not null,
  body        text not null,
  url         text not null default './#feedback',
  created_at  timestamptz not null default now()
);

alter table public.push_messages enable row level security;

drop policy if exists "anyone can read the current notice" on public.push_messages;
create policy "anyone can read the current notice"
  on public.push_messages for select to anon
  using (true);
-- No insert policy for anon: new notices are added from the SQL Editor
-- or the dashboard, which run as the service role and bypass RLS.


-- ---------- THE FIRST NOTICE ----------
insert into public.push_messages (title, body, url)
values (
  'Tell us how the Gathering went',
  'Your feedback shapes the next Ngarringilanha. About two minutes, and you can leave your name off.',
  './#feedback'
);

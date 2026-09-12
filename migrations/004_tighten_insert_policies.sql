-- ============================================================
-- Ngarringilanha Ranger Gathering — narrow the anon INSERT policies
--
-- Supabase's security advisor flags all three anon INSERT policies as
-- "RLS Policy Always True". The app has no login: 200 rangers arrive
-- with a QR code and no account, so *somebody unauthenticated* has to
-- be able to submit feedback, add a photo and flag a photo. There is
-- no user identity to scope these against, and there never will be.
--
-- But "anyone may insert" does not have to mean "anyone may insert
-- anything". The publishable key is in the page source of a public
-- repo, so treat every field as if a stranger is filling it in. These
-- policies pin each column to what the app actually sends.
--
-- The one that matters most is photos.url. Until now a row could point
-- at any URL on the internet and the gallery would render it as an
-- <img> on 200 phones. Now it must be a file in this project's own
-- photos bucket, which can only get there through the upload path.
--
-- Safe to re-run. Safe to roll back: see 004_rollback below.
-- ============================================================


-- ---------- FEEDBACK ----------
drop policy if exists "anon can submit feedback" on public.feedback;
create policy "anon can submit feedback"
  on public.feedback for insert to anon
  with check (
        (rating is null or rating between 1 and 5)
    -- the three segmented questions; '' is what the app sends when unanswered
    and coalesce(cultural_safety,'')   in ('', 'Yes, fully', 'Mostly', 'Not really')
    and coalesce(return_next,'')       in ('', 'Yes', 'Maybe', 'No')
    and coalesce(pay_accommodation,'') in ('', 'Yes', 'Maybe', 'No')
    -- free text: generous enough for a heartfelt answer, bounded enough
    -- that nobody can push a megabyte into the table
    and length(coalesce(best,''))      <=  300
    and length(coalesce(name,''))      <=  300
    and length(coalesce(well,''))      <= 4000
    and length(coalesce(improve,''))   <= 4000
    and length(coalesce(comments,''))  <= 4000
  );


-- ---------- PHOTOS ----------
drop policy if exists "anon can add photos" on public.photos;
create policy "anon can add photos"
  on public.photos for insert to anon
  with check (
        url like 'https://jajjnrdzageznhufwpqr.supabase.co/storage/v1/object/public/photos/%'
    and length(url)                    <=  500
    and length(coalesce(name,''))      <=  200
    and length(coalesce(station,''))   <=  200
    and length(coalesce(path,''))      <=  300
  );


-- ---------- PHOTO REPORTS ----------
-- photo_id is already NOT NULL with a foreign key to photos, so a report
-- against a photo that doesn't exist is refused by the schema. This pins
-- the reason to the five the app offers, plus the fallback it sends when
-- someone taps through without choosing one.
drop policy if exists "anon can report a photo" on public.photo_reports;
create policy "anon can report a photo"
  on public.photo_reports for insert to anon
  with check (
        coalesce(reason,'') in ('',
          'Ceremony or cultural business',
          'Restricted or sacred place',
          'Person did not agree',
          'Person who has passed away',
          'Other',
          'Not given')
    and length(coalesce(reported_by,'')) <= 200
  );

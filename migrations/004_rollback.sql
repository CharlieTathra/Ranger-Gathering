-- Undo 004: put the three anon INSERT policies back to accepting anything.
-- Only run this if a tightened policy is blocking a real submission during
-- the Gathering and there is no time to work out which rule is wrong.
drop policy if exists "anon can submit feedback" on public.feedback;
create policy "anon can submit feedback"
  on public.feedback for insert to anon with check (true);

drop policy if exists "anon can add photos" on public.photos;
create policy "anon can add photos"
  on public.photos for insert to anon with check (true);

drop policy if exists "anon can report a photo" on public.photo_reports;
create policy "anon can report a photo"
  on public.photo_reports for insert to anon with check (true);

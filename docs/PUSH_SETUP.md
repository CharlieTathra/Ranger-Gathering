# Push notifications — setup

Everything in the app and the repo is already done. These are the three things
that have to happen in Supabase, which only you can do.

Your keys are in the file **`VAPID-KEYS-SECRET.txt`** that came with this work.
Keep it out of GitHub and out of email.

---

## Before you start: what this can and cannot do

A notification can only reach a phone that has **already opened the app and
tapped Allow**. There is no way around that — it is how the web works, and it
is the same for every app you have ever used.

So:

- **It cannot reach the rangers who came to Trelawney in 2026.** They have gone
  home, nobody was ever asked for permission, and there is nothing to send to.
  For this year's feedback, the email to the group coordinators is still the
  only thing that will work.
- **It will matter a great deal next Gathering.** People install the app on day
  one, tap Allow, and from then on you can reach every one of them — bus
  leaving in ten minutes, dinner moved, weather coming in, fill in the feedback
  form before you drive home.

Build it now, use it next year. That is the honest shape of it.

---

## Step 1 — Create the tables

Supabase dashboard → **SQL Editor** → **New query** → paste the contents of
`migrations/005_push_notifications.sql` → **Run**.

You will get the "destructive operation" warning again because the file
contains `drop policy`. Same as last time: it drops and immediately recreates
policies, and touches no data. Expect **Success. No rows returned.**

This creates two tables:

| Table | What it holds |
|---|---|
| `push_subscriptions` | One opaque address per phone. No name, no number, no device identity. |
| `push_messages` | The wording to show. The newest row wins. |

**The rule that matters:** `anon` can add a subscription and can never read
one. If anyone could read that table, whoever holds the publishable key — which
is in the page source of a public repo — could pull every ranger's push address
and notify all of them. Only the Edge Function ever reads it.

Rollback if you need it: `migrations/005_rollback.sql`. Note that it deletes
every subscription, so everyone would have to opt in again.

---

## Step 2 — Add the secrets

Supabase dashboard → **Project Settings** → **Edge Functions** → **Secrets** →
add these four, copying the values from `VAPID-KEYS-SECRET.txt`:

- `VAPID_PUBLIC_KEY`
- `VAPID_PRIVATE_JWK`
- `VAPID_SUBJECT`
- `PUSH_SEND_TOKEN`

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are already there — Supabase
provides them to every function automatically. You do not add those.

**The private key is the one that matters.** Anyone holding it can notify every
ranger who has opted in. It never goes in the app, in GitHub, or in a chat
window. If you think it has leaked, tell me and I will make a new pair —
everyone just has to opt in again.

---

## Step 3 — Deploy the function

If you have the Supabase CLI:

```
supabase functions deploy send-push
```

If you don't, do it in the dashboard: **Edge Functions** → **Create a
function** → name it exactly `send-push` → paste the contents of
`supabase/functions/send-push/index.ts` → **Deploy**.

---

## Sending one

```
curl -X POST \
  -H "x-push-token: YOUR_PUSH_SEND_TOKEN" \
  https://jajjnrdzageznhufwpqr.supabase.co/functions/v1/send-push
```

It replies with how it went:

```json
{ "sent": 137, "failed": 0, "removed": 4 }
```

- **sent** — notifications that reached a phone's push service
- **failed** — something went wrong; try again
- **removed** — phones that uninstalled the app or cleared their data. These
  are dropped automatically so the count stays honest.

Right now it will say `{"sent":0,...,"note":"nobody has turned notifications on yet"}`,
which is correct and expected.

The token is what stops the URL alone from letting anyone notify 200 rangers.
Treat it like a password.

---

## Changing what the notification says

You don't need a new app release. Add a row — the newest one wins:

```sql
insert into public.push_messages (title, body, url) values (
  'Bus leaving in 10 minutes',
  'Last call for the river workshops — meet at the silo.',
  './#agenda'
);
```

Then send as in the step above.

The push itself carries no text. The phone is only told "something is waiting",
and the app reads the newest row to find out what to put on the screen. That is
why the wording can change without touching the app.

---

## What rangers see

A panel on the home screen, under the feedback card:

> **Hear about the next Gathering**
> Turn on notifications and we can let you know when the next Ngarringilanha is
> on, and send reminders during the week — bus times, weather, changes to the
> program. We won't use it for anything else.
> **[ Turn on notifications ]**

They tap it, their phone asks them to confirm, and that's it. It can be
dismissed, and once it's on it just says so.

**iPhones:** Apple only allows this for an app that has been **added to the
Home Screen**. On an iPhone in a browser tab the panel doesn't appear at all —
the install prompt above it is the thing that matters. Worth saying out loud at
next year's welcome session: *add it to your home screen on day one.*

**If there's no signal** when someone taps Allow, the app keeps the
subscription on the phone and finishes the job next time it opens somewhere
with a bar. They're told that's what happened rather than being told it worked.

---

## Privacy

A push subscription is an address the phone's own push service issues. It
carries no name, no phone number, and nothing that identifies a person or a
device. You cannot tell from this table who has opted in — only how many.

Nobody is opted in by default. Nothing is sent unless you send it.

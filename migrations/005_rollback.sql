-- Undo 005. This deletes every push subscription, so every ranger who
-- turned notifications on would have to turn them on again.
drop table if exists public.push_subscriptions;
drop table if exists public.push_messages;

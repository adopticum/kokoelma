-- Ensure full old-row payload support for Realtime UPDATE/DELETE events.
-- Supabase db diff may not emit REPLICA IDENTITY changes, so we track them explicitly.

alter table if exists public.userprofiles replica identity full;
alter table if exists public.groups replica identity full;
alter table if exists public.memberships replica identity full;

-- Add relevant tables to the Realtime publication
-- View this in Supabase Studio > Database > Publications > supabase_realtime > Tables
alter publication supabase_realtime add table public.userprofiles;
alter publication supabase_realtime add table public.groups;
alter publication supabase_realtime add table public.memberships;

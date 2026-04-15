-- Adds an RPC for clients to atomically bump report_count on community
-- equivalences that matched during a recitation session. Replaces the old
-- "client taps It's a Match" increment flow — report_count now tracks how
-- many sessions an equivalence has actually helped, not how many users
-- originally submitted it.

create or replace function public.increment_equivalence_reports(ids uuid[])
returns void
language sql
security definer
set search_path = public
as $$
  update public.equivalences
  set report_count = coalesce(report_count, 0) + 1
  where id = any(ids);
$$;

-- Anon + authenticated clients both call this — the iOS/Android app uses
-- the anon key for unauthenticated users and the user's JWT when signed in.
grant execute on function public.increment_equivalence_reports(uuid[]) to anon, authenticated;

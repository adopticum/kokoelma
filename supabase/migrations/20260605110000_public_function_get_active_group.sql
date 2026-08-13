/*
Create a helper function to let a user query their active grouip membership.

Memberships is a many-to-many relationship between users and groups.
We have not yet implemented a way for users to manage multiple memberships.
For now we consider the __most recent membership__ as theactive group membership.
*/

CREATE OR REPLACE FUNCTION public.get_active_groupid()
  RETURNS uuid
  LANGUAGE sql
  SECURITY INVOKER  -- Run as the calling user, respecting RLS.
  STABLE  -- Declare function deterministic, makes it possible to cache.
  SET search_path = public  -- Security best practice to avoid schema-search-path surprises.
AS $$
  select m.groupid
  from public.memberships m
  where m.userid = auth.uid()
  order by m.joined_at desc nulls last
  limit 1;
$$;

/* Removes execute permission from the public role, 
which in Postgres is granted by default to all functions. 
Otherwise anonymous/unauthenticated users can call the function. */
revoke all on function public.get_active_groupid() from public;

/* Explicitly allow only authenticated users to call the function. */
grant execute on function public.get_active_groupid() to authenticated;

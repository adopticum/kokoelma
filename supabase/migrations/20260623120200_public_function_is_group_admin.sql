/*
Replace the obsolete function is_admin() with new is_group_admin().

Create a helper function to check if logged in user is a group admin.
SECURITY DEFINER is critical to prevent infinite recursion on RLS.
*/


CREATE OR REPLACE FUNCTION public.is_group_admin()
  RETURNS boolean
  LANGUAGE sql
  SECURITY DEFINER  -- Run as the function owner, bypassing RLS.
  STABLE  -- Declare function deterministic, makes is possible to cache.
  SET search_path = public  -- Security best practise for SECURITY DEFINER.
AS $$
  SELECT COALESCE(( -- Use coalesce to handle missing rows cleanly.
    SELECT is_group_admin
    FROM privileges
    WHERE id = auth.uid()
  ), false);
$$;

/* Removes execute permission from the public role, 
which in Postgres is granted by default to all functions. 
Without this, anonymous/unauthenticated users can call the function too. */
revoke all on function public.is_group_admin() from public;

/* Explicitly allow only logged-in users to call it. */
grant execute on function public.is_group_admin() to authenticated;

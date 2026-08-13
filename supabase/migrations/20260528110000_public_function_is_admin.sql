/*
Create a helper function to check if logged in user is an admin.
SECURITY DEFINER is critical to prevent infinite recursion on RLS.
*/

CREATE OR REPLACE FUNCTION public.is_admin()
 RETURNS boolean
 LANGUAGE sql
 SECURITY DEFINER  -- Run as the function owner, bypassing RLS.
 STABLE  -- Declare function deterministic, makes is possible to cache.
 SET search_path = public  -- Security best practise for SECURITY DEFINER.
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM userprofiles
    WHERE id = auth.uid()
    AND is_admin = true
  );
$$;

/* Removes execute permission from the public role, which in Postgres 
is granted by default to all functions. 
Without this, anonymous/unauthenticated users can call the function too. */
revoke all on function public.is_admin() from public;

/* Explicitly allow only logged-in users to call it. */
grant execute on function public.is_admin() to authenticated;

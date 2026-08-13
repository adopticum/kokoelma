/*
Create a helper function to join users, userprofiles and privileges tables.

The challenge is that Supabase restricts direct client access auth schema.
The standard pattern is to expose users table via a Postgres view or RPC function.

SECURITY DEFINER is critical to prevent infinite recursion on RLS.
*/

CREATE OR REPLACE FUNCTION public.get_all_user_properties()
RETURNS TABLE (
  id          uuid,
  email       text,
  created_at  timestamp with time zone,
  last_sign_in_at timestamp with time zone,
  nickname    text,
  firstname   text,
  lastname    text,
  is_group_admin boolean)
--LANGUAGE sql
LANGUAGE plpgsql
STABLE  -- Declare function deterministic, makes is possible to cache.
SECURITY DEFINER  -- Run as the function owner, bypassing RLS.
SET search_path TO 'public'  -- Security best practise for SECURITY DEFINER.
AS $function$
BEGIN
  IF NOT public.is_group_admin() THEN
    RAISE EXCEPTION 'Only group admin users may call get_all_user_properties';
  END IF;

  RETURN QUERY
  SELECT
    au.id,
    au.email,
    au.created_at,
    au.last_sign_in_at,
    up.nickname,
    up.firstname,
    up.lastname,
    COALESCE(pr.is_group_admin, false) AS is_group_admin
  FROM auth.users au
  LEFT JOIN public.userprofiles up ON up.id = au.id
  LEFT JOIN public.privileges pr ON pr.id = au.id
  ORDER BY au.created_at DESC;
END;
$function$;

/* Removes execute permission from the public role, 
which in Postgres is granted by default to all functions. 
Without this, anonymous/unauthenticated users can call the function too. */
REVOKE ALL ON FUNCTION public.get_all_user_properties() FROM public;

/* Explicitly allow only logged-in users to call it. */
GRANT EXECUTE ON FUNCTION public.get_all_user_properties() TO authenticated;

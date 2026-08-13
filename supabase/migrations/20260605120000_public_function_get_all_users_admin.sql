/* Join data from auth.users and public.userprofiles 
to get a complete list of users with their profile information. 

This function is intended for admin use, so it includes all users,
regardless of the RLS policies on the userprofiles table.
*/

CREATE OR REPLACE FUNCTION public.get_all_users_admin()
  RETURNS TABLE(
    id uuid, 
    email text, 
    created_at timestamp with time zone, 
    last_sign_in_at timestamp with time zone, 
    nickname text, 
    firstname text, 
    lastname text, 
    is_admin boolean
  )
  LANGUAGE plpgsql
  SECURITY DEFINER  -- Run as the function owner, bypassing RLS.
  STABLE  -- Declare function deterministic, makes ir possible to cache.
  SET search_path TO 'public'  -- Security best practice to avoid schema-search-path surprises.
AS $function$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'only admin users may call get_all_users_admin';
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
    up.is_admin
  FROM auth.users au
  LEFT JOIN public.userprofiles up ON up.id = au.id
  ORDER BY au.created_at DESC;
END;
$function$
;

/* Removes execute permission from the public role, 
which in Postgres is granted by default to all functions. 
Otherwise anonymous/unauthenticated users can call the function. */
REVOKE ALL ON FUNCTION public.get_all_users_admin() FROM public;

/* Explicitly allow only authenticated users to call the function. */
GRANT EXECUTE ON FUNCTION public.get_all_users_admin() TO authenticated;

/* Optionally: Restrict to allow execution only by service role */
/* GRANT EXECUTE ON FUNCTION public.get_all_users_admin() TO service_role; */
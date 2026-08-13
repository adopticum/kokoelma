/*
Delete columns, tables, functions and policies that belonged to 
the old is_admin definitions in the schema. 

This is now obsolete and is replaced by the is_group_admin definitions.
*/


/* Remove obsolete RLS policies based on is_admin field or function. */

DROP POLICY IF EXISTS "Let admins read all userprofiles"
ON "public"."userprofiles";

DROP POLICY IF EXISTS "Let admins read all memberships"
ON "public"."memberships";

DROP POLICY IF EXISTS "Let admins add users to groups"
ON "public"."memberships";

DROP POLICY IF EXISTS "Let admins remove users from groups"
ON "public"."memberships";


/* Remove obsolete function that checks is_admin. */
DROP FUNCTION IF EXISTS public.is_admin();

/* Remove obsolete function that joins all user metadata. */
DROP FUNCTION IF EXISTS public.get_all_users_admin();

/*
Delete columns, tables, functions and policies that belonged to 
the old is_admin definitions in the schema. 

The userprofiles table now only contains columns that each user may edit.
Refer to the privileges table for permissions granted to users.
*/

/* Drop the old policies that rely on is_admin. */
DROP POLICY IF EXISTS "Enable insert access for users based on id"
ON "public"."userprofiles";

DROP POLICY IF EXISTS "Enable update access for users based on id"
ON "public"."userprofiles";


/* Create new insert RLS policy that only checks auth and id. */
CREATE POLICY "Let users create their own userprofile"
  on "public"."userprofiles"
  as permissive
  for insert
  to authenticated
with check (
  (( SELECT auth.uid() AS uid) = id));

/* Create new update RLS policy that only checks auth and id. */
CREATE POLICY "Let users modify their own userprofile"
  on "public"."userprofiles"
  as permissive
  for update
  to authenticated
using (
  (( SELECT auth.uid() AS uid) = id)
)
with check (
  (( SELECT auth.uid() AS uid) = id)
);


/* Remove obsolete column is_admin from userprofiles. */
ALTER TABLE public.userprofiles
DROP COLUMN IF EXISTS is_admin;


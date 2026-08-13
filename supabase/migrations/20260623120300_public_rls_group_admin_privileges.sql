/*
Create new RLS policies for group admins that are 
based on the is_group_admin() helper function.
*/

  create policy "Let group admins read all userprofiles"
  on "public"."userprofiles"
  as permissive
  for select
  to authenticated
using (public.is_group_admin());


  create policy "Let group admins read all memberships"
  on "public"."memberships"
  as permissive
  for select
  to authenticated
using (public.is_group_admin());


  create policy "Let group admins add users to groups"
  on "public"."memberships"
  as permissive
  for insert
  to authenticated
with check (public.is_group_admin());


  create policy "Let group admins remove users from groups"
  on "public"."memberships"
  as permissive
  for delete
  to authenticated
using (public.is_group_admin());

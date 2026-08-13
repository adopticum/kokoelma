  create policy "Let admins read all userprofiles"
  on "public"."userprofiles"
  as permissive
  for select
  to authenticated
using (public.is_admin());


  create policy "Let admins read all memberships"
  on "public"."memberships"
  as permissive
  for select
  to authenticated
using (public.is_admin());


  create policy "Let admins add users to groups"
  on "public"."memberships"
  as permissive
  for insert
  to authenticated
with check (public.is_admin());


  create policy "Let admins remove users from groups"
  on "public"."memberships"
  as permissive
  for delete
  to authenticated
using (public.is_admin());

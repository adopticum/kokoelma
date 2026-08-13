/* 
Control access to files in bucket "shared-files".
Pattern: <groupid>/<userid>/<uploaded files>
- Users can read all files in all groups they are a member of.
- Users can write and delete files in groups they are a member of,
  but only in their own sub-folder.
- We do not allow update on files. Photos are immutable documents.
*/

  create policy "Allow users to read files in groups they are members of"
  on "storage"."objects"
  as permissive
  for select
  to authenticated
using ((
  bucket_id = 'shared-files'::text
  -- check that 1st level of path is the id of a group that the user is member of.
  AND EXISTS (
    SELECT 1 FROM public.memberships
    WHERE groupid = (storage.foldername(name))[1]::uuid
    AND userid = auth.uid()
  )
));


  create policy "Allow users to write to their own folder in shared groups"
  on "storage"."objects"
  as permissive
  for insert
  to authenticated
with check ((
  bucket_id = 'shared-files'::text
  -- check that 2nd level of path matches user's id.
  AND (auth.uid())::text = (storage.foldername(name))[2]
  -- check that 1st level of path is the id of a group that the user is member of.
  AND EXISTS (
    SELECT 1 FROM public.memberships
    WHERE groupid = (storage.foldername(name))[1]::uuid
    AND userid = auth.uid()
  )
));


  create policy "Allow users to delete files in their own folder in shared groups"
  on "storage"."objects"
  as permissive
  for delete
  to authenticated
using ((
  bucket_id = 'shared-files'::text
  -- check that 2nd level of path matches user's id.
  AND (auth.uid())::text = (storage.foldername(name))[2]
  -- check that 1st level of path is the id of a group that the user is member of.
  AND EXISTS (
    SELECT 1 FROM public.memberships
    WHERE groupid = (storage.foldername(name))[1]::uuid
    AND userid = auth.uid()
  )
));

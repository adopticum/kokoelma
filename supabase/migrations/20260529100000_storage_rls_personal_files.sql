/* 
Control access to files in bucket "personal-files".
Users are allowed full access (SIUD) on the own files and nothing else.
Each user has their own path which starts with their uid.
*/

  create policy "Give users full access only to own folder 1p05vvu_0"
  on "storage"."objects"
  as permissive
  for select
  to authenticated
using (((bucket_id = 'personal-files'::text) AND (( SELECT (auth.uid())::text AS uid) = (storage.foldername(name))[1])));



  create policy "Give users full access only to own folder 1p05vvu_1"
  on "storage"."objects"
  as permissive
  for insert
  to authenticated
with check (((bucket_id = 'personal-files'::text) AND (( SELECT (auth.uid())::text AS uid) = (storage.foldername(name))[1])));



  create policy "Give users full access only to own folder 1p05vvu_2"
  on "storage"."objects"
  as permissive
  for update
  to authenticated
using (((bucket_id = 'personal-files'::text) AND (( SELECT (auth.uid())::text AS uid) = (storage.foldername(name))[1])));



  create policy "Give users full access only to own folder 1p05vvu_3"
  on "storage"."objects"
  as permissive
  for delete
  to authenticated
using (((bucket_id = 'personal-files'::text) AND (( SELECT (auth.uid())::text AS uid) = (storage.foldername(name))[1])));

/*
Create the metadata table for uploaded photos.
*/

create table "public"."photometadata" (
  "id" uuid not null default gen_random_uuid(),
  "groupid" uuid not null,
  "userid" uuid not null default auth.uid(),
  "filename" text not null default ''::text,
  "uploaded_at" timestamp with time zone not null default now(),
  "captured_at" timestamp with time zone,
  "latitude" numeric,
  "longitude" numeric
);


alter table "public"."photometadata" enable row level security;

CREATE UNIQUE INDEX photometadata_pkey 
ON "public"."photometadata" USING btree (id);

alter table "public"."photometadata" 
add constraint "photometadata_pkey" 
PRIMARY KEY using index "photometadata_pkey";

/* Each photo is uniquely identified by its "path" which is the combination of <groupid>/<userid>/<filename>. */
ALTER TABLE "public"."photometadata" 
ADD CONSTRAINT "photometadata_unique_file"
UNIQUE ("groupid", "userid", "filename");

/* Set a FK to group. */
alter table "public"."photometadata" 
add constraint "photometadata_groupid_fkey" 
FOREIGN KEY (groupid) REFERENCES public.groups(id) ON UPDATE CASCADE ON DELETE CASCADE not valid;

alter table "public"."photometadata" 
validate constraint "photometadata_groupid_fkey";

/* Intentionally do not set a FK on userid. The photos and metadata shall remain even if the user is deleted. */


/* Set table level permissions. */

/* Admin users must be able to create groups, even though regular users only need select permissions. */

GRANT ALL ON TABLE "public"."photometadata" TO "service_role";

REVOKE ALL ON TABLE "public"."photometadata" FROM "anon";

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE "public"."photometadata" TO "authenticated";


/* Create policies for RLS. 
- Users can only read photos and metadata in groups they are members of.
- Users can only upload photos and metadata into groups they are members of.
- Users can only delete photos and metadata that they have uploaded themselves.
- No update permissions. Consider photos and metadata immutable. Delete and re-upload is possible.
*/

  create policy "Allow users to read photos in all groups they are members of."
  on "public"."photometadata"
  as permissive
  for select
  to authenticated
using (
  EXISTS (
    SELECT 1 FROM public.memberships m
    WHERE m.groupid = photometadata.groupid
      AND m.userid = auth.uid()
  )
);


  create policy "Allow users to insert metadata only into groups they are members of."
  on "public"."photometadata"
  as permissive
  for insert
  to authenticated
with check (
  userid = auth.uid()
  AND EXISTS (
    SELECT 1 FROM public.memberships m
    WHERE m.groupid = photometadata.groupid
      AND m.userid = auth.uid()
  )
);


  create policy "Allow users to delete their own photos only."
  on "public"."photometadata"
  as permissive
  for delete
  to authenticated
using (
  userid = auth.uid()
);
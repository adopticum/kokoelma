/*
Create the privileges table.
This is joined to the users and userprofiles by FK.
The column privileges.is_group_admin replaces userprofiles.is_admin.

Users are allowed to read their own rows.
*/

/* Create a table for privileges. */
create table "public"."privileges" (
  "id" uuid not null default auth.uid(),
  "created_at" timestamp with time zone not null default now(),
  "is_group_admin" boolean not null default false
);

CREATE UNIQUE INDEX privileges_pkey ON public.privileges USING btree (id);

alter table "public"."privileges" 
add constraint "privileges_pkey" 
PRIMARY KEY using index "privileges_pkey";

alter table "public"."privileges" 
add constraint "privileges_id_fkey" 
FOREIGN KEY (id) REFERENCES public.userprofiles(id)
ON UPDATE CASCADE ON DELETE CASCADE not valid;

alter table "public"."privileges" 
validate constraint "privileges_id_fkey";


/* Set table level permissions. */

/* Admin users must be able to create groups, even though regular users only need select permissions. */

GRANT ALL ON TABLE "public"."privileges" TO "service_role";

REVOKE ALL ON TABLE "public"."privileges" FROM "anon","authenticated";

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE "public"."privileges" TO "authenticated";


/* Create policies for RLS. */

alter table "public"."privileges" enable row level security;

  create policy "Let users read their own privileges only"
  on "public"."privileges"
  as permissive
  for select
  to authenticated
using ((( SELECT auth.uid() AS uid) = id));

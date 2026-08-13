/*
Create a table for user profiles.
The id (PK) is the same as the auth.uid() of the user.
*/

create table "public"."userprofiles" (
  "id" uuid not null default auth.uid(),
  "created_at" timestamp with time zone not null default now(),
  "firstname" text not null default ''::text,
  "lastname" text not null default ''::text,
  "nickname" text not null default ''::text,
  "is_admin" boolean not null default false
);

CREATE UNIQUE INDEX userprofiles_pkey ON public.userprofiles USING btree (id);

alter table "public"."userprofiles" add constraint "userprofiles_pkey" PRIMARY KEY using index "userprofiles_pkey";

alter table "public"."userprofiles" add constraint "userprofiles_id_fkey" FOREIGN KEY (id) REFERENCES auth.users(id) ON UPDATE CASCADE ON DELETE CASCADE not valid;

alter table "public"."userprofiles" validate constraint "userprofiles_id_fkey";


/* Set privileges for table access. */

REVOKE ALL ON "public"."userprofiles" FROM "anon";

REVOKE ALL ON "public"."userprofiles" FROM "authenticated";

GRANT SELECT, INSERT, UPDATE ON table "public"."userprofiles" to "authenticated";

GRANT ALL ON TABLE "public"."userprofiles" TO "service_role";


/* Create policies for RLS. */

alter table "public"."userprofiles" enable row level security;

  create policy "Enable select access for users based on id"
  on "public"."userprofiles"
  as permissive
  for select
  to authenticated
using ((( SELECT auth.uid() AS uid) = id));


  create policy "Enable insert access for users based on id"
  on "public"."userprofiles"
  as permissive
  for insert
  to authenticated
with check (
  (( SELECT auth.uid() AS uid) = id)
  -- Ensure that users cannot set themselves as admin. Only existing admins can create new admins.
  AND (is_admin = false)
);


  create policy "Enable update access for users based on id"
  on "public"."userprofiles"
  as permissive
  for update
  to authenticated
using ((( SELECT auth.uid() AS uid) = id))
with check (
  (( SELECT auth.uid() AS uid) = id)
  -- Ensure that users cannot set themselves as admin.
  AND (is_admin = (SELECT is_admin FROM "public"."userprofiles" WHERE id = auth.uid()))
);

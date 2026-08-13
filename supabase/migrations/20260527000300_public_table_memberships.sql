/*
Create the memberships table.
Memberships is a many-to-many relation between users and groups.

Users are allowed to list all groups (for now)
Users are allowed to join and leave groups on their own (for now).
*/

/* Create table memberships for the many-to-many relation between users and groups. */

create table "public"."memberships" (
  "id" uuid not null default gen_random_uuid(),
  "joined_at" timestamp with time zone not null default now(),
  "groupid" uuid not null,
  "userid" uuid not null default auth.uid()
);

alter table "public"."memberships" enable row level security;

CREATE UNIQUE INDEX memberships_pkey ON public.memberships USING btree (id);

alter table "public"."memberships" add constraint "memberships_pkey" PRIMARY KEY using index "memberships_pkey";

alter table "public"."memberships" add constraint "memberships_groupid_fkey" FOREIGN KEY (groupid) REFERENCES public.groups(id) ON UPDATE CASCADE ON DELETE CASCADE not valid;

alter table "public"."memberships" validate constraint "memberships_groupid_fkey";

alter table "public"."memberships" add constraint "memberships_userid_fkey" FOREIGN KEY (userid) REFERENCES public.userprofiles(id) ON UPDATE CASCADE ON DELETE CASCADE not valid;

alter table "public"."memberships" validate constraint "memberships_userid_fkey";


/* Set table level permissions. */

/* Users are allowed to join and leave groups on their own (for now). */

GRANT ALL ON TABLE "public"."memberships" TO "service_role";

REVOKE ALL ON TABLE "public"."memberships" FROM "anon","authenticated";

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE "public"."memberships" TO "authenticated";


/* Create policies for RLS. */

  create policy "Let users view their own memberships only."
  on "public"."memberships"
  as permissive
  for select
  to authenticated
using ((( SELECT auth.uid() AS uid) = userid));

  create policy "Let users leave groups on their own (for now)."
  on "public"."memberships"
  as permissive
  for delete
  to authenticated
using ((( SELECT auth.uid() AS uid) = userid));

  create policy "Let users join groups on their own (for now)."
  on "public"."memberships"
  as permissive
  for insert
  to authenticated
with check (true);

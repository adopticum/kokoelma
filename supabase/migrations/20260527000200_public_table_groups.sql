/*
Create the groups table.

Users are allowed to list all groups (for now)
Users are allowed to join and leave groups on their own (for now).
*/

/* Create a table for groups. */
create table "public"."groups" (
  "id" uuid not null default gen_random_uuid(),
  "created_at" timestamp with time zone not null default now(),
  "name" text not null default ''::text,
  "description" text not null default ''::text
);

alter table "public"."groups" enable row level security;

CREATE UNIQUE INDEX groups_name_key ON public.groups USING btree (name);

CREATE UNIQUE INDEX groups_pkey ON public.groups USING btree (id);

alter table "public"."groups" add constraint "groups_pkey" PRIMARY KEY using index "groups_pkey";

alter table "public"."groups" add constraint "groups_name_key" UNIQUE using index "groups_name_key";


/* Set table level permissions. */

/* Admin users must be able to create groups, even though regular users only need select permissions. */

GRANT ALL ON TABLE "public"."groups" TO "service_role";

REVOKE ALL ON TABLE "public"."groups" FROM "anon","authenticated";

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE "public"."groups" TO "authenticated";

/* Create policies for RLS. */

  create policy "Let authenticated users see all groups (for now)."
  on "public"."groups"
  as permissive
  for select
  to authenticated
using (true);

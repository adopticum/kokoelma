/* 
Difference between applied migrations and Supabase production db state.

    $ supabase db diff --linked --schema public -f diff_with_public_schema 

The only differences compared to my manually adjusted migration files are that
Supabase wants to rely completely on RLS and grant full table permissions.
That is probably ok because there is another security measure in place 
that will deny access unless there is at least one RLS policy defined:

> Policies are required to query data
> You need to create an access policy before you can query data from this table. 
> Without a policy, querying this table will return an empty array of results.
*/

grant delete on table "public"."groups" to "anon";

grant insert on table "public"."groups" to "anon";

grant references on table "public"."groups" to "anon";

grant select on table "public"."groups" to "anon";

grant trigger on table "public"."groups" to "anon";

grant truncate on table "public"."groups" to "anon";

grant update on table "public"."groups" to "anon";

grant references on table "public"."groups" to "authenticated";

grant trigger on table "public"."groups" to "authenticated";

grant truncate on table "public"."groups" to "authenticated";

grant delete on table "public"."memberships" to "anon";

grant insert on table "public"."memberships" to "anon";

grant references on table "public"."memberships" to "anon";

grant select on table "public"."memberships" to "anon";

grant trigger on table "public"."memberships" to "anon";

grant truncate on table "public"."memberships" to "anon";

grant update on table "public"."memberships" to "anon";

grant references on table "public"."memberships" to "authenticated";

grant trigger on table "public"."memberships" to "authenticated";

grant truncate on table "public"."memberships" to "authenticated";

grant delete on table "public"."userprofiles" to "anon";

grant insert on table "public"."userprofiles" to "anon";

grant references on table "public"."userprofiles" to "anon";

grant select on table "public"."userprofiles" to "anon";

grant trigger on table "public"."userprofiles" to "anon";

grant truncate on table "public"."userprofiles" to "anon";

grant update on table "public"."userprofiles" to "anon";

grant delete on table "public"."userprofiles" to "authenticated";

grant references on table "public"."userprofiles" to "authenticated";

grant trigger on table "public"."userprofiles" to "authenticated";

grant truncate on table "public"."userprofiles" to "authenticated";



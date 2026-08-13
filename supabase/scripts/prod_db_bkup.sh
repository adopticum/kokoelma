#!/bin/sh

# dump auth schema (login users)
supabase db dump --linked --data-only --schema auth -f secrets/auth_data.sql 

# dump public schema (userprofiles, etc.)
supabase db dump --linked --data-only --schema public -f secrets/public_data.sql 

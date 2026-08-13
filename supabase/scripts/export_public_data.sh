#!/bin/sh

# To export the data from the public schema of the production database.
# The output file will be written in the seed directory.

TS=$(date +%Y%m%d%H%M%S)
FILENAME=public-schema-${TS}.sql

# Dump public schema data
# Output path will be relative to one level over where config.toml is.
supabase db dump --linked --data-only --schema public --file supabase/seed/${FILENAME}

# Change into the seed directory (supabase/seed).
cd "$(dirname "$0")/../seed" || exit 1
pwd
echo
# Compare new dump with version controlled public-schema.sql. 
diff --color=always public-schema.sql ${FILENAME} 

# pg_dump parameters:
#--column-inserts \
#--table=public.groups \
#--table=public.userprofiles \
#--table=public.memberships \

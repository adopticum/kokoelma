#!/bin/sh

# Restore to the new project using psql. 
# Note: 
# Set session_replication_role to replica before 
# restore to disable triggers during the migration, 
# preventing columns from being double-encrypted. 

psql "$NEW_DB_URL" -c "SET session_replication_role = replica;"
psql "$NEW_DB_URL" -f secrets/auth_data.sql
psql "$NEW_DB_URL" -f secrets/public_data.sql
psql "$NEW_DB_URL" -c "SET session_replication_role = DEFAULT;"

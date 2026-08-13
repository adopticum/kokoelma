#!/bin/sh

function print_usage() {
  cat <<EOF
Usage: $0 --local|--prod

Options:
  --local   Seed the local Supabase database with users.
  --prod    Seed the remote Supabase database with users.
EOF
}

if [ "$#" -ne 1 ]; then
  print_usage
  exit 1
fi

# Run from the script directory (supabase/)
cd "$(dirname "$0")" || exit 1

case "$1" in
	--local)
		# Point the Supabase client to the local development instance.
		export SUPABASE_URL="http://127.0.0.1:54321"

		# Extract the local service role key from `supabase status` output.
		export SUPABASE_SECRET_KEY=$(supabase status 2>/dev/null | grep -oE 'sb_secret_[A-Za-z0-9_-]+')
		;;
	--prod)
		# The varialbles SUPABASE_URL and SUPABASE_SECRET_KEY are expected to be set in the environment.
		;;
	*)
		print_usage
		exit 1
		;;
esac

# Run the Node seeder (uses local installed @supabase/supabase-js)
node seed-users.mjs

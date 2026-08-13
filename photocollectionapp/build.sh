#!/bin/bash
# Build the Flutter app and automate build numbering.
# Builds the app for iOS platform.
# TODO: Android platform

# Exit on error
set -e

# Default: Do not build when there are uncommitted changes.
force=false

# Parse arguments
for arg in "$@"; do
	case $arg in
		-f|--force)
		force=true
		;;
	esac
done


# 1. Check for uncommitted changes unless forced.
if [[ "$force" == false ]]; then
    if [[ -n $(git status --porcelain) ]]; then
        echo "❌ Uncommitted changes detected. Use -f or --force to override."
        exit 1
    fi
fi

# 2. Get current commit hash
commit_hash=$(git rev-parse --short HEAD)
echo "✅ Using commit hash: $commit_hash"

# 3. Inject commit hash into build
# For Flutter, you can pass it as a Dart define:
flutter build ios --dart-define=GIT_COMMIT=$commit_hash
echo "✅ Commit hash baked into build."

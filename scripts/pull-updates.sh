#!/usr/bin/env bash
# ii-lacuna: Update Script for Users
# Run this to sync your local installation with the latest changes from the repository.

set -e

echo "Fetching latest changes from ii-lacuna..."

# Ensure we are in the repository root
cd "$(dirname "$0")/.."

# Fetch and rebase to keep local history clean
git fetch origin
git rebase origin/main

echo "Updates applied successfully."

# Optional: Run post-update tasks if they exist
if [ -f "setup/update-deps.sh" ]; then
    echo "Running post-update dependency checks..."
    ./setup/update-deps.sh
fi

echo "Your ii-lacuna installation is now up to date."

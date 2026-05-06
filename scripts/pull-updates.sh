#!/usr/bin/env bash
# ii-lacuna: Update script for users.
# Syncs the local repo with its tracked remote branch, then reapplies repo files.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Error: $REPO_ROOT is not a git repository."
    exit 1
fi

if [[ -n "$(git status --short)" ]]; then
    echo "Error: repository has uncommitted changes."
    echo "Commit or stash them before running pull-updates.sh."
    exit 1
fi

current_branch="$(git branch --show-current)"
if [[ -z "$current_branch" ]]; then
    echo "Error: could not determine current branch."
    exit 1
fi

if ! upstream_ref="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"; then
    echo "Error: branch '$current_branch' has no upstream tracking branch."
    exit 1
fi

remote_name="${upstream_ref%%/*}"

echo "Fetching latest changes from $upstream_ref..."
git fetch "$remote_name"

echo "Rebasing $current_branch onto $upstream_ref..."
git rebase "$upstream_ref"

echo "Repo updated successfully."

if [[ -x "$REPO_ROOT/setup" ]]; then
    echo "Reapplying repo-managed config files..."
    "$REPO_ROOT/setup" install-files
else
    echo "Warning: setup entrypoint not found or not executable; skipping install-files."
fi

echo "ii-lacuna is up to date."

#!/usr/bin/env bash
# ii-lacuna: Sync script for manual Quickshell copies.
# Mirrors dots/.config/quickshell into a target quickshell directory.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_DIR="$REPO_ROOT/dots/.config/quickshell"
TARGET_DIR="${1:-$HOME/.config/quickshell}"

if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "Error: source directory not found: $SOURCE_DIR"
    exit 1
fi

mkdir -p "$TARGET_DIR"

echo "Syncing $SOURCE_DIR -> $TARGET_DIR"

# Match the repo copy, including deletions, so manual installs stay in sync.
rsync -av --delete "$SOURCE_DIR/" "$TARGET_DIR/"

echo "Sync complete."

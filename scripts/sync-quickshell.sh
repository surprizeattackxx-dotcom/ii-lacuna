#!/usr/bin/env bash
# ii-lacuna: Sync Script for Manual Quickshell Copies
# Use this if you have manually copied the quickshell directory and want to sync with upstream.

set -e

# Path to your local quickshell directory (default: ~/.config/quickshell)
TARGET_DIR="${1:-$HOME/.config/quickshell}"

# Path to the source in the ii-lacuna repo
SOURCE_DIR="$(dirname "$0")/../dots/.config/quickshell"

if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory not found: $SOURCE_DIR"
    exit 1
fi

echo "Syncing $SOURCE_DIR -> $TARGET_DIR"

# Perform the sync
rsync -avP "$SOURCE_DIR/" "$TARGET_DIR/"

echo "Sync complete."

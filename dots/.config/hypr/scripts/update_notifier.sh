#!/usr/bin/env bash

# Check interval in seconds (600s = 10 minutes)
INTERVAL=600

REPO_DIR="$HOME/projects/ii-lacuna"
UPSTREAM="vaguesyntax/ii-vynx"
CACHE_FILE="$HOME/.cache/ii-lacuna-update-notified"

while true; do
    # Get local HEAD SHA
    LOCAL_SHA=$(git -C "$REPO_DIR" rev-parse HEAD 2>/dev/null)

    # Get latest upstream main SHA via GitHub API
    REMOTE_SHA=$(curl -m 10 -sf \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/$UPSTREAM/commits/main" \
        | grep -m1 '"sha"' | cut -d'"' -f4)

    if [[ -n "$LOCAL_SHA" && -n "$REMOTE_SHA" && "$LOCAL_SHA" != "$REMOTE_SHA" ]]; then
        # Only notify once per remote SHA
        if [[ ! -f "$CACHE_FILE" ]] || [[ "$(cat "$CACHE_FILE")" != "$REMOTE_SHA" ]]; then
            SHORT="${REMOTE_SHA:0:7}"
            notify-send -t 60000 -a 'ii-lacuna' -u normal \
                'Upstream Update Available' \
                "ii-vynx has new commits ($SHORT). Check your fork to merge."
            echo "$REMOTE_SHA" > "$CACHE_FILE"
        fi
    fi

    sleep "$INTERVAL"
done

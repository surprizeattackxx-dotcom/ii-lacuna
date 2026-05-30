#!/usr/bin/env bash

# Notify when upstream (vaguesyntax/ii-vynx) has commits not yet merged into this fork.
# Counts real unmerged commits via a local 'upstream' remote, so it only fires when
# there is something to merge and goes quiet again once you've merged.

INTERVAL=600 # seconds (10 min)
REPO_DIR="$HOME/Projects/ii-lacuna"
UPSTREAM_URL="https://github.com/vaguesyntax/ii-vynx.git"
UPSTREAM_BRANCH="main"
CACHE_FILE="$HOME/.cache/ii-lacuna-update-notified"

# Ensure the upstream remote exists
git -C "$REPO_DIR" remote get-url upstream >/dev/null 2>&1 \
    || git -C "$REPO_DIR" remote add upstream "$UPSTREAM_URL" 2>/dev/null

while true; do
    if git -C "$REPO_DIR" rev-parse HEAD >/dev/null 2>&1; then
        git -C "$REPO_DIR" fetch -q upstream "$UPSTREAM_BRANCH" 2>/dev/null
        BEHIND=$(git -C "$REPO_DIR" rev-list --count "HEAD..upstream/$UPSTREAM_BRANCH" 2>/dev/null)
        TIP=$(git -C "$REPO_DIR" rev-parse --short "upstream/$UPSTREAM_BRANCH" 2>/dev/null)

        if [[ -n "$BEHIND" && "$BEHIND" -gt 0 ]]; then
            # Notify once per upstream tip
            if [[ ! -f "$CACHE_FILE" ]] || [[ "$(cat "$CACHE_FILE")" != "$TIP" ]]; then
                notify-send -t 60000 -a 'ii-lacuna' -u normal \
                    'Upstream Update Available' \
                    "ii-vynx is $BEHIND commit(s) ahead (@$TIP). Ask Claude to merge."
                echo "$TIP" > "$CACHE_FILE"
            fi
        fi
    fi

    sleep "$INTERVAL"
done

#!/usr/bin/env bash
# Check if upstream/main has commits not in local main

cd "$(dirname "$0")/.." || exit 1

git fetch upstream --quiet 2>/dev/null

LOCAL=$(git rev-parse main 2>/dev/null)
UPSTREAM=$(git rev-parse upstream/main 2>/dev/null)

if [[ -z "$UPSTREAM" ]]; then
    echo "No upstream remote configured"
    exit 1
fi

if [[ "$LOCAL" == "$UPSTREAM" ]]; then
    echo "Up to date with upstream"
    exit 0
fi

BEHIND=$(git rev-list --count main..upstream/main 2>/dev/null)

if [[ "$BEHIND" -gt 0 ]]; then
    echo "ii-lacuna: $BEHIND new commit(s) from upstream"
    echo ""
    echo "Recent changes:"
    git log --oneline --no-decorate main..upstream/main | head -15
    echo ""
    echo "Files changed:"
    git diff --stat main..upstream/main | tail -20

    notify-send -u low "ii-lacuna upstream" "$BEHIND new commit(s) available to merge" 2>/dev/null || true
    exit 2
fi

echo "Up to date with upstream"

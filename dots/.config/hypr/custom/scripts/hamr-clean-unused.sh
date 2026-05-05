#!/usr/bin/env bash
# hamr-clean-unused.sh
# Cleans up hamr caches and hides apps that haven't been used in 90 days.

INDEX_FILE="$HOME/.config/hamr/plugin-indexes.json"
HIDE_FILE="$HOME/.config/hamr/apps-launcher-hide.json"
AUR_CACHE="$HOME/.cache/hamr/aur"
PRUNE_SCRIPT="$HOME/.local/bin/hamr-prune-dead-apps"

echo "==> Starting hamr maintenance..."

# 1. Prune missing/dead desktop entries
if [[ -f "$PRUNE_SCRIPT" ]]; then
    echo "--> Pruning missing desktop entries..."
    python3 "$PRUNE_SCRIPT"
else
    echo "--> Warning: Prune script not found at $PRUNE_SCRIPT"
fi

# 2. Clear AUR search cache
if [[ -d "$AUR_CACHE" ]]; then
    echo "--> Clearing AUR search cache..."
    rm -rf "$AUR_CACHE"/*
fi

# 3. Hide apps not used in 90 days
if [[ -f "$INDEX_FILE" ]]; then
    echo "--> Identifying apps unused for >90 days..."
    
    python3 - <<EOF
import json
import os
import time
from pathlib import Path

index_path = Path("$INDEX_FILE")
hide_path = Path("$HIDE_FILE")
threshold_days = 90
threshold_ms = threshold_days * 24 * 60 * 60 * 1000
now_ms = int(time.time() * 1000)

if not index_path.exists():
    exit(0)

with open(index_path, 'r') as f:
    data = json.load(f)

apps = data.get('indexes', {}).get('apps', {}).get('items', [])
to_hide = []

for app in apps:
    last_used = app.get('frecency', {}).get('lastUsed', 0)
    count = app.get('frecency', {}).get('count', 0)
    app_id = app.get('id')
    
    if not app_id:
        continue
        
    # If it was used before but not recently
    if count > 0 and (now_ms - last_used) > threshold_ms:
        to_hide.append(app_id)
        print(f"    - Hiding {app.get('name', app_id)} (last used {threshold_days}+ days ago)")

if to_hide:
    hide_data = {"drop_paths_exact": [], "drop_desktop_basenames": []}
    if hide_path.exists():
        try:
            with open(hide_path, 'r') as f:
                hide_data = json.load(f)
        except:
            pass
    
    existing = set(hide_data.get("drop_paths_exact", []))
    new_count = 0
    for p in to_hide:
        if p not in existing:
            if "drop_paths_exact" not in hide_data:
                hide_data["drop_paths_exact"] = []
            hide_data["drop_paths_exact"].append(p)
            new_count += 1
            
    if new_count > 0:
        with open(hide_path, 'w') as f:
            json.dump(hide_data, f, indent=2)
        print(f"--> Added {new_count} apps to {hide_path}")
    else:
        print("--> No new apps to hide.")
else:
    print("--> No long-unused apps found.")
EOF
fi

echo "==> Maintenance complete. Restarting hamr..."
if command -v hamr >/dev/null 2>&1; then
    # Try graceful shutdown via CLI command
    hamr shutdown 2>/dev/null || true
    
    # Force kill any lingering processes just in case
    pkill -f "hamr-daemon" || true
    
    # Allow time for socket cleanup
    sleep 1
    
    # Re-start daemon in background
    hamr daemon >/dev/null 2>&1 &
    echo "--> Hamr daemon re-started."
else
    echo "--> Error: 'hamr' command not found in PATH."
fi
echo "Done."

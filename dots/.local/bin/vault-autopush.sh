#!/usr/bin/env bash
# Watch ~/vault, commit locally, and mirror to Google Drive (debounced).
# Driven by the vault-autopush.service systemd user unit.
# Watcher/debounce shape is lifted from the proven ~/.config/noctalia/scripts/autopush.sh.
#
# Two things go up, deliberately:
#   notes/            browsable markdown, readable from the Drive app on a phone
#   bundles/*.bundle  one git bundle per day = the WHOLE repo history in one file
#
# Restore: `git clone vault-YYYY-MM-DD.bundle vault`

repo="$HOME/vault"
remote="gdrive:Obsidian-Vault"
stage="$HOME/.local/share/vault-backup"
statefile="$stage/.last-status"
KEEP_BUNDLES=14

mkdir -p "$stage"
cd "$repo" || exit 1

notify_once() {
  # Only fire on a transition into failure, so a dead network can't spam the phone.
  local status="$1" msg="$2"
  local prev=""
  [ -f "$statefile" ] && prev=$(cat "$statefile")
  echo "$status" > "$statefile"
  [ "$status" = "$prev" ] && return 0
  if [ "$status" = "fail" ]; then
    notify-local "Vault backup FAILED" "$msg" urgent
  else
    notify-local "Vault backup recovered" "Drive sync is working again."
  fi
}

commit_local() {
  if [ -n "$(git status --porcelain)" ]; then
    git add -A
    git commit -q -m "auto: $(date '+%Y-%m-%d %H:%M:%S')" >/dev/null 2>&1
  fi
}

push_drive() {
  local day bundle
  day=$(date '+%Y-%m-%d')
  bundle="$stage/vault-$day.bundle"

  # Never let a damaged local repo propagate. If there's no history to bundle,
  # bail loudly instead of uploading an empty file over a good one.
  if [ "$(git rev-list --count HEAD 2>/dev/null || echo 0)" -lt 1 ]; then
    notify_once fail "Local vault repo has no commits — refusing to overwrite the Drive copy."
    return 1
  fi

  git bundle create "$bundle.tmp" --all >/dev/null 2>&1 || {
    notify_once fail "git bundle failed — Drive copy left untouched."
    return 1
  }
  # A real bundle of this vault is >100KB. Anything tiny means something went wrong.
  if [ "$(stat -c %s "$bundle.tmp")" -lt 10240 ]; then
    rm -f "$bundle.tmp"
    notify_once fail "Generated bundle was suspiciously small — not uploading."
    return 1
  fi
  mv -f "$bundle.tmp" "$bundle"

  # --backup-dir means a local deletion moves the remote copy aside instead of
  # destroying it, so wiping the vault locally can't wipe it on Drive too.
  if ! rclone sync "$repo" "$remote/notes" \
        --exclude '.git/**' \
        --backup-dir "$remote/replaced/$day" \
        --transfers 8 --checkers 8 \
        >/dev/null 2>&1; then
    notify_once fail "rclone sync of notes to Google Drive failed."
    return 1
  fi

  if ! rclone copy "$bundle" "$remote/bundles/" >/dev/null 2>&1; then
    notify_once fail "rclone copy of the git bundle to Google Drive failed."
    return 1
  fi

  # Keep the bundle dir from growing forever, locally and remotely.
  ls -1t "$stage"/vault-*.bundle 2>/dev/null | tail -n +$((KEEP_BUNDLES + 1)) | xargs -r rm -f
  rclone delete "$remote/bundles/" --min-age "${KEEP_BUNDLES}d" >/dev/null 2>&1

  notify_once ok ""
  return 0
}

sync_all() {
  commit_local
  push_drive
}

# On boot this unit can easily start before the network is usable —
# network-online.target is a SYSTEM target and does not meaningfully gate a
# user unit. Without this wait, the catch-up run below would fail on a cold
# boot and fire an urgent phone push for nothing. Give it up to 2 minutes.
for _ in $(seq 1 24); do
  rclone lsd "$remote" >/dev/null 2>&1 && break
  sleep 5
done

# Catch up anything that changed while the watcher was down.
sync_all

# Block until the first change, then keep draining events until 3s of quiet
# (debounce), then sync once. Ignore .git so our own commits don't retrigger.
#
# The dirty-check before blocking is load-bearing: a sync takes tens of seconds
# and NOTHING is watching the vault while it runs, so any edit made during a
# sync generates no event we ever see. Without this, that edit sits uncommitted
# until the *next* unrelated change happens to trigger a cycle — which for a
# last-edit-before-walking-away means it never gets backed up at all. If the
# tree is already dirty, skip the blocking wait and go straight to another pass.
while true; do
  if [ -z "$(git status --porcelain)" ]; then
    inotifywait -r -q -e modify,create,delete,move --exclude '/\.git/' "$repo" >/dev/null 2>&1 || break
  fi
  while inotifywait -r -q -t 3 -e modify,create,delete,move --exclude '/\.git/' "$repo" >/dev/null 2>&1; do :; done
  sync_all
done

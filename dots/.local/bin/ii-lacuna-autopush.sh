#!/usr/bin/env bash
# Watch ii-lacuna's dots/ tree and auto commit+push on change (debounced).
# Driven by the ii-lacuna-autopush.service systemd user unit.
# Watcher/debounce shape is lifted from the proven ~/.config/noctalia/scripts/
# autopush.sh, plus the failure-notification and dirty-check guards that
# ~/.local/bin/vault-autopush.sh earned the hard way.
#
# Scoped to dots/ ON PURPOSE. The repo root is 2.9 GB of packaging/build tree
# (sdata/dist-*), it contains a root-owned pkg/ directory that a user-level
# inotifywait cannot even read, and it holds project source that Donnie may be
# mid-edit on. dots/ is 36 MB / 201 dirs, is what's symlinked out to ~/.config,
# and is the thing that actually needs never-lose-it backup. Both the watch and
# the commit are scoped to it, so this can never sweep up a half-finished
# source change.

repo="$HOME/Projects/ii-lacuna"
watch="$repo/dots"
branch="main"
statefile="$HOME/.local/share/ii-lacuna-autopush.last-status"
# Touch this file to suspend auto-committing while making a change that deserves
# a real commit message; remove it and the next event syncs everything normally.
# Without it the watcher wins the race on every deliberate edit and buries the
# reasoning under "auto(dots): <timestamp>" (it did exactly that to the Bolt RS3
# window-rule change in 96d332ea8 / 7bb63c13d on 2026-08-12).
pausefile="$repo/.autopush-pause"

# Names that must never be committed, regardless of .gitignore. Defense in
# depth, same reasoning as noctalia's ai-keys.json guard.
SECRET_PATTERNS='(^|/)(secrets\.env|ai-keys\.json|.*\.pem|.*\.key|id_rsa.*|id_ed25519.*|\.netrc)$'

mkdir -p "$(dirname "$statefile")"
cd "$repo" || exit 1

notify_once() {
  # Only fire on a transition into failure, so a dead network or a long-lived
  # merge can't spam the phone every debounce cycle.
  local status="$1" msg="$2" prev=""
  [ -f "$statefile" ] && prev=$(cat "$statefile")
  echo "$status" > "$statefile"
  [ "$status" = "$prev" ] && return 0
  if [ "$status" = "fail" ]; then
    notify-local "ii-lacuna autopush FAILED" "$msg" urgent
  else
    notify-local "ii-lacuna autopush recovered" "Dotfiles are syncing again."
  fi
}

mid_operation() {
  # Never commit a half-finished merge/rebase/cherry-pick/bisect. git add -A
  # during one of those records conflict markers as if they were real content.
  [ -e .git/MERGE_HEAD ] || [ -e .git/CHERRY_PICK_HEAD ] || [ -e .git/REVERT_HEAD ] \
    || [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ] || [ -e .git/BISECT_LOG ]
}

commit_push() {
  # Paused on purpose — stay quiet (no notification; this is a normal state,
  # not a failure) and let the caller land its own commit.
  [ -e "$pausefile" ] && return 0

  if mid_operation; then
    notify_once fail "A merge/rebase is in progress — not committing until it's resolved."
    return 1
  fi

  if [ -n "$(git status --porcelain -- dots)" ]; then
    # Refuse the whole cycle if a secret-looking file is about to go in, rather
    # than committing it and cleaning up afterwards (git history is forever).
    local offenders
    offenders=$(git status --porcelain -- dots | awk '{print $NF}' | grep -E "$SECRET_PATTERNS")
    if [ -n "$offenders" ]; then
      notify_once fail "Refusing to commit, secret-looking file(s): $(echo "$offenders" | tr '\n' ' ')"
      return 1
    fi

    git add -A -- dots
    git commit -q -m "auto(dots): $(date '+%Y-%m-%d %H:%M:%S')" >/dev/null 2>&1
  fi

  # Push if ahead of origin (also covers commits made while offline, and the
  # hand-written commits this script never made itself).
  if [ -n "$(git log "origin/$branch..HEAD" --oneline 2>/dev/null)" ]; then
    if ! git push -q origin "$branch" >/dev/null 2>&1; then
      notify_once fail "git push origin $branch failed — commits are local only."
      return 1
    fi
  fi

  notify_once ok ""
  return 0
}

# Catch up anything that changed while the watcher was down.
commit_push

# Block until the first change, then keep draining events until 3s of quiet
# (debounce), then sync once. Ignore .git so our own commits don't retrigger.
#
# The dirty-check before blocking is load-bearing (learned from vault-autopush):
# a commit+push takes real time and NOTHING is watching while it runs, so an
# edit made during a cycle generates no event we ever see. Without this, that
# edit sits uncommitted until the next unrelated change happens to fire — which
# for a last-tweak-before-walking-away means never. If the tree is already
# dirty, skip the blocking wait and go straight round again.
while true; do
  if [ -z "$(git status --porcelain -- dots)" ]; then
    inotifywait -r -q -e modify,create,delete,move --exclude '/\.git/' "$watch" >/dev/null 2>&1 || break
  fi
  while inotifywait -r -q -t 3 -e modify,create,delete,move --exclude '/\.git/' "$watch" >/dev/null 2>&1; do :; done
  commit_push
done

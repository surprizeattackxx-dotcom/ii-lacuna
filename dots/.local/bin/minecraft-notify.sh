#!/usr/bin/env bash
# minecraft-notify — fires notifications for minecraft.service events.
# Watches the unit's user journal for:
#   server booting, world ready ("Done (Xs)!"), clean stop vs crash,
#   "<player> joined the game", "<player> left the game".
# Desktop toast on every event; phone push (notify-local "urgent") on
# online/offline/join — leaves are desktop-only so they don't buzz the phone.
# Runs as minecraft-notify.service (systemd --user).
#
# Test mode: minecraft-notify.sh --stdin  (feed journal-style lines, fire as usual)
set -uo pipefail

UNIT="${MINECRAFT_UNIT:-minecraft.service}"
NOTIFY_BIN="${MINECRAFT_NOTIFY_BIN:-$HOME/.local/bin/notify-local}"

saw_stopping=0
last_boot_notice=0

fire() { "$NOTIFY_BIN" "$@" >/dev/null 2>&1 || true; }

handle() {
  local line=$1 player secs now
  case "$line" in
    *"joined the game")
      player="${line% joined the game}"
      player="${player##*]: }"
      [ -n "$player" ] && fire "Minecraft 👋 $player joined" "$player is on the server" urgent
      ;;
    *"left the game")
      player="${line% left the game}"
      player="${player##*]: }"
      [ -n "$player" ] && fire "Minecraft 🔌 $player left" "$player logged off"
      ;;
    *"Starting minecraft server version"*)
      now=$(date +%s)
      # dampener: crash-loop restarts may print this every boot — max one toast / 2 min
      if (( now - last_boot_notice >= 120 )); then
        last_boot_notice=$now
        fire "Minecraft ⏳ server starting" "Booting up — modpack load takes about a minute"
      fi
      ;;
    *'Done ('*'s)! For help'*)
      secs=""
      [[ $line =~ Done\ \(([0-9.]+)s\) ]] && secs="${BASH_REMATCH[1]}"
      fire "Minecraft 🟢 server online" "World loaded${secs:+ in ${secs}s} — accepting connections" urgent
      ;;
    Stopping\ *|*"Stopping server")
      saw_stopping=1
      ;;
    Stopped\ *)
      if (( saw_stopping )); then
        fire "Minecraft 🔴 server offline" "Stopped cleanly" urgent
      else
        fire "Minecraft 🔴 server DOWN" "Exited unexpectedly — auto-restarting in 10s" urgent
      fi
      saw_stopping=0
      ;;
  esac
}

if [ "${1:-}" = "--stdin" ]; then
  while IFS= read -r line; do handle "$line"; done
else
  # -n 0: follow strictly from "now" — never replay old journal lines as fresh toasts
  /usr/bin/journalctl --user -u "$UNIT" -f -n 0 -o cat |
  while IFS= read -r line; do handle "$line"; done
fi

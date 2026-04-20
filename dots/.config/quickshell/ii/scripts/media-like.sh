#!/usr/bin/env bash
# Quickshell: like/dislike — uses hyprctl dispatch sendshortcut to send keys
# to player windows WITHOUT stealing focus. No wtype needed.
# Usage: media-like.sh <like|dislike> <kind> <desktop_entry> <dbus_name>
#
# Optional: ~/.config/quickshell/ii/scripts/media-like-user.sh

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/bin:${PATH:-}"

set -euo pipefail

ACTION="${1:-}"
KIND="${2:-unknown}"
DESKTOP="${3:-}"
DBUS="${4:-}"

USER_HOOK="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/ii/scripts/media-like-user.sh"

notify() {
	command -v notify-send >/dev/null 2>&1 || return 0
	notify-send -a "Quickshell" -i "audio-headphones" "$1" "$2"
}

require_hyprctl() {
	command -v hyprctl >/dev/null 2>&1 || {
		notify "Media" "\`hyprctl\` not found."
		exit 1
	}
}

# Find window address by class substring (case-insensitive)
find_addr_by_class() {
	local substr="$1"
	command -v jq >/dev/null 2>&1 || return 1
	hyprctl clients -j 2>/dev/null | jq -r --arg s "$substr" \
		'[.[] | select(((.class // "") | ascii_downcase | contains($s))) | .address] | first // empty' 2>/dev/null
}

# Find window address by title substring (case-insensitive)
find_addr_by_title() {
	local substr="$1"
	command -v jq >/dev/null 2>&1 || return 1
	hyprctl clients -j 2>/dev/null | jq -r --arg s "$substr" \
		'[.[] | select(((.title // "") | ascii_downcase | contains($s))) | .address] | first // empty' 2>/dev/null
}

# Send shortcut to a window address without changing focus
# Usage: send_shortcut "MODS, key" "address:0x..."
send_shortcut() {
	local shortcut="$1" target="$2"
	require_hyprctl
	hyprctl dispatch sendshortcut "$shortcut, $target" 2>/dev/null
}

find_spotify_addr() {
	local addr
	addr=$(find_addr_by_class "spotify")
	[[ -n "$addr" && "$addr" != "null" ]] && echo "$addr" && return 0
	return 1
}

find_youtube_addr() {
	local addr
	# Prefer window with "youtube" in title
	addr=$(find_addr_by_title "youtube")
	[[ -n "$addr" && "$addr" != "null" ]] && echo "$addr" && return 0
	# Fallback: class-based
	case "$KIND" in
	firefox)
		addr=$(find_addr_by_class "firefox")
		;;
	youtube)
		addr=$(find_addr_by_class "youtube")
		[[ -z "$addr" || "$addr" == "null" ]] && addr=$(find_addr_by_class "electron")
		;;
	*)
		for cls in chrome chromium brave google-chrome zen; do
			addr=$(find_addr_by_class "$cls")
			[[ -n "$addr" && "$addr" != "null" ]] && break
		done
		;;
	esac
	[[ -n "$addr" && "$addr" != "null" ]] && echo "$addr" && return 0
	return 1
}

spotify_like() {
	local addr
	addr=$(find_spotify_addr) || {
		notify "Spotify" "Could not find Spotify window."
		exit 1
	}
	send_shortcut "ALT SHIFT, b" "address:${addr}"
}

spotify_dislike() {
	local addr
	addr=$(find_spotify_addr) || {
		notify "Spotify" "Could not find Spotify window."
		exit 1
	}
	if [[ -n "${SPOTIFY_DISLIKE_SHORTCUT:-}" ]]; then
		send_shortcut "$SPOTIFY_DISLIKE_SHORTCUT" "address:${addr}"
	else
		# Spotify has no native dislike — toggle like off instead
		send_shortcut "ALT SHIFT, b" "address:${addr}"
	fi
}

browser_like() {
	local addr
	addr=$(find_youtube_addr) || {
		notify "Browser" "Could not find a YouTube/browser window."
		exit 1
	}
	send_shortcut "SHIFT, equal" "address:${addr}"
}

browser_dislike() {
	local addr
	addr=$(find_youtube_addr) || {
		notify "Browser" "Could not find a YouTube/browser window."
		exit 1
	}
	send_shortcut "SHIFT, minus" "address:${addr}"
}

if [[ -f "$USER_HOOK" ]]; then
	# shellcheck source=/dev/null
	source "$USER_HOOK"
	if declare -F media_like_user >/dev/null 2>&1; then
		media_like_user "$ACTION" "$KIND" "$DESKTOP" "$DBUS" && exit 0
	fi
fi

case "$ACTION" in
like | dislike) ;;
*) exit 1 ;;
esac

case "$KIND" in
spotify)
	if [[ "$ACTION" == "like" ]]; then
		spotify_like
	else
		spotify_dislike
	fi
	;;
firefox | chromium | brave | zen | youtube)
	if [[ "$ACTION" == "like" ]]; then
		browser_like
	else
		browser_dislike
	fi
	;;
unknown)
	notify "Media like/dislike" "Unknown MPRIS player."
	exit 1
	;;
*)
	notify "Media like/dislike" "Unhandled kind: ${KIND}"
	exit 1
	;;
esac

exit 0

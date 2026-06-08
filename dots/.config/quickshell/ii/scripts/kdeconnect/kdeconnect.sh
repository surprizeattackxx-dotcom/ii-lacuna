#!/usr/bin/env bash
set -euo pipefail

# ── Plain ANSI (fallback only — gum drives the real UI) ─────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ── Live Material 3 colors (tracks the wallpaper via matugen) ───────────────
COLORS_JSON="$HOME/.local/state/quickshell/user/generated/colors.json"
declare -A M3
load_colors() {
	if [[ -f "$COLORS_JSON" ]] && command -v python3 &>/dev/null; then
		while IFS='=' read -r k v; do
			[[ -n "$k" ]] && M3["$k"]="$v"
		done < <(python3 -c 'import json,sys
for k,v in json.load(open(sys.argv[1])).items():
    print(f"{k}={v}")' "$COLORS_JSON" 2>/dev/null || true)
	fi
	M3[primary]="${M3[primary]:-#88c0d0}"
	M3[on_primary]="${M3[on_primary]:-#2e3440}"
	M3[primary_container]="${M3[primary_container]:-#5e81ac}"
	M3[on_primary_container]="${M3[on_primary_container]:-#e5e9f0}"
	M3[secondary]="${M3[secondary]:-#81a1c1}"
	M3[tertiary]="${M3[tertiary]:-#b48ead}"
	M3[surface]="${M3[surface]:-#2e3440}"
	M3[surface_container]="${M3[surface_container]:-#3b4252}"
	M3[surface_container_high]="${M3[surface_container_high]:-#434c5e}"
	M3[on_surface]="${M3[on_surface]:-#eceff4}"
	M3[on_surface_variant]="${M3[on_surface_variant]:-#d8dee9}"
	M3[outline]="${M3[outline]:-#7b88a1}"
	M3[outline_variant]="${M3[outline_variant]:-#4c566a}"
	M3[error]="${M3[error]:-#bf616a}"
	M3[success]="${M3[success]:-#a3be8c}"
}
c() { printf '%s' "${M3[$1]}"; }

HAS_GUM=0; command -v gum &>/dev/null && HAS_GUM=1
WIDTH=52

DEVICE=""
DEVICE_NAME=""

# ── gum building blocks ─────────────────────────────────────────────────────
header() {
	gum style --border rounded --border-foreground "$(c primary)" \
		--foreground "$(c primary)" --align center --width "$WIDTH" \
		--padding "1 2" --bold \
		"󰄜  K D E   C O N N E C T" \
		"$(gum style --foreground "$(c on_surface_variant)" --bold=false 'phone companion')"
}

label() { # text color
	gum style --foreground "$2" "$1"
}

battery_bar() { # charge charging
	local charge="${1:-0}" charging="${2:-false}" width=22 filled bar="" i col
	((charge<0)) && charge=0; ((charge>100)) && charge=100
	filled=$(( charge * width / 100 ))
	for ((i=0; i<width; i++)); do
		if ((i<filled)); then bar+="█"; else bar+="░"; fi
	done
	col="$(c success)"
	((charge<=40)) && col="$(c tertiary)"
	((charge<=15)) && col="$(c error)"
	local bolt=""
	[[ "$charging" == "true" ]] && bolt="  $(gum style --foreground "$(c tertiary)" '󰂄')"
	printf '%s  %s%%%s' "$(gum style --foreground "$col" "$bar")" "$charge" "$bolt"
}

device_card() { # id name reachable
	local id="$1" name="$2" reachable="$3"
	local dot charge charging body
	if [[ "$reachable" == "1" ]]; then
		dot="$(gum style --foreground "$(c success)" '●')"
	else
		dot="$(gum style --foreground "$(c outline)" '○')"
	fi
	charge="$(get_charge_num "$id" || true)"
	charging="$(get_charging "$id" || echo false)"
	body="$(gum style --foreground "$(c on_surface)" --bold "$dot  $name")"
	if [[ -n "$charge" ]]; then
		body+=$'\n'"$(gum style --foreground "$(c on_surface_variant)" "󰁹  $(battery_bar "$charge" "$charging")")"
	else
		body+=$'\n'"$(gum style --foreground "$(c outline)" '󰁹  battery unavailable')"
	fi
	gum style --border rounded --border-foreground "$(c outline_variant)" \
		--padding "0 2" --width "$WIDTH" "$body"
}

confirm_msg() { # icon text color
	gum style --foreground "${3:-$(c primary)}" --bold "  ${1}  ${2}"
}

pause() {
	echo
	gum style --foreground "$(c outline)" "  ↵  press enter to go back"
	read -r _ || true
}

# ── device data ─────────────────────────────────────────────────────────────
get_charge_num() {
	dbus-send --session --dest=org.kde.kdeconnect --print-reply \
		"/modules/kdeconnect/devices/$1/battery" \
		org.freedesktop.DBus.Properties.Get \
		string:"org.kde.kdeconnect.device.battery" string:"charge" 2>/dev/null | \
		grep -oP 'int32 \K\d+' || true
}
get_charging() {
	dbus-send --session --dest=org.kde.kdeconnect --print-reply \
		"/modules/kdeconnect/devices/$1/battery" \
		org.freedesktop.DBus.Properties.Get \
		string:"org.kde.kdeconnect.device.battery" string:"isCharging" 2>/dev/null | \
		grep -oP 'boolean \K\w+' || true
}

get_battery() {
	local id="${1:-}"
	[[ -z "$id" ]] && pick_device
	id="${id:-$DEVICE}"
	local charge is_charging
	charge="$(get_charge_num "$id")"
	is_charging="$(get_charging "$id")"
	if [[ -n "$charge" ]]; then
		local icon=""
		if   [[ "$charge" -ge 90 ]]; then icon=""
		elif [[ "$charge" -ge 60 ]]; then icon=""
		elif [[ "$charge" -ge 30 ]]; then icon=""
		elif [[ "$charge" -ge 10 ]]; then icon=""
		fi
		local bolt=""
		[[ "$is_charging" == "true" ]] && bolt="⚡"
		echo -e "${icon} ${charge}%${bolt}"
	fi
}

pick_device() {
	local devices
	devices=$(kdeconnect-cli -a --id-name-only 2>/dev/null)
	[[ -z "$devices" ]] && devices=$(kdeconnect-cli -l --id-name-only 2>/dev/null)
	if [[ -z "$devices" ]]; then
		echo -e "${RED}No KDE Connect devices found.${NC}" >&2
		exit 1
	fi

	local count
	count=$(echo "$devices" | wc -l)
	if [[ "$count" -eq 1 ]]; then
		DEVICE=$(echo "$devices" | awk '{print $1}')
		DEVICE_NAME=$(echo "$devices" | awk '{$1=""; print $0}' | xargs)
		return
	fi

	if [[ "$HAS_GUM" -eq 1 ]]; then
		local names=() ids=() line picked
		while IFS= read -r line; do
			[[ -z "$line" ]] && continue
			ids+=("$(echo "$line" | awk '{print $1}')")
			names+=("$(echo "$line" | awk '{$1=""; print $0}' | xargs)")
		done <<< "$devices"
		picked=$(printf '%s\n' "${names[@]}" | gum choose \
			--header "  Select a device" \
			--cursor "󰜴 " \
			--cursor.foreground "$(c primary)" \
			--header.foreground "$(c on_surface_variant)" \
			--selected.foreground "$(c on_primary)" \
			--selected.background "$(c primary)")
		local i
		for i in "${!names[@]}"; do
			if [[ "${names[$i]}" == "$picked" ]]; then
				DEVICE="${ids[$i]}"; DEVICE_NAME="$picked"; return
			fi
		done
		exit 1
	elif command -v fzf &>/dev/null; then
		local picked
		picked=$(echo "$devices" | fzf --prompt="Select device: " --height=10)
		DEVICE=$(echo "$picked" | awk '{print $1}')
		DEVICE_NAME=$(echo "$picked" | awk '{$1=""; print $0}' | xargs)
	else
		echo -e "${YELLOW}Multiple devices found. Select one:${NC}" >&2
		local i=0 ids=() line
		while IFS= read -r line; do
			i=$((i+1)); ids+=("$(echo "$line" | awk '{print $1}')")
			echo -e "${CYAN}$i)${NC} $(echo "$line" | awk '{$1=""; print $0}' | xargs)" >&2
		done <<< "$devices"
		echo -n "> " >&2; read -r sel
		DEVICE="${ids[$((sel-1))]}"; DEVICE_NAME=""
	fi
}

# ── status ──────────────────────────────────────────────────────────────────
status() {
	if [[ "${SIMPLE:-0}" == "1" ]]; then
		kdeconnect-cli -a --id-name-only 2>/dev/null | while IFS= read -r line; do
			[[ -z "$line" ]] && continue
			local id name
			id=$(echo "$line" | awk '{print $1}')
			name=$(echo "$line" | awk '{$1=""; print $0}' | xargs)
			local batt batt_num=0
			batt=$(get_battery "$id" 2>/dev/null || true)
			[[ "$batt" =~ ([0-9]+)% ]] && batt_num="${BASH_REMATCH[1]}"
			echo "1|${name}|${batt_num}"
		done
		return
	fi

	if [[ "$HAS_GUM" -eq 1 ]]; then
		local any=0 line id name reach
		while IFS= read -r line; do
			[[ -z "$line" ]] && continue
			any=1
			id=$(echo "$line" | grep -oP '[0-9a-f]{32}')
			name=$(echo "$line" | sed 's/^[[:space:]]*- //;s/: '"$id"'.*//')
			reach=0; echo "$line" | grep -q "reachable" && reach=1
			device_card "$id" "$name" "$reach"
		done < <(kdeconnect-cli -l 2>/dev/null)
		if [[ "$any" -eq 0 ]]; then
			gum style --border rounded \
				--border-foreground "$(c outline_variant)" --foreground "$(c outline)" \
				--padding "0 2" --width "$WIDTH" "󰄜  No devices found"
		fi
		return
	fi

	echo -e "${BOLD}Devices:${NC}"
	while IFS= read -r line; do
		[[ -z "$line" ]] && continue
		local id name status_icon batt
		id=$(echo "$line" | grep -oP '[0-9a-f]{32}')
		name=$(echo "$line" | sed 's/^[[:space:]]*- //;s/: '"$id"'.*//')
		if echo "$line" | grep -q "reachable"; then status_icon="${GREEN}●${NC}"; else status_icon="${RED}○${NC}"; fi
		batt=$(get_battery "$id" 2>/dev/null || true)
		if [[ -n "$batt" ]]; then echo -e "  ${status_icon} ${name} — ${batt}"; else echo -e "  ${status_icon} ${name}"; fi
	done < <(kdeconnect-cli -l 2>/dev/null)
}

# ── actions ─────────────────────────────────────────────────────────────────
ping() {
	pick_device
	if [[ "$HAS_GUM" -eq 1 ]]; then
		gum spin --spinner pulse --spinner.foreground "$(c primary)" \
			--title "Ringing $DEVICE_NAME…" -- \
			bash -c "kdeconnect-cli -d '$DEVICE' --ring 2>/dev/null; sleep 1"
		confirm_msg "󰂜" "Ringing $DEVICE_NAME" "$(c primary)"
	else
		echo -e "${BLUE}Ringing ${BOLD}$DEVICE_NAME${NC}${BLUE}...${NC}"
		kdeconnect-cli -d "$DEVICE" --ring 2>/dev/null || true
	fi
}

find() {
	pick_device
	if [[ "$HAS_GUM" -eq 1 ]]; then
		gum spin --spinner pulse --spinner.foreground "$(c tertiary)" \
			--title "Making $DEVICE_NAME ring loudly…" -- \
			bash -c "kdeconnect-cli -d '$DEVICE' --findmyphone 2>/dev/null || kdeconnect-cli -d '$DEVICE' --ring 2>/dev/null; sleep 1"
		confirm_msg "󰍉" "Find my phone — $DEVICE_NAME" "$(c tertiary)"
	else
		echo -e "${BLUE}Making ${BOLD}$DEVICE_NAME${NC}${BLUE} ring loudly...${NC}"
		kdeconnect-cli -d "$DEVICE" --findmyphone 2>/dev/null || kdeconnect-cli -d "$DEVICE" --ring 2>/dev/null || true
	fi
}

send_clipboard() {
	pick_device
	local clip=""
	if command -v wl-paste &>/dev/null; then clip=$(wl-paste 2>/dev/null || true)
	elif command -v xclip &>/dev/null; then clip=$(xclip -o -selection clipboard 2>/dev/null || true); fi
	if [[ -z "$clip" ]]; then
		[[ "$HAS_GUM" -eq 1 ]] && confirm_msg "󰅖" "Clipboard is empty" "$(c error)" || echo -e "${RED}Clipboard is empty.${NC}" >&2
		return
	fi
	kdeconnect-cli -d "$DEVICE" --share-text "$clip"
	if [[ "$HAS_GUM" -eq 1 ]]; then
		confirm_msg "󰅎" "Clipboard sent to $DEVICE_NAME" "$(c success)"
		gum style --foreground "$(c outline)" --padding "0 4" "$(echo "$clip" | head -c 80)"
	fi
}

share_text() {
	pick_device
	local text
	if [[ "$HAS_GUM" -eq 1 ]]; then
		text=$(gum input --placeholder "Type a message to send…" \
			--width "$WIDTH" --prompt "󰊐  " \
			--prompt.foreground "$(c primary)" \
			--cursor.foreground "$(c primary)") || return
		[[ -z "$text" ]] && return
		kdeconnect-cli -d "$DEVICE" --share-text "$text"
		confirm_msg "󰍡" "Sent to $DEVICE_NAME" "$(c success)"
	else
		echo -n "Text: " >&2; read -r text
		kdeconnect-cli -d "$DEVICE" --share-text "$text"
	fi
}

share_file() {
	pick_device
	local path="${1:-}"
	if [[ -z "$path" && "$HAS_GUM" -eq 1 ]]; then
		path=$(gum file "$HOME" --height 18 2>/dev/null) || return
	elif [[ -z "$path" ]]; then
		echo -n "File path: " >&2; read -r path
	fi
	[[ -z "$path" ]] && return
	path=$(realpath -m "$path" 2>/dev/null || echo "$path")
	kdeconnect-cli -d "$DEVICE" --share "$path"
	[[ "$HAS_GUM" -eq 1 ]] && confirm_msg "󰉍" "Sent ${path##*/} to $DEVICE_NAME" "$(c success)"
}

lock() {
	pick_device
	kdeconnect-cli -d "$DEVICE" --lock 2>/dev/null || true
	[[ "$HAS_GUM" -eq 1 ]] && confirm_msg "󰍁" "Locked $DEVICE_NAME" "$(c primary)"
}

unlock() {
	pick_device
	kdeconnect-cli -d "$DEVICE" --unlock 2>/dev/null || true
	[[ "$HAS_GUM" -eq 1 ]] && confirm_msg "󰿆" "Unlocked $DEVICE_NAME" "$(c primary)"
}

notifications() {
	pick_device
	local out
	out=$(kdeconnect-cli -d "$DEVICE" --list-notifications 2>/dev/null || true)
	if [[ "$HAS_GUM" -eq 1 ]]; then
		if [[ -z "$out" ]]; then
			gum style --border rounded --border-foreground "$(c outline_variant)" \
				--foreground "$(c outline)" --padding "0 2" --width "$WIDTH" \
				"󰂚  No notifications from $DEVICE_NAME"
		else
			gum style --border rounded --border-foreground "$(c outline_variant)" \
				--foreground "$(c on_surface)" --padding "0 2" --width "$WIDTH" "$out"
		fi
	else
		echo -e "${BLUE}Notifications from ${BOLD}$DEVICE_NAME${NC}${BLUE}:${NC}"
		echo "${out:-  (none or not supported)}"
	fi
}

info() {
	pick_device
	local charge plugins
	charge="$(get_charge_num "$DEVICE" || true)"
	plugins=$(dbus-send --session --dest=org.kde.kdeconnect --print-reply \
		"/modules/kdeconnect/devices/$DEVICE" \
		org.kde.kdeconnect.device.loadedPlugins 2>/dev/null | \
		grep -oP 'string "\K[^"]+' | sed 's/kdeconnect_//' | sort | sed 's/^/  • /')
	if [[ "$HAS_GUM" -eq 1 ]]; then
		local body
		body="$(gum style --foreground "$(c primary)" --bold "$DEVICE_NAME")"
		body+=$'\n'"$(gum style --foreground "$(c outline)" "󰌪  $DEVICE")"
		[[ -n "$charge" ]] && body+=$'\n'"$(gum style --foreground "$(c on_surface_variant)" "󰁹  $(battery_bar "$charge" "$(get_charging "$DEVICE")")")"
		body+=$'\n\n'"$(gum style --foreground "$(c secondary)" --bold 'Plugins')"
		body+=$'\n'"$(gum style --foreground "$(c on_surface_variant)" "$plugins")"
		gum style --border rounded --border-foreground "$(c outline_variant)" \
			--padding "1 2" --width "$WIDTH" "$body"
	else
		echo -e "${BOLD}$DEVICE_NAME${NC}\n  ID: ${CYAN}$DEVICE${NC}"
		[[ -n "$charge" ]] && echo -e "  Battery: ${charge}%"
		echo -e "\n${BLUE}Plugins:${NC}\n$plugins"
	fi
}

refresh() {
	if [[ "$HAS_GUM" -eq 1 ]]; then
		gum spin --spinner points --spinner.foreground "$(c primary)" \
			--title "Refreshing devices…" -- \
			bash -c "kdeconnect-cli --refresh 2>/dev/null; sleep 2"
	else
		echo -e "${BLUE}Refreshing device list...${NC}"
		kdeconnect-cli --refresh 2>/dev/null; sleep 2
	fi
	status
}

pair() {
	local all_devices
	all_devices=$(kdeconnect-cli -l --id-name-only 2>/dev/null)
	if [[ -z "$all_devices" ]]; then
		echo -e "${RED}No devices found. Start kdeconnect-daemon first.${NC}" >&2; exit 1
	fi
	pick_device
	if [[ "$HAS_GUM" -eq 1 ]]; then
		confirm_msg "󰌹" "Pairing with $DEVICE_NAME — accept on your phone" "$(c tertiary)"
	else
		echo -e "${BLUE}Pairing with ${BOLD}$DEVICE_NAME${NC}${BLUE}...${NC}"
		echo -e "${YELLOW}Accept the pairing request on your device.${NC}"
	fi
	kdeconnect-cli -d "$DEVICE" --pair
}

# ── interactive dashboard ───────────────────────────────────────────────────
interactive() {
	if [[ "$HAS_GUM" -ne 1 ]]; then interactive_plain; return; fi
	while true; do
		clear
		header
		echo
		status
		echo
		local choice
		choice=$(gum choose \
			--header "  What's up?" \
			--header.foreground "$(c on_surface_variant)" \
			--cursor "󰜴 " \
			--cursor.foreground "$(c primary)" \
			--selected.foreground "$(c on_primary)" \
			--selected.background "$(c primary)" \
			--height 14 \
			"󰂜   Ring device" \
			"󰍉   Find my phone" \
			"󰅎   Send clipboard" \
			"󰍡   Share text" \
			"󰉍   Share file" \
			"󰍁   Lock phone" \
			"󰿆   Unlock phone" \
			"󰂚   Notifications" \
			"󰋽   Device info" \
			"󰑐   Refresh devices" \
			"󰗼   Quit") || { clear; exit 0; }

		echo
		case "$choice" in
			*Ring*)          ping ;;
			*Find*)          find ;;
			*clipboard*)     send_clipboard ;;
			*"Share text"*)  share_text ;;
			*"Share file"*)  share_file ;;
			*Lock*)          lock ;;
			*Unlock*)        unlock ;;
			*Notifications*) notifications ;;
			*info*)          info ;;
			*Refresh*)       refresh ;;
			*Quit*)          clear; exit 0 ;;
		esac
		pause
	done
}

interactive_plain() {
	echo -e "${BOLD}${CYAN}KDE Connect${NC}"
	while true; do
		echo -e "\n  ${CYAN}s${NC})status ${CYAN}p${NC})ring ${CYAN}f${NC})find ${CYAN}c${NC})clip ${CYAN}t${NC})text ${CYAN}F${NC})file ${CYAN}l${NC})lock ${CYAN}u${NC})unlock ${CYAN}n${NC})notifs ${CYAN}i${NC})info ${CYAN}r${NC})refresh ${CYAN}q${NC})quit"
		echo -n "> " >&2; read -r cmd
		case "$cmd" in
			s) status ;; p) ping ;; f) find ;; c) send_clipboard ;; t) share_text ;;
			F) share_file ;; l) lock ;; u) unlock ;; n) notifications ;; i) info ;;
			r) refresh ;; q) exit 0 ;; *) echo -e "${RED}?${NC}" >&2 ;;
		esac
	done
}

show_help() {
	cat <<EOF
Usage: kdeconnect [command]

Commands:
  status         List devices and connection status (default)
  info           Show device info and available plugins
  ping           Ring/Find device
  find           Make device ring loudly (find my phone)
  clipboard      Send clipboard contents to device
  text           Share text to device
  file [path]    Share file to device
  lock           Lock device
  unlock         Unlock device
  notifications  List device notifications
  refresh        Refresh device list
  pair           Pair with a device
  interactive    Interactive M3 dashboard
  help           Show this help
EOF
}

mkdir -p /tmp/quickshell/kdeconnect 2>/dev/null || true
load_colors

case "${1:-status}" in
	status) status ;;
	info) info ;;
	ping|ring) ping ;;
	find|findmyphone) find ;;
	clipboard|send-clipboard) send_clipboard ;;
	text|share-text) share_text ;;
	file|share-file) share_file "${2:-}" ;;
	lock) lock ;;
	unlock) unlock ;;
	notifications) notifications ;;
	refresh) refresh ;;
	pair) pair ;;
	interactive|--interactive|-i) interactive ;;
	help|--help|-h) show_help ;;
	*) echo -e "${RED}Unknown command: $1${NC}" >&2; show_help; exit 1 ;;
esac

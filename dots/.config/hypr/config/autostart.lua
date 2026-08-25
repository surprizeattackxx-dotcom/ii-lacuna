-- Auto-start config
-- if you dont use UWSM add your auto start programs here, otherwise use XDG autostart https://wiki.archlinux.org/title/XDG_Autostart

-- Autostart

hl.on("hyprland.start", function()
-- ─── Hardware & Services ────────────────────────
hl.exec_cmd("hyprpm reload -n")
hl.exec_cmd("hypridle")
hl.exec_cmd("~/.config/hypr/scripts/monitor-watch.sh")
hl.exec_cmd("~/.config/hypr/scripts/update_notifier.sh")
hl.exec_cmd("sleep 3 && ~/.config/hypr/scripts/restore-workspaces.sh")

-- ─── Desktop Services ───────────────────────────
-- nm-applet, kdeconnectd and geoclue-demo-agent are started via XDG autostart
-- (/etc/xdg/autostart/*.desktop) because uwsm manages the session. Launching
-- them here too raced the tray host and left Bitwarden with no tray icon.
hl.exec_cmd("pypr")
-- Browser autostart: brave-browser (swapped from firefox 2026-08-25).
-- Hardcoded rather than reusing `browser` from variables.lua because THIS
-- FILE LOADS FIRST (hyprland.lua: autostart is line 5, variables line 8)
-- so the global isn't defined yet — keep this in sync with variables.lua.
hl.exec_cmd("brave-browser")
-- The shell is noctalia v5 (native), managed by systemd (`noctalia.service`).
-- Legacy quickshell-ii / waybar launch lines removed 2026-07-31.
hl.exec_cmd("xhost +SI:localuser:root")


-- ─── Auth & Keyring ─────────────────────────────
hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
hl.exec_cmd("dbus-update-activation-environment --all")
hl.exec_cmd("sleep 1 && dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")

-- ─── Audio & Clipboard ──────────────────────────
hl.exec_cmd("easyeffects --hide-window --service-mode")
-- Android notification ding on every notification
hl.exec_cmd("~/.config/hypr/scripts/osrs-notify-sound.sh")
-- Clipboard watching is handled by Noctalia Shell's built-in clipboard service

-- ─── Apps ───────────────────────────────────────
hl.exec_cmd("sleep 1 && uwsm app -- thunderbird")
hl.exec_cmd("sleep 2 && uwsm app -- discord")
hl.exec_cmd("sleep 4 && uwsm app -- steam -cef-force-gpu -tenfoot")
hl.exec_cmd("uwsm app -- openrgb --start-minimized --profile 'Default'")
hl.exec_cmd("sleep 2 && uwsm app -- galaxybudsclient")

-- ─── Theme & Cursor ─────────────────────────────
hl.exec_cmd("hyprctl setcursor oreo_red_cursors 24")
hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme oreo_red_cursors")
hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-size 24")
hl.exec_cmd("mkdir -p ~/.icons/default && printf '[Icon Theme]\\nInherits=oreo_red_cursors\\n' > ~/.icons/default/index.theme")
end)

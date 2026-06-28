-- Keybindings
-- Uses globals: mainMod (hyprland.lua), app variables (variables.lua)

-- ─── App Launchers ──────────────────────────────

hl.bind("SUPER + RETURN", hl.dsp.exec_cmd("uwsm app -- " .. terminal))
hl.bind("SUPER + E", hl.dsp.exec_cmd("uwsm app -- " .. fileManager))
hl.bind("SUPER + B", hl.dsp.exec_cmd("uwsm app -- " .. browser))
hl.bind("SUPER + C", hl.dsp.exec_cmd("uwsm app -- " .. codeEditor))
hl.bind("CTRL + SHIFT + ESCAPE", hl.dsp.exec_cmd("uwsm app -- " .. taskManager))
hl.bind("SUPER + R", hl.dsp.exec_cmd("hamr"))
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("ALT + F4", hl.dsp.window.close())
hl.bind("SUPER + SHIFT + Q", hl.dsp.exec_cmd("~/.config/hypr/scripts/kill_hovered.sh"))
hl.bind("SUPER + P", hl.dsp.window.pin())
hl.bind("SUPER + F", hl.dsp.exec_cmd("~/.config/hypr/scripts/toggle_fullscreen.sh"))
hl.bind("SUPER + ALT + SPACE", hl.dsp.exec_cmd("python3 ~/.config/hypr/scripts/dvd-bounce.py"))
hl.bind("SUPER + S", hl.dsp.exec_cmd("~/.config/hypr/scripts/toggle_suspend_games.sh"))
hl.bind("SUPER + SEMICOLON", hl.dsp.layout("splitratio -0.1"))
hl.bind("SUPER + APOSTROPHE", hl.dsp.layout("splitratio +0.1"))
hl.bind("CTRL + SUPER + T", hl.dsp.exec_cmd("qs -c noctalia-shell ipc call wallpaper toggle"),
        { description = "Shell: Toggle wallpaper selector" })
hl.bind("CTRL + SUPER + ALT + T", hl.dsp.exec_cmd("qs -c noctalia-shell ipc call wallpaper random"),
        { description = "Shell: Select random wallpaper" })

-- ─── Cursor Zoom ───────────────────────────────
hl.bind("SUPER + EQUAL", hl.dsp.exec_cmd("~/.config/hypr/scripts/zoom.sh increase 0.5"))
hl.bind("SUPER + MINUS", hl.dsp.exec_cmd("~/.config/hypr/scripts/zoom.sh decrease 0.5"))
hl.bind("SUPER + KP_ADD", hl.dsp.exec_cmd("~/.config/hypr/scripts/zoom.sh increase 0.5"))
hl.bind("SUPER + KP_SUBTRACT", hl.dsp.exec_cmd("~/.config/hypr/scripts/zoom.sh decrease 0.5"))

-- ─── Directional Focus ─────────────────────────
hl.bind("SUPER + LEFT", hl.dsp.focus({ direction = "left" }))
hl.bind("SUPER + RIGHT", hl.dsp.focus({ direction = "right" }))
hl.bind("SUPER + UP", hl.dsp.focus({ direction = "up" }))
hl.bind("SUPER + DOWN", hl.dsp.focus({ direction = "down" }))
hl.bind("SUPER + SHIFT + LEFT", hl.dsp.window.move({ direction = "left" }))
hl.bind("SUPER + SHIFT + RIGHT", hl.dsp.window.move({ direction = "right" }))
hl.bind("SUPER + SHIFT + UP", hl.dsp.window.move({ direction = "up" }))
hl.bind("SUPER + SHIFT + DOWN", hl.dsp.window.move({ direction = "down" }))

-- ─── Workspace Focus ───────────────────────────
hl.bind("SUPER + 1", hl.dsp.focus({ workspace = 1 }))
hl.bind("SUPER + SHIFT + 1", hl.dsp.window.move({ workspace = 1 }))
hl.bind("SUPER + 2", hl.dsp.focus({ workspace = 2 }))
hl.bind("SUPER + SHIFT + 2", hl.dsp.window.move({ workspace = 2 }))
hl.bind("SUPER + 3", hl.dsp.focus({ workspace = 3 }))
hl.bind("SUPER + SHIFT + 3", hl.dsp.window.move({ workspace = 3 }))
hl.bind("SUPER + 4", hl.dsp.focus({ workspace = 4 }))
hl.bind("SUPER + SHIFT + 4", hl.dsp.window.move({ workspace = 4 }))
hl.bind("SUPER + 5", hl.dsp.focus({ workspace = 5 }))
hl.bind("SUPER + SHIFT + 5", hl.dsp.window.move({ workspace = 5 }))
hl.bind("SUPER + 6", hl.dsp.focus({ workspace = 6 }))
hl.bind("SUPER + SHIFT + 6", hl.dsp.window.move({ workspace = 6 }))
hl.bind("SUPER + 7", hl.dsp.focus({ workspace = 7 }))
hl.bind("SUPER + SHIFT + 7", hl.dsp.window.move({ workspace = 7 }))
hl.bind("SUPER + 8", hl.dsp.focus({ workspace = 8 }))
hl.bind("SUPER + SHIFT + 8", hl.dsp.window.move({ workspace = 8 }))
hl.bind("SUPER + 9", hl.dsp.focus({ workspace = 9 }))
hl.bind("SUPER + SHIFT + 9", hl.dsp.window.move({ workspace = 9 }))
hl.bind("SUPER + 0", hl.dsp.focus({ workspace = 10 }))
hl.bind("SUPER + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }))
hl.bind("SUPER + ALT + 1", hl.dsp.focus({ workspace = 11 }))
hl.bind("SUPER + ALT + SHIFT + 1", hl.dsp.window.move({ workspace = 11 }))
hl.bind("SUPER + ALT + 2", hl.dsp.focus({ workspace = 12 }))
hl.bind("SUPER + ALT + SHIFT + 2", hl.dsp.window.move({ workspace = 12 }))
hl.bind("SUPER + ALT + 3", hl.dsp.focus({ workspace = 13 }))
hl.bind("SUPER + ALT + SHIFT + 3", hl.dsp.window.move({ workspace = 13 }))
hl.bind("SUPER + ALT + 4", hl.dsp.focus({ workspace = 14 }))
hl.bind("SUPER + ALT + SHIFT + 4", hl.dsp.window.move({ workspace = 14 }))
hl.bind("SUPER + ALT + 5", hl.dsp.focus({ workspace = 15 }))
hl.bind("SUPER + ALT + SHIFT + 5", hl.dsp.window.move({ workspace = 15 }))
hl.bind("SUPER + ALT + 6", hl.dsp.focus({ workspace = 16 }))
hl.bind("SUPER + ALT + SHIFT + 6", hl.dsp.window.move({ workspace = 16 }))
hl.bind("SUPER + ALT + 7", hl.dsp.focus({ workspace = 17 }))
hl.bind("SUPER + ALT + SHIFT + 7", hl.dsp.window.move({ workspace = 17 }))
hl.bind("SUPER + ALT + 8", hl.dsp.focus({ workspace = 18 }))
hl.bind("SUPER + ALT + SHIFT + 8", hl.dsp.window.move({ workspace = 18 }))
hl.bind("SUPER + ALT + 9", hl.dsp.focus({ workspace = 19 }))
hl.bind("SUPER + ALT + SHIFT + 9", hl.dsp.window.move({ workspace = 19 }))
hl.bind("SUPER + ALT + 0", hl.dsp.focus({ workspace = 20 }))
hl.bind("SUPER + ALT + SHIFT + 0", hl.dsp.window.move({ workspace = 20 }))

-- ─── Mouse Operations ──────────────────────────
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- ─── QuickShell Actions ────────────────────────
hl.bind("SUPER + D", hl.dsp.exec_cmd("hamr toggle"))
hl.bind("SUPER + U", hl.dsp.exec_cmd("claude-usage-float"))
hl.bind("SUPER + V", hl.dsp.exec_cmd("qs -c noctalia-shell ipc call plugin:clipper toggle"))
hl.bind("SUPER + PERIOD", hl.dsp.exec_cmd("qs -c noctalia-shell ipc call launcher emoji"))
hl.bind("SUPER + A", hl.dsp.exec_cmd("qs -c noctalia-shell ipc call controlCenter toggle"))
hl.bind("SUPER + N", hl.dsp.exec_cmd("qs -c noctalia-shell ipc call notifications toggleHistory"))
hl.bind("SUPER + SLASH", hl.dsp.global("quickshell:cheatsheetToggle"))
hl.bind("SUPER + ALT + V", hl.dsp.exec_cmd("qs -c noctalia-shell ipc call calendar toggle"))
-- SUPER + K (on-screen keyboard): no noctalia equivalent
hl.bind("SUPER + M", hl.dsp.exec_cmd("qs -c noctalia-shell ipc call media toggle"))
hl.bind("SUPER + G", hl.dsp.exec_cmd("qs -c noctalia-shell ipc call systemMonitor toggle"))
hl.bind("SUPER + J", hl.dsp.exec_cmd("qs -c noctalia-shell ipc call bar toggle"))
hl.bind("SUPER + W", hl.dsp.exec_cmd("qs -c noctalia-shell ipc call wallpaper toggle"),
        { description = "Shell: Toggle wallpaper selector" })
hl.bind("SUPER + O", hl.dsp.global("quickshell:gameLauncherToggle"))
hl.bind("SUPER + SPACE", hl.dsp.exec_cmd("qs -c noctalia-shell ipc call launcher toggle"))
-- SUPER + X (animations toggle): no noctalia equivalent
hl.bind("SUPER + I", hl.dsp.exec_cmd(settingsApp))
hl.bind("SUPER + L", hl.dsp.exec_cmd("qs -c noctalia-shell ipc call lockScreen lock"))

-- ─── System Actions ────────────────────────────
hl.bind("CTRL + ALT + DELETE", hl.dsp.exec_cmd("qs -c noctalia-shell ipc call sessionMenu toggle"))
hl.bind("SUPER + TAB", hl.plugin.hymission.toggle)
hl.bind("SUPER + Z", hl.dsp.exec_cmd("pypr zoom"))
hl.bind("SUPER + H", hl.dsp.exec_cmd("$HOME/hypr-gamma/gui/build/hyprgamma-gui"))
hl.bind("SUPER + SHIFT + S", hl.dsp.global("quickshell:regionScreenshot"))
hl.bind("SUPER + SHIFT + A", hl.dsp.global("quickshell:regionSearch"))
hl.bind("SUPER + SHIFT + X", hl.dsp.global("quickshell:regionOcr"))
hl.bind("SUPER + SHIFT + I", hl.dsp.global("quickshell:aiSidebarToggle"))
-- SUPER + SHIFT + T (screen translate): no noctalia equivalent
hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"))
hl.bind("SUPER + SHIFT + R", hl.dsp.global("quickshell:regionRecord"))
hl.bind("CTRL + SUPER + V", hl.dsp.exec_cmd(volumeMixer))
hl.bind("CTRL + SUPER + R", hl.dsp.exec_cmd("~/.config/hypr/scripts/reload.sh"))
hl.bind("CTRL + SUPER + SLASH", hl.dsp.exec_cmd("xdg-open ~/.config/illogical-impulse/config.json"))
hl.bind("CTRL + SUPER + ALT + SLASH", hl.dsp.exec_cmd("xdg-open ~/.config/hypr/hyprland/binds.lua"))
hl.bind("SUPER + SHIFT + M", hl.dsp.exec_cmd("pw-play ~/.local/share/sounds/osrs/death.ogg & sleep 3; command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit"))

-- ─── Media & Volume ────────────────────────────
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), {
    locked = true,
    repeating = true
})
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), {
    locked = true,
    repeating = true
})
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("~/.config/hypr/scripts/osd_brightness.sh up"), {
    locked = true,
    repeating = true
})
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("~/.config/hypr/scripts/osd_brightness.sh down"), {
    locked = true,
    repeating = true
})
hl.bind("SUPER + F5", hl.dsp.exec_cmd("~/.config/hypr/scripts/osd_brightness.sh down 10"), {
    locked = true,
    repeating = true
})
hl.bind("SUPER + F6", hl.dsp.exec_cmd("~/.config/hypr/scripts/toggle_brightness.sh"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.global("quickshell:regionScreenshot"))
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioStop", hl.dsp.exec_cmd("playerctl stop"), { locked = true })

-- Islands: toggle bar edit mode
hl.bind("SUPER + SHIFT + E", hl.dsp.exec_cmd("printf 'edit' > /tmp/qs_island_toggle"))

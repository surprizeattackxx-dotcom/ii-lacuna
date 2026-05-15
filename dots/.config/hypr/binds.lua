-- Keybindings
-- Uses globals: apps, mainMod (defined in hyprland.lua)

-- App launchers
local app_binds = {
    { "RETURN", apps.terminal    },
    { "E",      apps.fileManager },
    { "B",      apps.browser     },
    { "R",      apps.launcher    },
}
for _, bind in ipairs(app_binds) do
    hl.bind(mainMod .. " + " .. bind[1], hl.dsp.exec_cmd(bind[2]))
end

-- Window management
hl.bind(mainMod .. " + Q",              hl.dsp.window.close())
hl.bind("ALT + F4",                     hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + ALT + Q", hl.dsp.exec_cmd("hyprctl kill"))
hl.bind(mainMod .. " + P",             hl.dsp.window.pin())
hl.bind(mainMod .. " + F",             hl.dsp.exec_cmd("~/.config/hypr/scripts/toggle_fullscreen.sh"))
hl.bind(mainMod .. " + S",             hl.dsp.exec_cmd("~/.config/hypr/scripts/toggle_suspend_games.sh"))
hl.bind(mainMod .. " + SEMICOLON",     hl.dsp.layout("splitratio -0.1"))
hl.bind(mainMod .. " + APOSTROPHE",    hl.dsp.layout("splitratio +0.1"))
hl.bind("SUPER + P", hl.dsp.window.pseudo())

-- Focus direction
hl.bind(mainMod .. " + LEFT",          hl.dsp.focus({ direction = "left"  }))
hl.bind(mainMod .. " + RIGHT",         hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + UP",            hl.dsp.focus({ direction = "up"    }))
hl.bind(mainMod .. " + DOWN",          hl.dsp.focus({ direction = "down"  }))

-- Move window
hl.bind(mainMod .. " + SHIFT + LEFT",  hl.dsp.window.move({ direction = "left"  }))
hl.bind(mainMod .. " + SHIFT + RIGHT", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + UP",    hl.dsp.window.move({ direction = "up"    }))
hl.bind(mainMod .. " + SHIFT + DOWN",  hl.dsp.window.move({ direction = "down"  }))

-- Workspace switching: 1–10 on DP-1
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,          hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key,  hl.dsp.window.move({ workspace = i }))
end

-- Workspace switching: 11–20 on DP-2 (ALT + 0-9)
for i = 11, 20 do
    local key = (i - 10) % 10
    hl.bind(mainMod .. " + ALT + " .. key,          hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + ALT + SHIFT + " .. key,  hl.dsp.window.move({ workspace = i }))
end

-- Mouse binds
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Launcher toggle
hl.bind(mainMod .. " + D",          hl.dsp.exec_cmd("hamr toggle"))

-- hymini workspace overview
hl.bind(mainMod .. " + O",          hl.dsp.exec_cmd("hyprctl dispatch hymini:toggle"))

-- Shell & UI
hl.bind(mainMod .. " + V",          hl.dsp.global("quickshell:overviewClipboardToggle"))
hl.bind(mainMod .. " + PERIOD",     hl.dsp.global("quickshell:overviewEmojiToggle"))
hl.bind(mainMod .. " + A",          hl.dsp.global("quickshell:sidebarLeftToggle"))
hl.bind(mainMod .. " + N",          hl.dsp.global("quickshell:sidebarRightToggle"))
hl.bind(mainMod .. " + SLASH",      hl.dsp.global("quickshell:cheatsheetToggle"))
hl.bind(mainMod .. " + ALT + V",    hl.dsp.global("quickshell:calendarAppToggle"))
hl.bind(mainMod .. " + K",          hl.dsp.global("quickshell:oskToggle"))
hl.bind(mainMod .. " + M",          hl.dsp.global("quickshell:mediaControlsToggle"))
hl.bind(mainMod .. " + G",          hl.dsp.global("quickshell:overlayToggle"))
hl.bind(mainMod .. " + J",          hl.dsp.global("quickshell:barToggle"))
hl.bind(mainMod .. " + W",          hl.dsp.global("quickshell:wallpaperChangerToggle"))
hl.bind(mainMod .. " + X",          hl.dsp.global("quickshell:animations"))
hl.bind(mainMod .. " + I",          hl.dsp.exec_cmd("qs -p ~/.config/quickshell/ii/settings-launcher.qml"))
hl.bind(mainMod .. " + L",          hl.dsp.global("quickshell:lock"))
hl.bind("CTRL + ALT + DELETE",      hl.dsp.global("quickshell:sessionToggle"))

hl.bind("SUPER + TAB", hl.dsp.exec_cmd("/home/donnie/projects/hypr-plugins/hymission/debug_toggle.sh"))



-- Per-monitor gamma GUI
hl.bind(mainMod .. " + H", hl.dsp.exec_cmd("/home/donnie/projects/hypr-gamma/gui/build-gui/hyprgamma-gui"))

-- Utilities
hl.bind(mainMod .. " + SHIFT + S",  hl.dsp.global("quickshell:regionScreenshot"))
hl.bind(mainMod .. " + SHIFT + A",  hl.dsp.global("quickshell:regionSearch"))
hl.bind(mainMod .. " + SHIFT + X",  hl.dsp.global("quickshell:regionOcr"))
hl.bind(mainMod .. " + SHIFT + T",  hl.dsp.global("quickshell:screenTranslate"))
hl.bind(mainMod .. " + SHIFT + C",  hl.dsp.exec_cmd("hyprpicker -a"))
hl.bind(mainMod .. " + SHIFT + R",  hl.dsp.global("quickshell:regionRecord"))

-- Audio
hl.bind("CTRL + SUPER + V",              hl.dsp.exec_cmd("pavucontrol"))

-- Config shortcuts
hl.bind("CTRL + SUPER + R",              hl.dsp.exec_cmd("~/.config/hypr/scripts/reload.sh"))
hl.bind("CTRL + " .. mainMod .. " + SLASH",          hl.dsp.exec_cmd("xdg-open ~/.config/illogical-impulse/config.json"))
hl.bind("CTRL + " .. mainMod .. " + ALT + SLASH",    hl.dsp.exec_cmd("xdg-open ~/.config/hypr/custom/keybinds.conf"))

-- Exit
hl.bind(mainMod .. " + SHIFT + M",  hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit"))

-- Media keys
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),   { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),         { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),        { locked = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),      { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("~/.config/hypr/scripts/osd_brightness.sh up"),        { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("~/.config/hypr/scripts/osd_brightness.sh down"),      { locked = true, repeating = true })
hl.bind(mainMod .. " + F5",      hl.dsp.exec_cmd("~/.config/hypr/scripts/osd_brightness.sh down 10"),     { locked = true, repeating = true })
hl.bind(mainMod .. " + F6",      hl.dsp.exec_cmd("~/.config/hypr/scripts/toggle_brightness.sh"),        { locked = true }) -- max brightness
hl.bind("XF86AudioNext",         hl.dsp.exec_cmd("playerctl next"),                                    { locked = true })
hl.bind("XF86AudioPrev",         hl.dsp.exec_cmd("playerctl previous"),                               { locked = true })
hl.bind("XF86AudioPlay",         hl.dsp.exec_cmd("playerctl play-pause"),                             { locked = true })
hl.bind("XF86AudioPause",        hl.dsp.exec_cmd("playerctl play-pause"),                             { locked = true })
hl.bind("XF86AudioStop",         hl.dsp.exec_cmd("playerctl stop"),                                    { locked = true })

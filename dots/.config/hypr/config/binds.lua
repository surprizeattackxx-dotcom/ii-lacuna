-- Keybindings
-- Uses globals: mainMod (hyprland.lua), app variables (variables.lua)

local function bind(k, a, o)
    hl.bind(k, a, o)
end

local function ws_bind(mod, num, ws)
    bind(mod .. " + " .. num, hl.dsp.focus({ workspace = ws }))
    bind(mod .. " + SHIFT + " .. num, hl.dsp.window.move({ workspace = ws }))
end

-- Apps
bind("SUPER + RETURN", hl.dsp.exec_cmd("uwsm app -- " .. terminal))
bind("SUPER + E", hl.dsp.exec_cmd("uwsm app -- " .. fileManager))
bind("SUPER + B", hl.dsp.exec_cmd("uwsm app -- " .. browser))
bind("SUPER + C", hl.dsp.exec_cmd("uwsm app -- " .. claude))
bind("SUPER + O", hl.dsp.exec_cmd("uwsm app -- " .. opencode))
bind("CTRL + SHIFT + ESCAPE", hl.dsp.exec_cmd("uwsm app -- " .. taskManager))
bind("SUPER + R", hl.dsp.exec_cmd("hamr"))
bind("SUPER + Q", hl.dsp.window.close())
bind("ALT + F4", hl.dsp.window.close())
bind("SUPER + SHIFT + Q", hl.dsp.exec_cmd("~/.config/hypr/scripts/kill_hovered.sh"))
bind("SUPER + P", hl.dsp.window.pin())
bind("SUPER + F", hl.dsp.exec_cmd("~/.config/hypr/scripts/toggle_fullscreen.sh"))
bind("SUPER + ALT + SPACE", hl.dsp.exec_cmd("python3 ~/.config/hypr/scripts/dvd-bounce.py"))
bind("SUPER + SHIFT + SPACE", hl.dsp.window.float({ action = "toggle" }))
bind("SUPER + S", hl.dsp.exec_cmd("~/.config/hypr/scripts/toggle_suspend_games.sh"))
bind("SUPER + SHIFT + V", hl.dsp.exec_cmd("~/.local/bin/desktop-vnc-toggle"))
bind("SUPER + SEMICOLON", hl.dsp.layout("splitratio -0.1"))
bind("SUPER + APOSTROPHE", hl.dsp.layout("splitratio +0.1"))

bind("CTRL + SUPER + T", hl.dsp.exec_cmd("noctalia msg panel-toggle wallpaper"))
bind("CTRL + SUPER + ALT + T", hl.dsp.exec_cmd("noctalia msg wallpaper-random"))

-- Zoom
for _, v in pairs({
    {"SUPER + EQUAL", "increase"},
    {"SUPER + MINUS", "decrease"},
    {"SUPER + KP_ADD", "increase"},
    {"SUPER + KP_SUBTRACT", "decrease"}
}) do
    bind(v[1], hl.dsp.exec_cmd("~/.config/hypr/scripts/zoom.sh " .. v[2] .. " 0.5"))
end

-- Focus / Move
for _, d in ipairs({"left","right","up","down"}) do
    bind("SUPER + " .. d:upper(), hl.dsp.focus({direction=d}))
    bind("SUPER + SHIFT + " .. d:upper(), hl.dsp.window.move({direction=d}))
end

-- Scrolling layout
local scroll = {
    ["SUPER + ALT + RIGHT"]="move +col",
    ["SUPER + ALT + LEFT"]="move -col",
    ["SUPER + ALT + SHIFT + RIGHT"]="swapcol r",
    ["SUPER + ALT + SHIFT + LEFT"]="swapcol l",
    ["SUPER + ALT + I"]="consume",
    ["SUPER + ALT + O"]="expel",
    ["SUPER + ALT + F"]="fit active",
    ["SUPER + ALT + C"]="center",
    ["SUPER + ALT + W"]="colresize +conf"
}
for k,v in pairs(scroll) do bind(k, hl.dsp.layout(v)) end

-- Workspaces 1-30
-- Modifier order mirrors the physical monitor layout: CTRL (leftmost key) is
-- DP-1 (leftmost screen), ALT is HDMI-A-1. Blocks come from MONITOR_BLOCKS.
for i=1,9 do
    ws_bind("SUPER", i, i)            -- DP-2      1-10
    ws_bind("SUPER + CTRL", i, i+10)  -- DP-1     11-20
    ws_bind("SUPER + ALT", i, i+20)   -- HDMI-A-1 21-30
end

ws_bind("SUPER", 0, 10)
ws_bind("SUPER + CTRL", 0, 20)
ws_bind("SUPER + ALT", 0, 30)

-- ─── F-key workspaces ──────────────────────────
-- Bare F1-F10 jump to the focused monitor's own block (DP-2 1-10, DP-1 11-20,
-- HDMI-A-1 21-30), resolved at press time from MONITOR_BLOCKS in variables.lua.
-- No modifier means a global grab, so config/handlers.lua switches these off
-- while a game / RuneLite / Minecraft window holds focus; SUPER+SHIFT+F is a
-- manual override that force-disables them anywhere (survives reloads).
-- hl.bind is called directly rather than the local bind() helper above: the
-- helper discards the return value, and the gate needs the bind handles.
-- The Lua context persists across hyprctl reloads, so the handle table is
-- RESET every run (stale handles from the previous run are dead).
__fkeys = { binds = {} }
__fkeys_manual_off = __fkeys_manual_off or false

local function fkey_target(n)
    local m = hl.get_active_monitor()
    if not m then return nil end
    for _, b in ipairs(MONITOR_BLOCKS) do
        if b.monitor == m.name then return b.first + n - 1 end
    end
    return nil
end

for i = 1, 10 do
    local kb = hl.bind("F" .. i, function()
        local ws = fkey_target(i)
        if ws then hl.dispatch(hl.dsp.focus({ workspace = ws })) end
    end, { description = "workspace " .. i .. " on focused monitor" })
    if kb then __fkeys.binds[#__fkeys.binds + 1] = kb end
end

bind("SUPER + SHIFT + F", function()
    __fkeys_manual_off = not __fkeys_manual_off
    if __handlers and __handlers.refresh_fkey_gate then
        __handlers.refresh_fkey_gate()
    end
    hl.notification.create({
        text = __fkeys_manual_off
            and "⌨ F-key workspaces OFF — apps keep their F-keys"
            or "⌨ F-key workspaces ON (auto-gated)",
        timeout = 3000,
    })
end, { description = "toggle bare F-key workspace switching" })

-- Mouse
bind("SUPER + mouse:272", hl.dsp.window.drag(), {mouse=true})
bind("SUPER + mouse:273", hl.dsp.window.resize(), {mouse=true})

-- Noctalia / Shell
local panels = {
    ["SUPER + D"]="hamr toggle",
    ["SUPER + U"]="claude-usage-float",
    ["SUPER + V"]="noctalia msg panel-toggle clipboard",
    ["SUPER + PERIOD"]="noctalia msg panel-toggle launcher /emo",
    ["SUPER + A"]="noctalia msg panel-toggle control-center",
    ["SUPER + N"]="noctalia msg panel-toggle control-center notifications",
    ["SUPER + ALT + V"]="noctalia msg panel-toggle control-center calendar",
    ["SUPER + M"]="noctalia msg panel-toggle control-center media",
    ["SUPER + G"]="noctalia msg panel-toggle control-center system-monitor",
    ["SUPER + J"]="noctalia msg bar-toggle",
    ["SUPER + W"]="noctalia msg panel-toggle wallpaper",
    ["SUPER + SPACE"]="noctalia msg panel-toggle launcher",
    ["SUPER + I"]=settingsApp,
    ["SUPER + L"]="noctalia msg session lock"
}
for k,v in pairs(panels) do bind(k, hl.dsp.exec_cmd(v)) end

-- System
bind("CTRL + ALT + DELETE", hl.dsp.exec_cmd("noctalia msg panel-toggle session"))

if hl.plugin.hymission then
    bind("SUPER + TAB", hl.plugin.hymission.toggle)
end

bind("SUPER + Z", hl.dsp.exec_cmd("pypr zoom"))
bind("SUPER + H", hl.dsp.exec_cmd("$HOME/Projects/hypr-gamma/gui/build/hyprgamma-gui"))
bind("SUPER + SHIFT + G", function()
    if __handlers and __handlers.toggle_gaming then __handlers.toggle_gaming() end
end)
bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("noctalia msg screenshot-region"))
bind("SUPER + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"))
bind("CTRL + SUPER + V", hl.dsp.exec_cmd(volumeMixer))
bind("CTRL + SUPER + R", hl.dsp.exec_cmd("~/.config/hypr/scripts/reload.sh"))
bind("CTRL + SUPER + SLASH", hl.dsp.exec_cmd("xdg-open ~/.config/illogical-impulse/config.json"))
bind("CTRL + SUPER + ALT + SLASH", hl.dsp.exec_cmd("xdg-open ~/.config/hypr/config/binds.lua"))
bind("SUPER + SHIFT + M", hl.dsp.exec_cmd("pw-play ~/.local/share/sounds/osrs/death.ogg & sleep 3; command -v hyprshutdown >/dev/null && hyprshutdown || hyprctl dispatch exit"))

-- Media
bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), {locked=true,repeating=true})
bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), {locked=true,repeating=true})
bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), {locked=true})
bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), {locked=true})

for _,v in ipairs({
    "XF86MonBrightnessUp",
    "XF86MonBrightnessDown"
}) do
    bind(v, hl.dsp.exec_cmd("~/.config/hypr/scripts/osd_brightness.sh"), {locked=true,repeating=true})
end

bind("SUPER + F5", hl.dsp.exec_cmd("~/.config/hypr/scripts/osd_brightness.sh down 10"), {locked=true,repeating=true})
bind("SUPER + F6", hl.dsp.exec_cmd("~/.config/hypr/scripts/toggle_brightness.sh"), {locked=true})

for _,v in ipairs({
    {"XF86AudioNext","next"},
    {"XF86AudioPrev","previous"},
    {"XF86AudioPause","play-pause"},
    {"XF86AudioStop","stop"}
}) do
    bind(v[1], hl.dsp.exec_cmd("playerctl " .. v[2]), {locked=true})
end

bind("CTRL + SUPER + RIGHT", hl.dsp.exec_cmd("playerctl next"))
bind("CTRL + SUPER + LEFT", hl.dsp.exec_cmd("playerctl previous"))

bind("Control_R", hl.dsp.exec_cmd("ydotool click 0xC0"))

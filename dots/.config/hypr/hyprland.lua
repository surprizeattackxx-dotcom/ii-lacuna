-- ─── App Definitions ───────────────────────────
apps = {
    terminal    = "kitty",
    fileManager = "dolphin",
    browser     = "google-chrome-stable",
    launcher    = "hamr",
    editor      = "kate",}

mainMod = "SUPER"

local cfg = os.getenv("HOME") .. "/.config/hypr/"

-- ─── Config Includes ───────────────────────────
dofile(cfg .. "monitors.lua")
dofile(cfg .. "modules/dynamic-monitors.lua")
dofile(cfg .. "env.lua")
dofile(cfg .. "autostart.lua")
dofile(cfg .. "look-and-feel.lua")
dofile(cfg .. "animations.lua")
dofile(cfg .. "input.lua")
dofile(cfg .. "workspaces.lua")
dofile(cfg .. "rules.lua")
dofile(cfg .. "binds.lua")
dofile(cfg .. "variables.lua")
dofile(cfg .. "hyprland/colors.lua") -- matugen wallpaper-derived border/bg colors (must be last to win)
local _overrides = cfg .. "hyprland/shellOverrides/main.lua"
if io.open(_overrides, "r") then dofile(_overrides) end

hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")

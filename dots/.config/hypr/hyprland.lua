-- Hyprland 0.55 Lua Configuration
-- Modular entry point
-- https://wiki.hypr.land/Configuring/

-- Shared globals (accessible by all modules)
apps = {
    terminal    = "kitty",
    fileManager = "dolphin",
    browser     = "google-chrome-beta",
    launcher    = "hamr",
    editor      = "kate",
}
mainMod = "SUPER"

-- Config dir
local cfg = os.getenv("HOME") .. "/.config/hypr/"

-- Load modules in order
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

hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")

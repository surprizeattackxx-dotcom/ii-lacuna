-- CachyOS Hyprland Configuration

require("config.cheatsheet") -- must load before config.binds (wraps hl.bind)
require("config.animations")
require("config.autostart")
require("config.colors")
require("config.decorations")
require("config.variables")
require("config.environment")
require("config.inputs")
require("config.binds")
require("config.misc")
require("config.monitors")
require("config.windowrules")
require("config.workspaces")
require("config.handlers") -- event handlers (lifeguard, RuneLite, game mode) + cheatsheet dump; keep last

-- For Noctalia Color templates
require("noctalia").apply_theme()

-- Hyprland Visual Editor overlay, persisted by scripts/hve-lua/hve-apply.sh.
-- Loaded last so it can override anything above; optional, may not exist yet.
do
    local hve_path = os.getenv("HOME") .. "/.config/hypr/hve.lua"
    local f = io.open(hve_path, "r")
    if f then
        f:close()
        dofile(hve_path)
    end
end

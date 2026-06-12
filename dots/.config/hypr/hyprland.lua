mainMod = "SUPER"

local cfg = os.getenv("HOME") .. "/.config/hypr/"

-- ─── Config Includes ───────────────────────────
dofile(cfg .. "hyprland/variables.lua")
dofile(cfg .. "monitors.lua")
dofile(cfg .. "hyprland/env.lua")
dofile(cfg .. "hyprland/autostart.lua")
dofile(cfg .. "hyprland/look-and-feel.lua")
dofile(cfg .. "animations.lua")
dofile(cfg .. "hyprland/input.lua")
dofile(cfg .. "hyprland/workspaces.lua")
dofile(cfg .. "hyprland/rules.lua")
dofile(cfg .. "hyprland/binds.lua")

-- ─── User Overrides ────────────────────────────
for _, f in ipairs({ "variables", "env", "autostart", "look-and-feel", "input", "workspaces", "rules", "binds" }) do
  local p = cfg .. "custom/" .. f .. ".lua"
  if io.open(p, "r") then dofile(p) end
end

dofile(cfg .. "hyprland/colors.lua") -- matugen wallpaper-derived border/bg colors (must be last to win)
local _overrides = cfg .. "hyprland/shellOverrides/main.lua"
if io.open(_overrides, "r") then dofile(_overrides) end

hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")

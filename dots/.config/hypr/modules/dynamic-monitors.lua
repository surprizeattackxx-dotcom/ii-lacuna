-- Dynamic Monitor State Module
-- Reads state file written by monitor-watch.sh
-- Usage: dofile(cfg .. "modules/dynamic-monitors.lua")
-- Then check: Monitors.active, Monitors:isActive("DP-1"), etc.

local STATE_FILE = os.getenv("HOME") .. "/.config/hypr/monitor-state.lua"

-- ─── State ─────────────────────────────────────
Monitors = {}

function Monitors:reload()
    local f = io.open(STATE_FILE, "r")
    if not f then
        self.active = {}
        self.disabled = {}
        self.moved = {}
        return
    end
    local raw = f:read("*a")
    f:close()
    local ok, data = pcall(load, raw)
    if not ok then
        self.active = {}
        self.disabled = {}
        self.moved = {}
        return
    end
    local ok2, result = pcall(data)
    if not ok2 or type(result) ~= "table" then
        self.active = {}
        self.disabled = {}
        self.moved = {}
        return
    end
    self.active = result.active or {}
    self.disabled = result.disabled or {}
    self.moved = result.moved or {}
end

function Monitors:isActive(name)
    for _, m in ipairs(self.active) do
        if m == name then return true end
    end
    return false
end

function Monitors:isDisabled(name)
    for _, m in ipairs(self.disabled) do
        if m == name then return true end
    end
    return false
end

function Monitors:list()
    return self.active
end

-- ─── Moved Workspace Tracking ──────────────────
function Monitors:isMoved(name)
    return self.moved[name] ~= nil
end

function Monitors:getMovedWorkspaces(name)
    return self.moved[name] or {}
end

Monitors:reload()

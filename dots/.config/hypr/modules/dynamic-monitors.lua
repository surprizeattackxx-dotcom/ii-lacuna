-- Dynamic Monitor State Module
-- Reads state file written by monitor-watch.sh
-- Usage: dofile(cfg .. "modules/dynamic-monitors.lua")
-- Then check: Monitors.active, Monitors:isActive("DP-1"), etc.

local STATE_FILE = os.getenv("HOME") .. "/.config/hypr/monitor-state.lua"

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
    data = data()
    self.active = data.active or {}
    self.disabled = data.disabled or {}
    self.moved = data.moved or {}
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

function Monitors:isMoved(name)
    return self.moved[name] ~= nil
end

function Monitors:getMovedWorkspaces(name)
    return self.moved[name] or {}
end

Monitors:reload()

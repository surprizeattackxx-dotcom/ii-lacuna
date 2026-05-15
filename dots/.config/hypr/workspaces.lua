-- Workspace Rules

-- Smart gaps: single window or fullscreen gets no gaps
hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })

-- Monitor workspace assignment — reads from monitor-state.lua for actual names
local state_file = os.getenv("HOME") .. "/.config/hypr/monitor-state.lua"
local monitors = {}
local f = io.open(state_file, "r")
if f then
    local content = f:read("*all")
    f:close()
    for name in content:gmatch('"([A-Z0-9%-]+)"') do
        table.insert(monitors, name)
    end
end

-- Fallback if state file doesn't exist yet
if #monitors == 0 then
    monitors = { "DP-1", "DP-2", "HDMI-A-1" }
end

-- Monitor 1 → workspaces 1–10
for i = 1, 10 do
    hl.workspace_rule({
        workspace = tostring(i),
        monitor   = monitors[1] or "DP-1",
        default   = (i == 1),
    })
end

-- Monitor 2 → workspaces 11–20
for i = 11, 20 do
    hl.workspace_rule({
        workspace = tostring(i),
        monitor   = monitors[2] or "DP-2",
        default   = (i == 11),
    })
end

-- Monitor 3 → workspaces 21–30
for i = 21, 30 do
    hl.workspace_rule({
        workspace = tostring(i),
        monitor   = monitors[3] or "HDMI-A-1",
        default   = (i == 21),
    })
end

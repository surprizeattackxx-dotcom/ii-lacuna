-- Workspace Rules

-- Smart gaps: single window or fullscreen gets no gaps
hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })

-- Monitor DP-1 → workspaces 1–10
for i = 1, 10 do
    hl.workspace_rule({
        workspace = tostring(i),
        monitor   = "DP-1",
        default   = (i == 1),
    })
end

-- Monitor DP-2 → workspaces 11–20
for i = 11, 20 do
    hl.workspace_rule({
        workspace = tostring(i),
        monitor   = "DP-2",
        default   = (i == 11),
    })
end

-- Monitor HDMI-A-1 → workspaces 21–30
for i = 21, 30 do
    hl.workspace_rule({
        workspace = tostring(i),
        monitor   = "HDMI-A-1",
        default   = (i == 21),
    })
end

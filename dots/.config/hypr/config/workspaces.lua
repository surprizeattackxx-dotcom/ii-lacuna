-- Workspace Rules

-- ─── Smart Gaps ────────────────────────────────
-- Single window or fullscreen gets no gaps
hl.workspace_rule({ gaps_in = 0, gaps_out = 0, workspace = "w[tv1]" })
hl.workspace_rule({ gaps_in = 0, gaps_out = 0, workspace = "f[1]" })

-- ─── Monitor → Workspace Binding ───────────────
-- Each monitor owns a block of 10 workspaces; the first in each block is default.
local monitor_blocks = {
    { monitor = "DP-2", first = 1 },
    { monitor = "DP-1", first = 11 },
    { monitor = "HDMI-A-1", first = 21 },
}
for _, b in ipairs(monitor_blocks) do
    for ws = b.first, b.first + 9 do
        hl.workspace_rule({ monitor = b.monitor, workspace = ws, default = ws == b.first })
        end
        end

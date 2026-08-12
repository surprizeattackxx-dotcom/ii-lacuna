-- Workspace Rules

-- ─── Smart Gaps ────────────────────────────────
-- Single window or fullscreen gets no gaps
hl.workspace_rule({ gaps_in = 0, gaps_out = 0, workspace = "w[tv1]" })
hl.workspace_rule({ gaps_in = 0, gaps_out = 0, workspace = "f[1]" })

-- ─── Monitor → Workspace Binding ───────────────
-- Each monitor owns a block of 10 workspaces; the first in each block is default.
-- MONITOR_BLOCKS lives in config/variables.lua (loads first) so these rules and
-- the bare F-key workspace binds share one table and can't drift apart.
for _, b in ipairs(MONITOR_BLOCKS) do
    for ws = b.first, b.first + 9 do
        hl.workspace_rule({ monitor = b.monitor, workspace = ws, default = ws == b.first, persistent = true })
    end
end

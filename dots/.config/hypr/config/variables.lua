-- ─── Apps ──────────────────────────────────────
terminal = "kitty"
fileManager = "dolphin"
browser = "google-chrome-stable-themed"
codeEditor = "kate"
textEditor = "kate"
volumeMixer = "pavucontrol-qt"
settingsApp = "qs -c noctalia-shell ipc call settings toggle"
taskManager = "kitty -1 fish -c btop"

workspaceGroupSize = 10

-- ─── UPPERCASE globals expected by the stock config/ files ─────
-- The stock CachyOS config/*.lua (binds, windowrules) reference these
-- UPPERCASE names; mapped to the lowercase values above so there's one
-- source of truth.
TERMINAL     = terminal
FILE_MANAGER = fileManager
BROWSER      = browser
EDITOR       = codeEditor
CALCULATOR   = "gnome-calculator"

-- Monitors — MONITOR1/2/3 back the SUPER+SHIFT+1/2/3 "move window to monitor"
-- binds. Reorder these names to change which physical screen is 1/2/3.
MONITOR1 = "DP-2"       -- primary (currently focused)
MONITOR2 = "HDMI-A-1"
MONITOR3 = "DP-1"
PRIMARY_MONITOR = MONITOR1

-- Workspaces per monitor (drives the SUPER+SHIFT+CONTROL+n move binds)
NUM_WPM = workspaceGroupSize

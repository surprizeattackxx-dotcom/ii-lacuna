-- ─── Apps ──────────────────────────────────────
terminal = "kitty"
fileManager = "dolphin"
browser = "google-chrome-stable"
codeEditor = "micro"
volumeMixer = "pavucontrol-qt"
settingsApp = "noctalia msg settings-toggle"
taskManager = "kitty -1 fish -c btop"
claude = "claude-desktop"
opencode = "ai.opencode.opencode"

-- Primary monitor, used by windowrules.lua to pin .exe/discord/vesktop windows.
PRIMARY_MONITOR = "DP-2"

-- ─── Game client classes ───────────────────────
-- Different launchers stamp different WM_CLASS on the same client (the raw
-- jar: net-runelite-client-RuneLite; the official RuneLite launcher app:
-- net-runelite-launcher-Launcher — found live 2026-07-22) even though the
-- window title is always "RuneLite" pre-login. RS3 (Steam build, app 1343400)
-- was given the identical treatment on 2026-08-12: full opacity, the same
-- workspace pin, F-keys reserved, and the cursor-centered float in
-- handlers.lua instead of fullscreen. Shared here (loads before windowrules
-- AND handlers) so the workspace pin and the placement handler can't drift
-- apart — add a new launcher's class in exactly one place.
RUNELITE_CLASSES = {
    ["net-runelite-client-RuneLite"] = true,
    ["net-runelite-launcher-Launcher"] = true,
}
-- Two RS3 launchers, two different WM_CLASSes for the same game (both verified
-- live via `hyprctl clients -j`, 2026-08-12): Steam stamps steam_app_1343400,
-- while Bolt's rs2client comes through XWayland as a plain "RuneScape". Both
-- carry initial_title "RuneScape". Only the Steam one matches the generic
-- gamingApps rules in windowrules.lua, so only it needs the carve-outs there —
-- but both need the confine-pointer exemption, since that keys off content.
RS3_CLASSES = {
    ["steam_app_1343400"] = true,
    ["RuneScape"] = true,
}

-- PartyDeck (the Hyprland fork at ~/Projects/partydeck) wraps every instance
-- in gamescope, which reports class "gamescope" (or "gamescope-kbm" once the
-- mouse/keyboard build lands). It needs the OPPOSITE of the generic Steam
-- treatment: no forced fullscreen, no gaming-workspace shove — PartyDeck's own
-- Rust-side splitscreen daemon (src/hyprland.rs) floats, resizes and positions
-- each instance into its own tile itself, live, the same way it dispatches
-- window.float/resize/move for RS3's placement above. Verified live
-- 2026-08-16 (hyprctl eval) that the fullscreen_state=2 rule fights any
-- resize/move dispatch aimed at a window still under it — same reason RS3 is
-- carved out. Only class this box will ever hand gamescope-class windows to,
-- since nothing else here launches raw gamescope.
PARTYDECK_CLASSES = {
    ["gamescope"] = true,
    ["gamescope-kbm"] = true,
}
PARTYDECK_CLASS_PATTERN = class_pattern(PARTYDECK_CLASSES)

-- Every class that gets the game-client treatment, mapped to the exact
-- initial_title its MAIN window carries. Popups/panels share the WM_CLASS but
-- not that title — that's how handlers.lua places only the real client.
-- Both titles verified live via `hyprctl clients -j` (RS3 = "RuneScape",
-- 2026-08-12; RuneLite = "RuneLite", 2026-07-22).
GAME_CLIENT_CLASSES = {}
GAME_CLIENT_MAIN_TITLE = {}
for c in pairs(RUNELITE_CLASSES) do
    GAME_CLIENT_CLASSES[c] = true
    GAME_CLIENT_MAIN_TITLE[c] = "RuneLite"
end
for c in pairs(RS3_CLASSES) do
    GAME_CLIENT_CLASSES[c] = true
    GAME_CLIENT_MAIN_TITLE[c] = "RuneScape"
end

local function class_pattern(tbl)
    local alts = {}
    for c in pairs(tbl) do alts[#alts + 1] = c end
    table.sort(alts)
    return "^(" .. table.concat(alts, "|") .. ")$"
end

GAME_CLIENT_CLASS_PATTERN = class_pattern(GAME_CLIENT_CLASSES)
-- RS3 alone: windowrules.lua needs it to carve RS3 out of the generic Steam
-- gaming rules (fullscreen + gaming workspace) that RuneLite never matched.
RS3_CLASS_PATTERN = class_pattern(RS3_CLASSES)
RS3_MAIN_TITLE_PATTERN = "^(RuneScape)$"

-- ─── Monitor → workspace blocks ────────────────
-- Each monitor owns a block of 10 workspaces; the first in each block is its
-- default. Shared here (loads before binds, workspaces AND handlers) so the
-- workspace rules and the bare F-key binds resolve from one table instead of
-- two that silently drift — same reasoning as RUNELITE_CLASSES above.
MONITOR_BLOCKS = {
    { monitor = "DP-2",     first = 1 },
    { monitor = "DP-1",     first = 11 },
    { monitor = "HDMI-A-1", first = 21 },
}

-- ─── F-key gate ────────────────────────────────
-- Bare F1-F10 are bound to workspace switching in binds.lua. A no-modifier
-- bind is a global grab: the focused app never receives the key at all. These
-- apps genuinely need their own F-keys, so config/handlers.lua disables the
-- binds while one of them holds focus.
-- Minecraft's real window class is UNVERIFIED (2026-08-05): Prism-launched MC
-- wasn't running and the hyprland log had already rotated, so both class and
-- title are matched loosely. Next time it's open, check `hyprctl clients -j`
-- and narrow this to the real class.
-- Deliberately NOT gated, per Donnie 2026-08-05: Godot and Chrome. Use the
-- SUPER+SHIFT+F manual override to reclaim F-keys in those.
local function contains_ci(s, needle)
    return type(s) == "string" and s:lower():find(needle, 1, true) ~= nil
end

function fkey_gate_match(w)
    if not w then return false end
    local ok, res = pcall(function()
        if w.content_type == "game" then return true end
        if GAME_CLIENT_CLASSES[w.class] then return true end
        if contains_ci(w.class, "minecraft") or contains_ci(w.title, "minecraft") then
            return true
        end
        return false
    end)
    return ok and res or false
end

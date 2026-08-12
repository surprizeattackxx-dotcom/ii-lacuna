-- Runtime event handlers: window lifeguard, RuneLite placement, gaming mode.
-- Loaded LAST from hyprland.lua. Every callback body is pcall-guarded so a
-- handler bug can never break config load or the running session.
-- The Lua context persists across hyprctl reloads: previous subscriptions and
-- the sweep timer are cleaned up before re-registering.

if __handlers then
  for _, s in ipairs(__handlers.subs or {}) do
    pcall(function() s:remove() end)
  end
  if __handlers.sweep then
    pcall(function() __handlers.sweep:set_enabled(false) end)
  end
end
__handlers = { subs = {} }

-- ══ Lifeguard ═══════════════════════════════════════════════════════════
-- Floating windows that restore their own saved position can land outside
-- every monitor (RuneLite at x=-3822, Rockstar at [-2434, 2940] — the layout
-- has no output covering the top-left quadrant). Unreachable by normal focus.
-- Detect by geometry intersection (w.visible stays true off-screen — tested)
-- and rescue with the proven focus-by-address → center technique.

local RESCUE_EXCLUDE = {
  ["plasma-changeicons"] = true, -- deliberately parked at 999999,999999
}

local function offscreen(w)
  local ok, res = pcall(function()
    if not w.mapped or w.hidden or not w.floating then return false end
    if RESCUE_EXCLUDE[w.class] then return false end
    if w.workspace and w.workspace.special then return false end
    local wx, wy, ww, wh = w.at.x, w.at.y, w.size.x, w.size.y
    for _, m in ipairs(hl.get_monitors()) do
      if math.max(wx, m.x) < math.min(wx + ww, m.x + m.width)
        and math.max(wy, m.y) < math.min(wy + wh, m.y + m.height) then
        return false
      end
    end
    return true
  end)
  return ok and res or false
end

local function rescue(w)
  pcall(function()
    local prev = hl.get_active_window()
    hl.dispatch(hl.dsp.focus({ window = "address:" .. w.address }))
    hl.dispatch(hl.dsp.window.center())
    if prev and prev.address ~= w.address then
      hl.dispatch(hl.dsp.focus({ window = "address:" .. prev.address }))
    end
    local label = (w.class ~= "" and w.class) or w.title or "window"
    hl.notification.create({ text = "🛟 rescued off-screen " .. label, timeout = 4000 })
  end)
end

table.insert(__handlers.subs, hl.on("window.open", function(w)
  hl.timer(function()
    if offscreen(w) then rescue(w) end
  end, { timeout = 400, type = "oneshot" })
end))

-- hl.timer at config-load time SEGFAULTS in `--verify-config` mode (event
-- loop manager not initialized — same bug family as upstream #14414). Create
-- the sweep timer only in a live session: directly when monitors exist
-- (reload path), else deferred to hyprland.start (cold start; the event
-- never fires under verify, and hl.on registration itself is verify-safe).
local function start_sweep()
  __handlers.sweep = hl.timer(function()
    pcall(function()
      for _, w in ipairs(hl.get_windows({ floating = true, mapped = true })) do
        if offscreen(w) then rescue(w) end
      end
    end)
  end, { timeout = 8000, type = "repeat" })
end
if #hl.get_monitors() > 0 then
  start_sweep()
else
  table.insert(__handlers.subs, hl.on("hyprland.start", start_sweep))
end

-- ══ Game client main-window placement ═══════════════════════════════════
-- Float the MAIN client at the cursor, clamped on-screen with real math.
-- Main window only: initial_title is exactly "RuneLite" / "RuneScape" before
-- anything else is appended; popups/panels share the WM_CLASS but not that
-- title (this is what all four 2026-07-15 rule-based attempts couldn't
-- express — see the vault's Hyprland Lua Config note).
-- GAME_CLIENT_MAIN_TITLE (class → expected main-window title) is defined in
-- config/variables.lua, which loads before both this file and windowrules.lua,
-- so the workspace pin and this handler share one source of truth instead of
-- drifting. RS3 joined RuneLite here on 2026-08-12.

function __handlers.place_game_client(w)
  pcall(function()
    local main_title = GAME_CLIENT_MAIN_TITLE[w.class]
    if not (main_title and w.initial_title == main_title) then
      return
    end
    local m = w.monitor
    if not m then return end
    local W, H = math.floor(m.width * 0.62), math.floor(m.height * 0.70)
    hl.dispatch(hl.dsp.focus({ window = "address:" .. w.address }))
    if not w.floating then
      hl.dispatch(hl.dsp.window.float({ action = "on" }))
    end
    hl.dispatch(hl.dsp.window.resize({ exact = true, x = W, y = H }))
    local c = hl.get_cursor_pos() or { x = m.x + m.width / 2, y = m.y + m.height / 2 }
    local PAD = 20
    local x = math.max(m.x + PAD, math.min(c.x - W / 2, m.x + m.width - W - PAD))
    local y = math.max(m.y + PAD, math.min(c.y - 60, m.y + m.height - H - PAD))
    hl.dispatch(hl.dsp.window.move({ exact = true, x = math.floor(x), y = math.floor(y) }))
  end)
end

table.insert(__handlers.subs, hl.on("window.open", function(w)
  -- match inside the timer, not at event time: title props may not be
  -- committed yet in the window.open instant (map-time race, hit live
  -- 2026-07-22 — the at-event check silently never matched)
  hl.timer(function() __handlers.place_game_client(w) end, { timeout = 400, type = "oneshot" })
end))

-- ══ Gaming mode ═════════════════════════════════════════════════════════
-- Windows tagged content = "game" by the rules in windowrules.lua toggle
-- animations off while any game is open, back on when the last one closes.

local function game_count()
  local n = 0
  for _, w in ipairs(hl.get_windows()) do
    local ok, ct = pcall(function() return w.content_type end)
    if ok and ct == "game" then n = n + 1 end
  end
  return n
end

local function set_gaming(on)
  __handlers.gaming = on
  hl.config({ animations = { enabled = not on } })
  hl.notification.create({
    text = on and "🎮 game mode ON — animations off" or "🎮 game mode OFF — animations back",
    timeout = 3000,
  })
end

-- Manual override (SUPER+SHIFT+G in binds.lua). Manually-enabled game mode
-- must survive window-close events and reloads, so the flag is a plain
-- global (persists in the Lua context), not part of the per-reload table.
__gaming_manual = __gaming_manual or false

function __handlers.toggle_gaming()
  pcall(function()
    if __handlers.gaming then
      __gaming_manual = false
      set_gaming(false)
    else
      __gaming_manual = true
      set_gaming(true)
    end
  end)
end

table.insert(__handlers.subs, hl.on("window.open", function(w)
  -- content tag is applied by rules; give it a beat before checking
  hl.timer(function()
    pcall(function()
      if not __handlers.gaming and w.content_type == "game" then set_gaming(true) end
    end)
  end, { timeout = 500, type = "oneshot" })
end))

local function maybe_game_off()
  hl.timer(function()
    pcall(function()
      if __handlers.gaming and not __gaming_manual and game_count() == 0 then set_gaming(false) end
    end)
  end, { timeout = 500, type = "oneshot" })
end
table.insert(__handlers.subs, hl.on("window.close", maybe_game_off))
table.insert(__handlers.subs, hl.on("window.destroy", maybe_game_off))

-- A reload while game mode is active (open game or manual toggle) re-runs
-- config/animations.lua (animations back on) and resets __handlers —
-- re-detect and re-apply without a popup.
if __gaming_manual or game_count() > 0 then
  __handlers.gaming = true
  hl.config({ animations = { enabled = false } })
end

-- ══ F-key workspace gate ════════════════════════════════════════════════
-- Bare F1-F10 (binds.lua) are a global grab — the focused app never sees the
-- key — so apps that need their own F-keys get the binds switched off while
-- they hold focus. Which apps: fkey_gate_match() in config/variables.lua.
-- Deliberately idempotent: every call re-derives from the CURRENT active
-- window and sets ALL handles, rather than toggling state on each event.
-- Measured live 2026-08-05 (hyprctl repl): window.active fires TWICE per
-- focus change, and focus can land on no window at all. Re-deriving makes
-- both of those harmless instead of a permanent desync.

function __handlers.refresh_fkey_gate()
    pcall(function()
        local binds = (__fkeys or {}).binds
        if not binds or #binds == 0 then return end
        local gated = __fkeys_manual_off or fkey_gate_match(hl.get_active_window())
        for _, kb in ipairs(binds) do
            pcall(function() kb:set_enabled(not gated) end)
        end
        __handlers.fkeys_gated = gated
    end)
end

for _, ev in ipairs({ "window.active", "workspace.active", "window.close", "window.destroy" }) do
    local sub = hl.on(ev, function() __handlers.refresh_fkey_gate() end)
    if sub then table.insert(__handlers.subs, sub) end
end

-- Apply current state at load; same live-session guard as the sweep timer.
if #hl.get_monitors() > 0 then
    __handlers.refresh_fkey_gate()
else
    table.insert(__handlers.subs, hl.on("hyprland.start", __handlers.refresh_fkey_gate))
end

-- ══ Cheatsheet dump ═════════════════════════════════════════════════════
-- config.cheatsheet recorded every hl.bind during this config run; all
-- modules are loaded by now, so write the JSON for the noctalia panel.
-- Live sessions only: a `--verify-config` run executes this file too and
-- must not overwrite the JSON (its plugin binds don't register there, which
-- would skew the recorded set). Same live-detection as the sweep above.
local function dump_binds()
  if __cheat and __cheat.dump then pcall(__cheat.dump) end
end
if #hl.get_monitors() > 0 then
  dump_binds()
else
  table.insert(__handlers.subs, hl.on("hyprland.start", dump_binds))
end

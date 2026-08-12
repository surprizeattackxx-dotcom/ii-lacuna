-- Cheatsheet bind recorder — wraps hl.bind so every real, resolved bind is
-- recorded at registration time, then dumped as JSON for noctalia's cheatsheet
-- panel (Services/System/HyprlandKeybinds.qml reads the JSON). Replaces the
-- old parse_binds_lua.py regex parser, which couldn't resolve Lua variables.
-- Must be require()d BEFORE config.binds; config.handlers calls __cheat.dump()
-- as the last step of config load.
-- The Lua context persists across hyprctl reloads, so wrapping is guarded to
-- happen exactly once; the record table resets every run.

local HOME = os.getenv("HOME")
local BINDS_FILE = HOME .. "/.config/hypr/config/binds.lua"
local JSON_PATH = HOME .. "/.local/state/quickshell/hypr-binds.json"

__cheat = __cheat or {}
__cheat.records = {}
__cheat.bind_no = 0
__cheat.cmdmap = __cheat.cmdmap or setmetatable({}, { __mode = "k" })

-- ── static section map from binds.lua "─── Name ───" headers ──────────────
-- sections[i] = { line, name }; bind_lines[n] = line of the nth hl.bind(
-- call, used as a registration-order fallback when debug.getinfo doesn't
-- expose real file positions (Hyprland loads config chunks under opaque
-- names). Order-mapping is exact while binds.lua registers only literal,
-- top-level hl.bind calls and no other config file binds before it.
local sections, bind_lines = {}, {}
do
  local f = io.open(BINDS_FILE, "r")
  if f then
    local n = 0
    for line in f:lines() do
      n = n + 1
      local ascii = line:gsub("\226\148\128", "-") -- "─" (U+2500) → "-"
      local name = ascii:match("^%-%-%s*%-%-+%s*(.-)%s*%-%-+%s*$")
      if name and #name > 0 then
        sections[#sections + 1] = { line = n, name = name }
      end
      if line:find("hl%.bind%s*%(") and not line:match("^%s*%-%-") then
        bind_lines[#bind_lines + 1] = n
      end
    end
    f:close()
  end
end

local function category_for_line(line)
  local cat = "Other"
  for _, s in ipairs(sections) do
    if s.line < line then cat = s.name else break end
  end
  return cat
end

local function pretty_cmd(cmd)
  cmd = cmd:gsub("^uwsm app %-%- ", "")
  local ipc = cmd:match("^qs %-c noctalia%-shell ipc call (.+)$") or cmd:match("^noctalia msg (.+)$")
  if ipc then return "Shell: " .. ipc end
  return cmd
end

if not __cheat.wrapped then
  __cheat.wrapped = true
  -- originals kept reachable for live recovery via hyprctl repl:
  --   hl.bind = __cheat.orig_bind  (etc.)
  __cheat.orig_bind = hl.bind
  __cheat.orig_exec_cmd = hl.dsp.exec_cmd
  __cheat.orig_global = hl.dsp.global

  local orig_exec = hl.dsp.exec_cmd
  hl.dsp.exec_cmd = function(cmd, ...)
    local d = orig_exec(cmd, ...)
    __cheat.cmdmap[d] = pretty_cmd(tostring(cmd))
    return d
  end

  local orig_global = hl.dsp.global
  hl.dsp.global = function(name, ...)
    local d = orig_global(name, ...)
    __cheat.cmdmap[d] = "Shell: " .. tostring(name):gsub("^quickshell:", "")
    return d
  end

  local orig_bind = hl.bind
  hl.bind = function(keys, disp, opts)
    local kb = orig_bind(keys, disp, opts)
    __cheat.bind_no = __cheat.bind_no + 1
    local desc = (opts and (opts.description or opts.desc))
      or __cheat.cmdmap[disp] or ""
    local line
    local ok, info = pcall(debug.getinfo, 2, "Sl")
    if ok and info and info.source and info.source:find("binds", 1, true)
      and info.currentline and info.currentline > 0 then
      line = info.currentline
    else
      line = bind_lines[__cheat.bind_no]
    end
    __cheat.records[#__cheat.records + 1] = {
      key_combo = tostring(keys),
      category = line and category_for_line(line) or "Other",
      description = tostring(desc),
    }
    return kb
  end
end

local function json_escape(s)
  s = s:gsub("\\", "\\\\"):gsub('"', '\\"')
  return (s:gsub("%c", function(c) return string.format("\\u%04x", c:byte()) end))
end

function __cheat.dump()
  os.execute("mkdir -p '" .. HOME .. "/.local/state/quickshell'")
  local parts = {}
  for _, r in ipairs(__cheat.records) do
    parts[#parts + 1] = string.format(
      '{"key_combo":"%s","category":"%s","description":"%s"}',
      json_escape(r.key_combo), json_escape(r.category), json_escape(r.description))
  end
  local f = io.open(JSON_PATH, "w")
  if not f then return end
  f:write("[" .. table.concat(parts, ",") .. "]\n")
  f:close()
end

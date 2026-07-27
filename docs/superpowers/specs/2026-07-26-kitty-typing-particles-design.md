# Kitty Typing Particles

**Date:** 2026-07-26
**Status:** Pending review

## Goal

When you type a printable character or hit backspace in kitty (your default terminal), a small burst of particles explodes outward from the exact cell you just typed in and fades out, rendered on top of everything as a full-screen transparent overlay. Particles are colored from the active color scheme's `mPrimary`/`mSecondary` tokens — Aether cyan/violet when Aether is selected (what you asked for), but it re-colors automatically if you ever switch schemes, same as every other themed element in the shell.

## Non-Goals

- Not system-wide — only fires while a kitty window is focused and receiving the keystroke. Other terminals/apps do nothing. (We scoped this down from "all of Hyprland" earlier in brainstorming — no reliable caret-position signal exists outside kitty.)
- Not tracking every keystroke — only printable characters + backspace trigger a burst; modifiers, arrows, enter, tab, etc. are ignored.
- Not persisting particle state across a Quickshell restart — if noctalia-shell restarts mid-burst, in-flight particles are just gone, no resume logic.

## Architecture

Two additive pieces plus one new wire between them. Nothing existing is rewired.

### 1. Kitty watcher — `particles_watcher.py`

New file in `dots/.config/kitty/`, loaded via `watcher particles_watcher.py` in `kitty.conf`. Kitty calls its `on_key_event` hook on every keypress while the window is focused; the watcher filters down to printable characters and backspace, ignoring everything else.

For each triggering key: reads the window's cursor cell (row/col) and cell pixel dimensions straight from kitty's own window/font-metrics API, and adds the window's cached absolute screen origin (see below) to get an absolute screen pixel target, nudged by half a cell so the burst centers on the glyph.

Wayland clients can't see their own on-screen position, so the watcher separately subscribes to Hyprland's IPC event socket (`.socket2.sock`) for `activewindowv2`/`windowmoved`/`windowresized` events on kitty windows, caching each window's `at`/`size` and refreshing only when one of those fires — not on every keystroke.

Holds one persistent Unix socket connection to the renderer (below), open for the life of the kitty process. Writes one line per triggering key: `x,y,kind\n` where kind is `char` or `backspace`. If the write fails (renderer not running), the event is dropped silently — this must never be able to slow down or block actual typing.

### 2. Quickshell renderer — `Modules/Particles/`

New module in noctalia-shell. Follows the existing per-monitor overlay pattern already used by `Modules/Background/FadeOverlay.qml` and `Modules/Background/Overview.qml` — a `Variants { model: Quickshell.screens }` wrapping one `PanelWindow` per screen, each a fully transparent, click-through, keyboard-inert `WlrLayershell` surface anchored to all four edges (`WlrKeyboardFocus.None`, `ExclusionMode.Ignore`, same as `FadeOverlay`) so it never steals input.

Listens on `$XDG_RUNTIME_DIR/particles.sock` using `Quickshell.Io`'s `SocketServer`/`Socket` types. This is a new pattern for the codebase — the shell's existing IPC (`IpcHandler` + `qs ipc call`, used by AiChat/Cheatsheet/GameLauncher/CustomButtonIPCService) is request/response RPC meant for occasional toggle-style commands, and forks a new `qs` client process per call. Fine for "open the AI chat panel," too much overhead for a raw per-keystroke stream during fast typing — so this module opens a dedicated long-lived socket instead. An `IpcHandler { target: "particles" }` is still added alongside it for `enable`/`disable`/`reload`, consistent with how every other module exposes manual control.

Each screen's surface holds its own particle pool — plain QML objects with position, velocity, life, and opacity — driven by the same frame-loop mechanism the holo-shell shaders use (whatever `HoloPanel`'s scanline/flicker driver turns out to be day-of-build; not introducing a second animation system). A `char` event spawns 6-10 particles bursting outward at random angles/speeds from the target point, colored from `Color.mPrimary`/`Color.mSecondary`, shrinking and fading over roughly 300-500ms with no gravity — explode-and-fade. A `backspace` event spawns the same burst with a visually distinct treatment (color lean and/or fewer/smaller particles, tuned at build time). A surface only draws bursts whose coordinates land inside its own screen geometry, so multi-monitor setups route correctly. When no particles are alive on a given screen, that screen's frame loop stops entirely — zero cost at rest, matching the idle-sweep pattern elsewhere in the reskin.

## Data Flow

```
You type a printable char in a focused kitty window
  → on_key_event fires in particles_watcher.py
      → filtered: printable/backspace? yes → continue; else → ignore
      → cursor cell (row,col) + cell size read from kitty window state
      → + cached window origin (from Hyprland IPC, refreshed on move/resize/focus only)
      → = absolute screen pixel (x, y)
      → written as "x,y,kind\n" to the open socket connection

Quickshell particles module (per-screen SocketServer)
  → receives line, parses x,y,kind
  → finds the screen whose geometry contains (x,y)
  → that screen's surface spawns 6-10 particles at (x,y), scheme-colored
  → frame loop (if not already running) starts, animates burst outward + fade
  → last particle dies → frame loop stops → back to zero cost

Renderer not running (Quickshell restarting, crashed, etc.):
  → watcher's socket write fails → event dropped silently → typing unaffected

kitty window moved/resized:
  → Hyprland IPC event fires → watcher updates cached origin for that window only
```

## Error Handling

- **Renderer not running / socket write fails**: watcher drops the event, never blocks or throws — typing must always work regardless of Quickshell's state.
- **Multiple kitty windows open**: kitty loads the watcher per-OS-window, so each has its own instance tracking its own cached origin via Hyprland events scoped to its own window ID.
- **Window closed/kitty quit mid-burst**: irrelevant to the renderer — already-spawned particles are independent QML objects; they just finish their animation and die normally.
- **Hyprland IPC event socket unavailable** (e.g. a future non-Hyprland compositor): watcher fails to resolve window origin, logs once, drops events until it reconnects — no crash, particles just don't fire.
- **SocketServer bind fails** (stale socket file from a crashed previous run): remove the stale socket file at startup before binding, standard Unix socket server cleanup.

## Testing / Validation

No unit-test story here — this is a live visual/input feature. Validation is manual:

1. Open kitty, type normal text, confirm a burst fires from each character in the active scheme's colors and fades within half a second
2. Hold backspace, confirm the distinct backspace treatment fires per deletion
3. Type fast (paste a chunk of text or hold a key) and confirm no input lag/dropped keystrokes in the terminal itself
4. Move/resize the kitty window, then type again, confirm bursts still land on the correct cell (origin cache updated correctly)
5. Open a second kitty window on a second monitor, type in each, confirm bursts render on the correct monitor
6. Kill/restart the `quickshell-noctalia` service while kitty is focused, then type — confirm no error/hang, then confirm bursts resume once the service is back up
7. Switch to a non-Aether color scheme, confirm particles re-color to match instead of staying hardcoded cyan/violet

## Files Changed / Added

| File | Change |
|------|--------|
| `dots/.config/kitty/particles_watcher.py` | New — kitty watcher, hooks `on_key_event`, computes cursor pixel, streams to socket |
| `dots/.config/kitty/kitty.conf` | Modified — add `watcher particles_watcher.py` |
| `Modules/Particles/ParticlesOverlay.qml` | New — per-screen layer-shell surface, particle pool, frame loop |
| `Modules/Particles/ParticlesService.qml` (or similar) | New — `SocketServer` on `$XDG_RUNTIME_DIR/particles.sock`, parses events, routes to correct screen; also hosts the `IpcHandler { target: "particles" }` |
| Shell module registration (wherever other top-level modules like `Dock`/`Background` are loaded) | Modified — load the new Particles module |

## Deferred (explicitly out of scope for this pass)

- System-wide (non-kitty) support — no reliable caret-position signal exists outside kitty on Wayland; would need a separate AT-SPI-based or mouse-fallback design, ruled out earlier in brainstorming.
- Configurable particle count/color/physics via a settings UI — hardcoded constants for this pass.
- Supporting terminals other than kitty (foot, alacritty, wezterm, ghostty are also installed on this machine) — kitty only, since its watcher/remote-control API is what makes accurate cursor tracking possible at all.

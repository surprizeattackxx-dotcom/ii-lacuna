# Kitty Typing Particles

**Date:** 2026-07-26
**Status:** Pending review (revised — original sensor mechanism assumed a kitty hook that doesn't exist; see Architecture §1)

## Goal

When you type a printable character or hit backspace in kitty (your default terminal), a small burst of particles explodes outward from the exact cell you just typed in and fades out, rendered on top of everything as a full-screen transparent overlay. Particles are colored from the active color scheme's `mPrimary`/`mSecondary` tokens — Aether cyan/violet when Aether is selected (what you asked for), but it re-colors automatically if you ever switch schemes, same as every other themed element in the shell.

## Non-Goals

- Not system-wide — only fires while a kitty window is focused and receiving the keystroke. Other terminals/apps do nothing. (We scoped this down from "all of Hyprland" earlier in brainstorming — no reliable caret-position signal exists outside kitty.)
- Not tracking every keystroke — only printable characters + backspace trigger a burst; modifiers, arrows, enter, tab, etc. are ignored.
- Not persisting particle state across a Quickshell restart — if noctalia-shell restarts mid-burst, in-flight particles are just gone, no resume logic.

## Architecture

Two additive pieces plus one new wire between them. Nothing existing is rewired.

### 1. Kitty watcher — `particles_watcher.py`

**Revised after implementation research — kitty's watcher API has no `on_key_event` hook for normal passthrough typing.** That hook only exists in kitty's separate overlay-kitten framework (used for things like the hints kitten, which takes over the whole window), not for observing keys as they pass through to your shell. Confirmed against kitty 0.48.1 source (`kitty/window.py`, the `Watchers` class) and kitty's own docs — the real hook set is `on_load`, `on_resize`, `on_close`, `on_focus_change`, `on_set_user_var`, `on_title_change`, `on_cmd_startstop`, `on_color_scheme_preference_change`, `on_tab_bar_dirty`, `on_quit`. None fire per keystroke.

What actually works, and is fully within kitty's supported Python API: kitty exposes a real in-process timer (`add_timer(callback, interval_seconds, rearm)` / `remove_timer(id)`, from `kitty.fast_data_types`, the same primitive kitty's own cursor-blink and scroll-animation code uses) plus a `Window.as_text(add_cursor=True)` method — the identical call `kitty @ get-text` itself uses internally — which returns the visible screen's plain text with a trailing `\x1b[{row+1};{col+1}H` cursor-position escape appended.

New file in `dots/.config/kitty/`, loaded via `watcher particles_watcher.py` in `kitty.conf`. Uses the real `on_focus_change` and `on_close` hooks:

- **On focus gained**: starts a repeating `add_timer` callback (~50Hz, i.e. every 0.02s) scoped to that window.
- **Each tick**: calls `window.as_text(add_cursor=True)`, parses the trailing `\x1b[row;colH` sequence and the plain grid text, and diffs against the previous tick's snapshot:
  - cursor moved exactly one cell right on the same row, and the cell it moved off of now holds a new non-blank glyph it didn't have before → `char` event, targeting that cell (`row`, the column it moved off of).
  - cursor moved exactly one cell left on the same row, and the cell it landed on lost content it had before → `backspace` event, targeting that cell.
  - anything else (bigger jumps, line wraps, unrelated redraws, scrollback, tab-completion inserting multiple characters at once) → no event. This is a deliberate side effect, not just a limitation: it means pastes and completions don't spam a burst per inserted character, only genuine one-key-at-a-time typing does.
- **On focus lost / window close**: cancels that window's timer via `remove_timer`.

Emits one line per detected event over a persistent Unix socket connection to the renderer (below), held open for the life of the kitty process: `row,col,cols,lines,kind\n` — grid-relative, not pixels (pixel resolution happens on the Quickshell side, see below). `cols`/`lines` are `window.screen.columns`/`window.screen.lines`, included so the renderer can derive per-cell pixel size. If the socket write ever fails (renderer not running), the event is dropped silently — this must never be able to slow down or block actual typing, and the polling timer itself must never block kitty's main loop (each tick's parse/diff work is a handful of string operations on an already-small screen buffer, well under a millisecond).

### 2. Quickshell renderer — `Modules/Particles/`

New module in noctalia-shell. Follows the existing per-monitor overlay pattern already used by `Modules/Background/FadeOverlay.qml` and `Modules/Background/Overview.qml` — a `Variants { model: Quickshell.screens }` wrapping one `PanelWindow` per screen, each a fully transparent, click-through, keyboard-inert `WlrLayershell` surface anchored to all four edges (`WlrKeyboardFocus.None`, `ExclusionMode.Ignore`, same as `FadeOverlay`) so it never steals input.

Listens on `$XDG_RUNTIME_DIR/particles.sock` using `Quickshell.Io`'s `SocketServer`/`Socket` types (`SocketServer { path; handler: Component { Socket { parser: SplitParser { splitMarker: "\n"; onRead: (line) => {...} } } } }` — confirmed against the installed Quickshell's `quickshell-io.qmltypes`). This is a new pattern for the codebase — the shell's existing IPC (`IpcHandler` + `qs ipc call`, used by AiChat/Cheatsheet/GameLauncher/CustomButtonIPCService) is request/response RPC meant for occasional toggle-style commands, and forks a new `qs` client process per call. Fine for "open the AI chat panel," too much overhead for a raw per-keystroke stream during fast typing — so this module opens a dedicated long-lived socket instead. An `IpcHandler { target: "particles" }` is still added alongside it for `enable`/`disable`/`reload`, consistent with how every other module exposes manual control.

Each received `row,col,cols,lines,kind` line is turned into an absolute screen pixel here, not on the kitty side — Quickshell already has native Hyprland integration (`Quickshell.Hyprland`'s `HyprlandIpc.activeToplevel`) that this codebase can query directly for the focused window's live pixel geometry (`lastIpcObject.at` / `.size`, the same fields `hyprctl clients -j` reports). Since a burst can only ever originate from whichever kitty window currently has keyboard focus, `activeToplevel` at the moment the event arrives is always the right window — no PID or address matching needed. Per-cell pixel size is derived as `size.width / cols` and `size.height / lines`; the target point is `at + (col + 0.5) * cellWidth, at + (row + 0.5) * cellHeight`. This is an approximation (kitty's internal padding isn't subtracted), acceptable for a cosmetic burst that just needs to land on roughly the right glyph, not pixel-perfect.

Each screen's surface holds its own particle pool — plain QML objects with position, velocity, life, and opacity — driven by the same frame-loop mechanism the holo-shell shaders use (whatever `HoloPanel`'s scanline/flicker driver turns out to be day-of-build; not introducing a second animation system). A `char` event spawns 6-10 particles bursting outward at random angles/speeds from the target point, colored from `Color.mPrimary`/`Color.mSecondary`, shrinking and fading over roughly 300-500ms with no gravity — explode-and-fade. A `backspace` event spawns the same burst with a visually distinct treatment (color lean and/or fewer/smaller particles, tuned at build time). A surface only draws bursts whose coordinates land inside its own screen geometry, so multi-monitor setups route correctly. When no particles are alive on a given screen, that screen's frame loop stops entirely — zero cost at rest, matching the idle-sweep pattern elsewhere in the reskin.

## Data Flow

```
Kitty window gains focus
  → on_focus_change fires → particles_watcher.py starts a ~50Hz add_timer for this window

Each timer tick:
  → window.as_text(add_cursor=True) → plain grid text + trailing cursor escape
  → parse row,col from "\x1b[row;colH"; diff grid text against last tick
      → cursor moved right one cell + new glyph at old position → kind=char
      → cursor moved left one cell + glyph removed → kind=backspace
      → anything else → no event
  → on event: write "row,col,cols,lines,kind\n" to the open socket connection

Quickshell particles module (per-screen SocketServer)
  → receives line, parses row,col,cols,lines,kind
  → reads HyprlandIpc.activeToplevel.lastIpcObject for live at/size
  → derives absolute pixel: at + (col+0.5)*(size.width/cols), at + (row+0.5)*(size.height/lines)
  → finds the screen whose geometry contains that pixel
  → that screen's surface spawns 6-10 particles there, scheme-colored
  → frame loop (if not already running) starts, animates burst outward + fade
  → last particle dies → frame loop stops → back to zero cost

Kitty window loses focus / closes:
  → on_focus_change / on_close fires → particles_watcher.py cancels that window's timer via remove_timer

Renderer not running (Quickshell restarting, crashed, etc.):
  → watcher's socket write fails → event dropped silently → typing unaffected
```

## Error Handling

- **Renderer not running / socket write fails**: watcher drops the event, never blocks or throws — typing must always work regardless of Quickshell's state.
- **Multiple kitty windows open**: kitty loads the watcher per-OS-window, so each has its own instance and its own `add_timer`, independently started/stopped by that window's own focus events.
- **Window closed/kitty quit mid-burst**: irrelevant to the renderer — already-spawned particles are independent QML objects; they just finish their animation and die normally. On the watcher side, `on_close` cancels the timer so it doesn't keep firing against a dead window.
- **`HyprlandIpc.activeToplevel` unavailable or stale at the moment an event arrives** (e.g. focus changed between the keypress and the socket message being processed): drop that single event rather than spawning a burst at a wrong/stale position — a missed burst is harmless, a burst on the wrong window isn't a good look.
- **SocketServer bind fails** (stale socket file from a crashed previous run): remove the stale socket file at startup before binding, standard Unix socket server cleanup.
- **Timer tick work exceeds its budget** (shouldn't happen at these screen sizes, but): if diffing ever gets expensive on a very large scrollback/window, the watcher must never let a slow tick block kitty's main loop — keep the per-tick work to plain-text diffing only, no heavy parsing.

## Testing / Validation

No unit-test story here — this is a live visual/input feature. Validation is manual:

1. Open kitty, type normal text, confirm a burst fires from each character in the active scheme's colors and fades within half a second
2. Hold backspace, confirm the distinct backspace treatment fires per deletion
3. Type fast (paste a chunk of text or hold a key) and confirm no input lag/dropped keystrokes in the terminal itself
4. Move/resize the kitty window, then type again, confirm bursts still land on the correct cell (position is queried live each event, not cached, so this should just work)
5. Open a second kitty window on a second monitor, type in each, confirm bursts render on the correct monitor
6. Kill/restart the `quickshell-noctalia` service while kitty is focused, then type — confirm no error/hang, then confirm bursts resume once the service is back up
7. Switch to a non-Aether color scheme, confirm particles re-color to match instead of staying hardcoded cyan/violet

## Files Changed / Added

| File | Change |
|------|--------|
| `dots/.config/kitty/particles_watcher.py` | New — kitty watcher, hooks `on_focus_change`/`on_close`, polls via `add_timer` + `window.as_text(add_cursor=True)`, streams grid-relative events to socket |
| `dots/.config/kitty/kitty.conf` | Modified — add `watcher particles_watcher.py` |
| `Modules/Particles/ParticlesOverlay.qml` | New — per-screen layer-shell surface, particle pool, frame loop |
| `Modules/Particles/ParticlesService.qml` (or similar) | New — `SocketServer` on `$XDG_RUNTIME_DIR/particles.sock`, parses events, routes to correct screen; also hosts the `IpcHandler { target: "particles" }` |
| Shell module registration (wherever other top-level modules like `Dock`/`Background` are loaded) | Modified — load the new Particles module |

## Deferred (explicitly out of scope for this pass)

- System-wide (non-kitty) support — no reliable caret-position signal exists outside kitty on Wayland; would need a separate AT-SPI-based or mouse-fallback design, ruled out earlier in brainstorming.
- Configurable particle count/color/physics via a settings UI — hardcoded constants for this pass.
- Supporting terminals other than kitty (foot, alacritty, wezterm, ghostty are also installed on this machine) — kitty only, since its watcher/remote-control API is what makes accurate cursor tracking possible at all.

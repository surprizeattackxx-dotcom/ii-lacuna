-- Window rules wiki https://wiki.hypr.land/Configuring/Basics/Window-Rules/

-- Picture-in-Picture
hl.window_rule({
    match             = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" },
    float             = true,
    keep_aspect_ratio = true,
    size              = { "max(monitor_w, monitor_h)*0.25", "min(monitor_w, monitor_h)*0.25" },
    pin               = true,
})

-- Gaming
local gamingApps = "^(steam_app.*)$"
local gamingWorkspace = "name:gaming"

-- RS3 (steam_app_1343400) is deliberately EXEMPT from both gaming-workspace
-- rules — as of 2026-08-12 it gets RuneLite's treatment instead and is pinned
-- to workspace 1 alongside it (see ws_assignments near the bottom). It matches
-- BOTH of these (class ^steam_app AND content=game), so each rule excludes it
-- on a different field: this one by class, the next by its main window's
-- initial_title. Patterns live in config/variables.lua.
-- PartyDeck's gamescope classes joined the exemption 2026-08-16 (see the
-- PartyDeck section below): rule 1's exclusion widened from RS3 alone to
-- NOT_GAMING_WORKSPACE_CLASS_PATTERN (RS3 + PartyDeck merged in
-- variables.lua); rule 2 already excludes it by class since gamingApps no
-- longer matches "gamescope" at all (was "^(steam_app.*|gamescope)$", now
-- just steam_app — PartyDeck gets its own rules instead, right below).
hl.window_rule({ match = { content = "game", class = "negative:" .. NOT_GAMING_WORKSPACE_CLASS_PATTERN }, workspace = gamingWorkspace })
hl.window_rule({ match = { class = gamingApps, initial_title = "negative:" .. RS3_MAIN_TITLE_PATTERN }, workspace = gamingWorkspace })
hl.window_rule({ match = { class = "^(steam)$", title = "^(Friends List)$" }, float = true })
hl.window_rule({
    match = {
        class = "^(steam)$",
        title = "^(Launching\\.{3})$"
    },
    float     = true,
    center    = false,
    workspace = gamingWorkspace,
})
-- RS3 excluded from the fullscreen block (2026-08-12) — it floats at 62%x70%
-- placed at the cursor via config/handlers.lua, same as RuneLite.
hl.window_rule({
    match = {
        class         = gamingApps,
        title         = "^(.+)$",
        initial_title = "negative:^(.*\\\\home\\\\.*|RuneScape)$",
    },
    size             = { "monitor_w", "monitor_h" },
    fullscreen_state = 2,
    content          = "game",
})
-- ...but it still needs the content tag the block above would have set: the
-- F-key gate (fkey_gate_match), gaming-mode animations-off (handlers.lua), and
-- RS3's own confine-pointer exemption at the bottom of this file all key off
-- content = "game". Tagging it here keeps all three working while it's windowed.
hl.window_rule({ match = { class = RS3_CLASS_PATTERN }, content = "game" })
hl.window_rule({
    match = {
        class         = "^(steam_app.*)$",
        initial_title = "^$",
    },
    float            = true,
    center           = true,
    fullscreen       = false,
    fullscreen_state = 0,
})

-- Apps
hl.window_rule({ match = { class = "^(.*\\.exe)$", float = true }, monitor = PRIMARY_MONITOR, fullscreen_state = 0 })
hl.window_rule({ match = { class = "^(vesktop|discord)$" }, monitor = PRIMARY_MONITOR })
hl.window_rule({ match = { class = "^(.*[Cc]alculator.*)$" }, float = true, size = { "max(monitor_w, monitor_h)*0.17", "min(monitor_w, monitor_h)*0.43" } })
hl.window_rule({ match = { class = "^(org\\.kde\\.keditfiletype)$" }, float = true })
hl.window_rule({ match = { class = "^(org\\.kde\\.ark)$" }, size = { "max(monitor_w, monitor_h)*0.40", "min(monitor_w, monitor_h)*0.40" } })
hl.window_rule({ match = { class = "^(.*satty.*)$" }, min_size = { "max(monitor_w, monitor_h)*0.35", "min(monitor_w, monitor_h)*0.35" }, float = true })
hl.window_rule({ match = { class = "^(dev\\.)?(noctalia\\.Noctalia(\\.Settings)?)$" }, float = true, size = { "monitor_w*0.70", "monitor_h*0.70" } })
-- Dolphin floats disabled — main window tiles now. Uncomment to restore the
-- centered, cursor-positioned floating window (dialogs stayed tiled via the
-- negative: title filter).
-- WARNING (2026-07-15): this exact move-clamp pattern, tried live on RuneLite,
-- did NOT clamp — window ended up at a large negative X, fully off-monitor.
-- window_w/window_h likely don't resolve the way this snippet assumes. Test
-- interactively before uncommenting or reusing this pattern elsewhere.
-- hl.window_rule({
--     match = {
--         class = "^(org\\.kde\\.dolphin)$",
--         title = "negative:^(Moving.*|Create New.*|Extract.*|Compress.*|Copying.*|Progress.*|Configure.*|Properties.*|Choose\\sApplication.*)$",
--     },
--     float = true,
--     size = { "monitor_w*0.50", "monitor_h*0.55" },
--     move = {
--         "max(20, min(cursor_x - (window_w*0.50), monitor_w - window_w + 20))", -- X axis clamping
--         "max(20, min(cursor_y - 50, monitor_h - window_h + 20))" -- Y axis clamping
--     },
-- })

-- Opacity Overrides
local terminals = "^(kitty|ghostty|[Kk]onsole|Alacritty|gnome-terminal|xfce[0-9]?-terminal)$"

hl.window_rule({ match = { class = "^(firefox|zen)$" }, opacity = "1.0 override" })
hl.window_rule({ match = { class = terminals }, opacity = "1.0 override" }) -- Override opacity in favor of terminal settings for opacity. If your terminal doesn't support transparency, you can remove this rule.
hl.window_rule({ match = { class = "^(mpv|org.kde.haruna|.*plex.*|org\\.kde\\.gwenview|.*vlc.*)$" }, opacity = "1.0 override" })
hl.window_rule({ match = { class = GAME_CLIENT_CLASS_PATTERN }, opacity = "1.0 override" })
hl.window_rule({ match = { class = "^(google-chrome)$" }, opacity = "1.0 override" })

-- Float Utility Windows
local floatApps = {
    { class = "^(kvantummanager|qt[56]ct|nwg-look)$" },
    { class = "^(org.pulseaudio.pavucontrol|blueman-manager|nm-applet|nm-connection-editor|pavucontrol-qt)$" },
    { title = "^(Winetricks.*|Protontricks.*)$" },
}
for _, m in ipairs(floatApps) do hl.window_rule({ match = m, float = true }) end

-- Float Common Modals
local modalMatches = {
    { title = "^(Open|Authentication Required|Add Folder to Workspace|Choose Files|Save As|Confirm to replace files|File Operation Progress)$" },
    { initial_title = "^(Open File)$" },
    { class = "^([Xx]dg-desktop-portal-gtk)$" },
    { title = "^(File Upload|Choose wallpaper|Library)(.*)$" },
    { class = "^(.*dialog.*)$" },
    { title = "^(.*dialog.*)$" },
    { class = "^(hyprland-share-picker)$"},
}
for _, m in ipairs(modalMatches) do hl.window_rule({ match = m, float = true }) end

-- Ignore maximize requests from all apps. You'll probably like this.
hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

-- Fix some dragging issues with XWayland
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

hl.layer_rule({
  name = "noctalia",
  match = {
    namespace = "^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd|window-switcher)$",
  },
  no_anim = true,
  ignore_alpha = 0.5,
  blur = true,
  blur_popups = true,
})

-- ============================================================
--  Migrated custom rules (from old hyprland/windowrules.lua)
--  suppress-maximize-events and fix-xwayland-drags are omitted here —
--  the stock rules above already cover them.
-- ============================================================

-- ··· Floating dialogs ···
local floating_dialogs = {
    { class = "^(org\\.pulseaudio\\.pavucontrol)$", size = "monitor_w*.45 monitor_h*.45" },
    { class = "^(org\\.kde\\.easyeffects)$", size = "monitor_w*.55 monitor_h*.65" },
    { class = "^(nm-connection-editor)$", size = "monitor_w*.45 monitor_h*.45" },
    { class = ".*bluedevilwizard" },
    { class = "org.freedesktop.impl.portal.desktop.kde", size = "monitor_w*.60 monitor_h*.65" }
}

-- ··· Centered floating apps ···
hl.window_rule({ center = true, float = true, no_blur = true, name = "float-utils",
    match = { class = "^(blueman-manager|polkit-gnome-authentication-agent-1|org.gnome.polkit|lxpolkit)$" } })
hl.window_rule({ center = true, float = true, name = "float-media", match = { class = "^(mpv|imv|vlc|org\\.fooyin\\.fooyin)$" } })
hl.window_rule({ center = true, float = true, name = "float-theme-tools", match = { class = "^(nwg-look|qt5ct|qt6ct|kvantummanager)$" } })
hl.window_rule({ center = true, float = true, name = "float-qalculate", match = { class = "^(qalculate-gtk)$" } })
-- RuneLite deliberately excluded from static float rules: it restores its own
-- saved clientBounds, which land in the empty top-left quadrant of the
-- monitor layout (no output covers x 0..3840, y 0..2160) — a plain `float =
-- true` here would just map it invisible. RESOLVED 2026-07-22: config/
-- handlers.lua now floats + places the RuneLite main window itself (cursor-
-- centered, clamped on-screen) via the window.open event, not a static rule —
-- see [[Hyprland Lua Config]] in the vault.
-- RS3 rides the same handler as of 2026-08-12 (Donnie: same rules as RuneLite).
-- It has no off-screen-restore problem of its own — it maps correctly at its
-- monitor origin — so for RS3 the handler is purely the windowed 62%x70%
-- cursor placement, not a rescue.
hl.window_rule({ float = true, name = "float-mc", match = { class = "^(Minecraft.*|bolt-launcher|com\\.adamcake\\.Bolt)$" } })
hl.window_rule({ float = true, name = "float-jagex-launcher", match = { class = "(?i)^(.*jagexlauncher.*)$" } })
hl.window_rule({ float = true, name = "float-jagex-launcher-title", match = { title = "^(Jagex Launcher)(.*)$" } })
hl.window_rule({ float = true, name = "float-runelite-launcher", match = { class = "^(net-runelite-launcher-Launcher)$" } })

-- ··· Picture-in-picture (custom position; runs after the stock PiP rule so it wins) ···
hl.window_rule({ float = true, pin = true, name = "discord-pip", match = { title = "Picture in picture" } })
hl.window_rule({
    float = true, pin = true, keep_aspect_ratio = true, name = "pip-positioned",
    match = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" },
    move = "monitor_w*.73 monitor_h*.72", size = "monitor_w*.25 monitor_h*.25",
})

-- ··· Tearing (immediate) ···
local tearing = {
    { match = { title = ".*\\.exe" }, name = "tearing-exe" },
    { match = { title = ".*minecraft.*" }, name = "tearing-mc" },
    { match = { class = "^steam_app" }, name = "tearing-steam" },
}
for _, r in ipairs(tearing) do
    hl.window_rule({ immediate = true, match = r.match, name = r.name })
end

-- ··· Confine pointer ···
-- RuneScape is deliberately EXEMPT, BOTH launchers — it's a point-and-click
-- MMO, and since 2026-08-12 it runs as a 62%x70% floating window (RuneLite
-- parity) rather than fullscreen, so a locked cursor would also trap the
-- pointer inside that window. Rule 2 now excludes RS3_CLASS_PATTERN rather
-- than the Steam class alone: adding Bolt's client (class "RuneScape") to
-- RS3_CLASSES gives it content = "game", which would otherwise have made this
-- rule newly confine it. Steam RS3 matched both of the first two rules (class
-- ^steam_app AND content=game, confirmed live via hyprctl), so each excludes
-- it on a different field: rule 1 skips anything already tagged as game
-- content, rule 2 skips RS3 by class. Bolt's client only ever matches rule 2,
-- since its class isn't a steam_app. Every other game still gets confined by
-- one rule or the other. Drop the negative: on rule 2 to re-lock RS3.
local confine = {
    { match = { class = "^steam_app", content = "negative:game" }, name = "confine-steam" },
    { match = { content = "game", class = "negative:" .. RS3_CLASS_PATTERN }, name = "confine-game" },
    { match = { title = ".*minecraft.*" }, name = "confine-mc" },
}
for _, r in ipairs(confine) do
    hl.window_rule({ confine_pointer = true, match = r.match, name = r.name })
end

-- ··· Workspace assignments ···
local ws_assignments = {
    { match = { class = GAME_CLIENT_CLASS_PATTERN }, workspace = "1 silent",  name = "ws-game-clients" },
    { match = { title = "^(facebook)$" },                     workspace = "11 silent", name = "ws-facebook" },
    { match = { class = "^(discord)$" },                      workspace = "11 silent", name = "ws-discord" },
    { match = { class = "^(org\\.mozilla\\.Thunderbird)$" },  workspace = "5 silent",  name = "ws-thunderbird" },
    { match = { class = "^(Spotify)$" },                      workspace = "8 silent",  name = "ws-spotify" },
    { match = { class = "^(Gimp-2.10)$" },                    workspace = "9 silent",  name = "ws-gimp" },
    { match = { class = "^(Bitwarden)$" },                    workspace = "3 silent",  name = "ws-bitwarden" },
    { match = { class = "^(GalaxyBudsClient)$" },             workspace = "12 silent", name = "ws-galaxybuds" },
}
for _, r in ipairs(ws_assignments) do
    hl.window_rule({ match = r.match, workspace = r.workspace, name = r.name })
end

-- ··· Steam (client window placement; stock rules above handle steam_app games) ···
hl.window_rule({ float = true, name = "steam-negative-float", match = { class = "^steam$", title = "negative:^Steam$" } })
hl.window_rule({ float = false, workspace = "2", name = "ws-steam", match = { class = "^(steam)$", title = "^(Steam)$" } })

-- ··· App-specific tweaks ···
hl.window_rule({ float = true, no_initial_focus = true, move = "999999 999999", name = "plasma-changeicons", match = { class = "^(plasma-changeicons)$" } })
hl.window_rule({ move = "40 80", name = "dolphin-copy", match = { title = "^(Copying — Dolphin)$" } })
hl.window_rule({ tile = true, name = "warp-tile", match = { class = "^dev\\.warp\\.Warp$" } })
hl.window_rule({ tile = true, name = "tile-rockstar-launcher", match = { title = "^(Rockstar Games Launcher)(.*)$" } })
hl.window_rule({ float = true, move = "20 monitor_h-120", name = "move-hyprland-run", match = { class = "hyprland-run" } })
hl.window_rule({ size = { 800, 500 }, name = "float-blueman", match = { class = "^(blueman-manager)$" } })
hl.window_rule({ no_initial_focus = true, name = "jetbrains-fix", match = { class = "^jetbrains-.*$", float = true, title = "^$|^\\s$|^win\\d+$" } })

-- ------------------------------------------------------------
--  LAYER RULES  (stock config/windowrules.lua had none)
--
--  2026-07-15: a rewrite of this whole block against the noctalia-* scheme
--  caused two confirmed regressions (red-banding/blur artifact on the bar+
--  notifications, then missing bar widgets) and was fully reverted. See
--  Noctalia Plugin Gotchas.
--  2026-07-31: the dead quickshell:* relic rules (xray, ignore-alpha,
--  animation, and override blocks below) were removed — they match no live
--  namespace in the v5 shell (verified via hyprctl layers). Live rules are
--  the global xray=true, the noctalia main rule, and the noctalia_blur list.
-- ------------------------------------------------------------

-- ··· Global ···
hl.layer_rule({ xray = true, match = { namespace = ".*" } })

-- 2026-07-15: tried noctalia-bar-content blur + lower/separate bar opacity to
-- get a glassy framed-bar look. Blur itself worked with no artifacts, but it
-- exposed a real seam where the bar rectangle and frame border meet (they
-- blur genuinely different content at that corner) - tried fixing the color
-- mismatch via xray, made it worse, reverted. That seam only applies to a bar
-- WITH a visible border/frame; the live bar has border_width 0, so no seam.
-- RETRIED 2026-07-31: blur rules for the live noctalia namespaces went in
-- above (additive, not a rewrite). Second pass (iOS Liquid Glass): bar was
-- a floating pill (margin_ends 100, radii 19, background_opacity 0.8, luminous
-- border "#FFFFFF40" @ 1px); dock floated (margin_edge 14, radius 28, opacity
-- 0.65); blur size 11 / passes 5 + noise 0.05 + vibrancy 0.25 in decorations.lua.
-- 2026-07-31 (later): bar re-attached full-width — margin_edge 0, margin_ends 0,
-- radius_top_* 0 (square top corners), bottom corners 19, border+opacity kept.
-- Extended 2026-07-31: "noctalia-notification.*" joined the blur list; toast
-- background_opacity 0.85 in config.toml. Lock screen is NOT compositor-blurred
-- (Hyprland doesn't blur behind ext-session-lock) - its frost is noctalia-side
-- (blur_intensity 0.7 + login box opacity 0.6 in settings.toml).
-- Extended 2026-07-31: "noctalia-desktop-widget-.*" joined the blur list;
-- weather/media_player/sysmon desktop cards placed top-left of DP-1 in
-- config.toml (background_opacity 0.7, radius 24, color "surface").
-- Verified: no regressions (bar/dock/wallpaper layers all present).

-- ··· Blur ··· (live noctalia v5 namespaces, verified 2026-07-31 via hyprctl layers;
-- the old quickshell:* table below matched nothing)
local noctalia_blur = {
    "noctalia-bar.*",
    "noctalia-dock",
    "noctalia-panel",
    "noctalia-attached-panel",
    "noctalia-notification.*",
    "noctalia-desktop-widget-.*",
    "noctalia-osd",
}
for _, ns in ipairs(noctalia_blur) do
    hl.layer_rule({ blur = true, match = { namespace = ns } })
end

-- ··· QuickShell overrides (removed 2026-07-31 — all dead in v5) ···
-- ··· Ignore alpha (removed 2026-08-01 — same deal, bare/numbered namespaces
-- like bar[0-9]*, sideright[0-9]*, cheatsheet[0-9]* matched nothing; verified
-- against live `hyprctl layers` and the noctalia v5 source, which only ever
-- emits noctalia-* prefixed namespaces) ···

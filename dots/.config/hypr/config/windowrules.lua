-- Window rules wiki https://wiki.hypr.land/Configuring/Basics/Window-Rules/

-- Generic floating position
hl.window_rule({ match = { float = true }, center = true })

-- Picture-in-Picture
hl.window_rule({
    match             = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" },
    float             = true,
    keep_aspect_ratio = true,
    size              = { "max(monitor_w, monitor_h)*0.25", "min(monitor_w, monitor_h)*0.25" },
    pin               = true,
})

-- Gaming
local gamingApps = "^(steam_app.*|gamescope)$"
local gamingWorkspace = "name:gaming"

hl.window_rule({ match = { content = "game" }, workspace = gamingWorkspace })
hl.window_rule({ match = { class = gamingApps }, workspace = gamingWorkspace })
hl.window_rule({ match = { class = "^(steam)$", title = "^(Friends List)$" }, float = true })
hl.window_rule({
    match = {
        class = "^(steam)$",
        title = "^(Launching\\.{3})$"
    },
    float     = true,
    center    = true,
    workspace = gamingWorkspace,
})
hl.window_rule({
    match = {
        class         = gamingApps,
        title         = "^(.+)$",
        initial_title = "negative:^(.*\\\\home\\\\.*)$",
    },
    size             = { "monitor_w", "monitor_h" },
    fullscreen_state = 2,
    content          = "game",
})
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
hl.window_rule({ match = { class = "^(.*\\.exe)$", float = true }, monitor = PRIMARY_MONITOR, center = true, fullscreen_state = 0 })
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

-- Float Utility Windows
local floatApps = {
    { class = "^(kvantummanager|qt[56]ct|nwg-look)$" },
    { class = "^(org.pulseaudio.pavucontrol|blueman-manager|nm-applet|nm-connection-editor)$" },
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

-- ============================================================
--  Migrated custom rules (from old hyprland/windowrules.lua)
--  suppress-maximize-events and fix-xwayland-drags are omitted here —
--  the stock rules above already cover them.
-- ============================================================

-- ··· Floating dialogs ···
local floating_dialogs = {
    { title = "^(Open File)(.*)$" },
    { title = "^(Select a File)(.*)$" },
    { title = "^(Choose wallpaper)(.*)$", size = "monitor_w*.60 monitor_h*.65" },
    { title = "^(Open Folder)(.*)$" },
    { title = "^(Save As)(.*)$" },
    { title = "^(Library)(.*)$" },
    { title = "^(File Upload)(.*)$" },
    { title = "^(.*)(wants to save)$" },
    { title = "^(.*)(wants to open)$" },
    { title = ".*Welcome" },
    { title = "^(ii-lacuna Settings)$" },
    { title = ".*Shell conflicts.*" },
    { class = "^(blueberry\\.py)$" },
    { class = "^(guifetch)$" },
    { class = "^(pavucontrol)$", size = "monitor_w*.45 monitor_h*.45" },
    { class = "^(org\\.pulseaudio\\.pavucontrol)$", size = "monitor_w*.45 monitor_h*.45" },
    { class = "^(pavucontrol-qt)$", size = "monitor_w*.45 monitor_h*.45" },
    { class = "^(org\\.kde\\.easyeffects)$", size = "monitor_w*.55 monitor_h*.65" },
    { class = "^(nm-connection-editor)$", size = "monitor_w*.45 monitor_h*.45" },
    { class = ".*plasmawindowed.*" },
    { class = "kcm_.*" },
    { class = ".*bluedevilwizard" },
    { class = "org.freedesktop.impl.portal.desktop.kde", size = "monitor_w*.60 monitor_h*.65" },
    { class = "^(Zotero)$", size = "monitor_w*.45 monitor_h*.45" },
}
for _, r in ipairs(floating_dialogs) do
    local rule = { float = true, center = true, match = {}, name = "float-" .. (r.class or r.title) }
    if r.class then rule.match.class = r.class end
    if r.title then rule.match.title = r.title end
    if r.size then rule.size = r.size end
    hl.window_rule(rule)
end

-- ··· Centered floating apps ···
hl.window_rule({ center = true, float = true, no_blur = true, name = "float-utils",
    match = { class = "^(blueman-manager|polkit-gnome-authentication-agent-1|org.gnome.polkit|lxpolkit)$" } })
hl.window_rule({ center = true, float = true, name = "float-media", match = { class = "^(mpv|imv|vlc|org\\.fooyin\\.fooyin)$" } })
hl.window_rule({ center = true, float = true, name = "float-theme-tools", match = { class = "^(nwg-look|qt5ct|qt6ct|kvantummanager)$" } })
hl.window_rule({ center = true, float = true, name = "float-qalculate", match = { class = "^(qalculate-gtk)$" } })
-- RuneLite deliberately excluded: it restores its own saved clientBounds, which
-- land in the empty top-left quadrant of the monitor layout (no output covers
-- x 0..3840, y 0..2160). Floating means Hyprland honours that, so it maps
-- invisible. Tiled, the layout owns its position.
hl.window_rule({ float = true, name = "float-mc", match = { class = "^(Minecraft.*|bolt-launcher|com\\.adamcake\\.Bolt)$" } })
hl.window_rule({ float = true, center = true, name = "float-jagex-launcher", match = { class = "(?i)^(.*jagexlauncher.*)$" } })
hl.window_rule({ float = true, center = true, name = "float-jagex-launcher-title", match = { title = "^(Jagex Launcher)(.*)$" } })

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
local confine = {
    { match = { class = "^steam_app" }, name = "confine-steam" },
    { match = { content = "game" }, name = "confine-game" },
    { match = { title = ".*minecraft.*" }, name = "confine-mc" },
}
for _, r in ipairs(confine) do
    hl.window_rule({ confine_pointer = true, match = r.match, name = r.name })
end

-- ··· Workspace assignments ···
local ws_assignments = {
    { match = { class = "^(net-runelite-client-RuneLite)$" }, workspace = "1 silent",  name = "ws-runelite" },
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
hl.window_rule({ float = false, workspace = "2 silent", name = "ws-steam", match = { class = "^(steam)$", title = "^(Steam)$" } })

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
--  2026-07-15: attempted a rewrite of this whole block against the real
--  noctalia-* namespace scheme (the quickshell:* patterns below are dead -
--  none of them match anything live). The rewrite caused two confirmed live
--  regressions (a red-banding/blur artifact on the bar+notifications, then
--  missing bar widgets after the blur rules were pulled) and was fully
--  reverted back to this exact original content rather than keep
--  iterating blind. See Noctalia Plugin Gotchas for what was tried and
--  why it's parked, not retried, until it can be tested more carefully.
-- ------------------------------------------------------------

-- ··· Global ···
hl.layer_rule({ xray = true, match = { namespace = ".*" } })
-- xray blur samples the background *level*, but the visible wallpaper is
-- quickshell's Background on the bottom level — glass needs real sampling
hl.layer_rule({ xray = false, match = { namespace = "quickshell:.*" } })

-- 2026-07-15: tried noctalia-bar-content blur + lower/separate bar opacity to
-- get a glassy framed-bar look. Blur itself worked with no artifacts, but it
-- exposed a real seam where the bar rectangle and frame border meet (they
-- blur genuinely different content at that corner) - tried fixing the color
-- mismatch via xray, made it worse, reverted. Whole thing parked - see
-- Noctalia Plugin Gotchas for what was tried and the corner-geometry idea
-- for next time (square off the bar's corners so they sit flush against the
-- frame with no gap for a seam to show in, instead of chasing a color match).

-- ··· Blur ··· (old quickshell:* table, dead - see note above)
local layer_blur = {
    "gtk-layer-shell", "launcher", "notifications",
    "session[0-9]*", "bar[0-9]*", "barcorner.*", "dock[0-9]*",
    "indicator.*", "overview[0-9]*", "cheatsheet[0-9]*",
    "sideright[0-9]*", "sideleft[0-9]*", "osk[0-9]*",
    "quickshell:.*", "quickshell:session",
}
for _, ns in ipairs(layer_blur) do
    hl.layer_rule({ blur = true, match = { namespace = ns } })
end
hl.layer_rule({ blur = false, match = { namespace = "quickshell:appLauncher" } })

-- ··· Ignore alpha ···
local layer_ignore_alpha = {
    { ns = "launcher", a = 0.5 },
    { ns = "notifications", a = 0.69 },
    { ns = "bar[0-9]*", a = 0.6 },
    { ns = "barcorner.*", a = 0.6 },
    { ns = "dock[0-9]*", a = 0.6 },
    { ns = "indicator.*", a = 0.6 },
    { ns = "overview[0-9]*", a = 0.6 },
    { ns = "cheatsheet[0-9]*", a = 0.6 },
    { ns = "sideright[0-9]*", a = 0.6 },
    { ns = "sideleft[0-9]*", a = 0.6 },
    { ns = "osk[0-9]*", a = 0.6 },
    { ns = "quickshell:.*", a = 0.1 },
}
for _, r in ipairs(layer_ignore_alpha) do
    hl.layer_rule({ ignore_alpha = r.a, match = { namespace = r.ns } })
end

-- ··· No animation ···
local layer_no_anim = {
    "walker", "selection", "overview", "anyrun", "indicator.*",
    "osk", "hyprpicker", "noanim", "gtk4-layer-shell",
    "quickshell:actionCenter", "quickshell:lockWindowPusher",
    "quickshell:overlay", "quickshell:overview", "quickshell:polkit",
    "quickshell:regionSelector", "quickshell:screenshot", "quickshell:session",
    "quickshell:wNotificationCenter", "quickshell:wOnScreenDisplay",
    "quickshell:wStartMenu", "quickshell:wTaskView",
}
for _, ns in ipairs(layer_no_anim) do
    hl.layer_rule({ no_anim = true, match = { namespace = ns } })
end

-- ··· Animations ···
local layer_anim = {
    { ns = "quickshell:bar", anim = "slide" },
    { ns = "quickshell:cheatsheet", anim = "slide bottom" },
    { ns = "quickshell:dock", anim = "slide" },
    { ns = "quickshell:screenCorners", anim = "popin 120%" },
    { ns = "quickshell:notificationPopup", anim = "fade" },
    { ns = "quickshell:reloadPopup", anim = "slide" },
    { ns = "quickshell:sidebarRight", anim = "slide right" },
    { ns = "quickshell:sidebarLeft", anim = "slide left" },
    { ns = "quickshell:verticalBar", anim = "slide" },
    { ns = "quickshell:wallpaperSelector", anim = "slide top" },
}
for _, r in ipairs(layer_anim) do
    hl.layer_rule({ animation = r.anim, match = { namespace = r.ns } })
end

-- ··· QuickShell overrides ···
hl.layer_rule({ ignore_alpha = 1, match = { namespace = "quickshell:overlay" } })
hl.layer_rule({ ignore_alpha = 1, xray = false, match = { namespace = "quickshell:popup" } })
hl.layer_rule({ ignore_alpha = 1, match = { namespace = "quickshell:mediaControls" } })
hl.layer_rule({ ignore_alpha = 0, match = { namespace = "quickshell:wTaskView" } })
hl.layer_rule({ order = -1, match = { namespace = "quickshell:osk" } })
hl.layer_rule({ animation = "slide bottom", blur = true, ignore_alpha = 0.6, match = { namespace = "quickshell:wallpaperChanger" } })

-- ============================================================
--  Window & Layer Rules
-- ============================================================

-- ------------------------------------------------------------
--  WINDOW RULES
-- ------------------------------------------------------------

-- ··· Global behaviour ···
hl.window_rule({ match = { class = ".*" }, name = "suppress-maximize-events", suppress_event = "maximize" })
hl.window_rule({ match = { class = "^$", title = "^$", xwayland = true }, name = "fix-xwayland-drags", no_focus = true })

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
hl.window_rule({ float = true, name = "float-mc", match = { class = "^(Minecraft.*|com\\.adamcake\\.Bolt|net\\.runelite\\.client\\.RuneLite)$" } })
hl.window_rule({ center = true, float = true, no_blur = true, opacity = 1.0, size = { 680, 760 }, name = "float-kdeconnect", match = { class = "^(kde-connect-tui)$" } })
hl.window_rule({ center = true, float = true, no_blur = true, opacity = 1.0, size = { 900, 620 }, name = "float-claude-usage", match = { class = "^(claude-usage-tui)$" } })
hl.window_rule({ center = true, name = "default-float-center", match = { float = true } })

-- ··· Picture-in-picture ···
hl.window_rule({ float = true, pin = true, name = "discord-pip", match = { title = "Picture in picture" } })
hl.window_rule({
  float = true, pin = true, keep_aspect_ratio = true, name = "pip",
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
local workspaces = {
  { match = { title = "^(facebook)$" }, workspace = "11:silent", name = "ws-facebook" },
  { match = { class = "^(discord)$" }, workspace = "11 silent", name = "ws-discord" },
  { match = { class = "^(org\\.mozilla\\.Thunderbird)$" }, workspace = "5 silent", name = "ws-thunderbird" },
  { match = { class = "^(Spotify)$" }, workspace = "8 silent", name = "ws-spotify" },
  { match = { class = "^(Gimp-2.10)$" }, workspace = "9 silent", name = "ws-gimp" },
}
for _, r in ipairs(workspaces) do
  hl.window_rule({ match = r.match, workspace = r.workspace, name = r.name })
end

-- ··· Steam ···
hl.window_rule({ float = true, name = "steam-negative-float", match = { class = "^steam$", title = "negative:^Steam$" } })
hl.window_rule({ float = false, workspace = "2 silent", name = "ws-steam", match = { class = "^(steam)$", title = "^(Steam)$" } })

-- ··· App-specific tweaks ···
hl.window_rule({ float = true, no_initial_focus = true, move = "999999 999999", name = "plasma-changeicons", match = { class = "^(plasma-changeicons)$" } })
hl.window_rule({ move = "40 80", name = "dolphin-copy", match = { title = "^(Copying — Dolphin)$" } })
hl.window_rule({ tile = true, name = "warp-tile", match = { class = "^dev\\.warp\\.Warp$" } })
hl.window_rule({ float = true, move = "20 monitor_h-120", name = "move-hyprland-run", match = { class = "hyprland-run" } })
hl.window_rule({ size = { 800, 500 }, name = "float-blueman", match = { class = "^(blueman-manager)$" } })
hl.window_rule({ no_initial_focus = true, name = "jetbrains-fix", match = { class = "^jetbrains-.*$", float = true, title = "^$|^\\s$|^win\\d+$" } })

-- ------------------------------------------------------------
--  LAYER RULES
-- ------------------------------------------------------------

-- ··· Global ···
hl.layer_rule({ xray = true, match = { namespace = ".*" } })
-- xray blur samples the background *level*, but the visible wallpaper is
-- quickshell's Background on the bottom level — glass needs real sampling
hl.layer_rule({ xray = false, match = { namespace = "quickshell:.*" } })

-- ··· Blur ···
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

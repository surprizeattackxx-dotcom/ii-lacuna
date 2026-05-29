-- Window Rules & Layer Rules

-----------------------
---- WINDOW RULES ----
-----------------------

hl.window_rule({ name = "suppress-maximize-events", match = { class = ".*" }, suppress_event = "maximize" })

hl.window_rule({
    name = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

--hl.window_rule({ name = "steam-fixes",           match = { class = "steam_app_.*" },       float= true, immediate   = true         })
hl.window_rule({ name = "firefox-idle-inhibit",  match = { class = "firefox" },            idle_inhibit = "focus"    })
hl.window_rule({ name = "discord-pip",           match = { title = "Picture in picture" }, float = true, pin = true  })
hl.window_rule({ name = "move-hyprland-run",     match = { class = "hyprland-run" },       float = true, move = "20 monitor_h-120" })

hl.window_rule({ name = "disable-blur-xwayland-menus", match = { class = "^()$", title = "^()$" }, no_blur = true })
hl.window_rule({ name = "disable-blur-all",            match = { class = ".*" },                   no_blur = true })

-- Floating dialogs
local floating_rules = {
    { title = "^(Open File)(.*)$" },
    { title = "^(Select a File)(.*)$" },
    { title = "^(Choose wallpaper)(.*)$",  size = "monitor_w*.60 monitor_h*.65" },
    { title = "^(Open Folder)(.*)$" },
    { title = "^(Save As)(.*)$" },
    { title = "^(Library)(.*)$" },
    { title = "^(File Upload)(.*)$" },
    { title = "^(.*)(wants to save)$" },
    { title = "^(.*)(wants to open)$" },
    { class = "^(blueberry\\.py)$" },
    { class = "^(guifetch)$" },
    { class = "^(pavucontrol)$",                      size = "monitor_w*.45 monitor_h*.45" },
    { class = "^(org\\.pulseaudio\\.pavucontrol)$",   size = "monitor_w*.45 monitor_h*.45" },
    { class = "^(nm-connection-editor)$",             size = "monitor_w*.45 monitor_h*.45" },
    { class = ".*plasmawindowed.*" },
    { class = "kcm_.*" },
    { class = ".*bluedevilwizard" },
    { title = ".*Welcome" },
    { title = "^(ii-lacuna Settings)$" },
    { title = ".*Shell conflicts.*" },
    { class = "org.freedesktop.impl.portal.desktop.kde", size = "monitor_w*.60 monitor_h*.65" },
    { class = "^(Zotero)$",                           size = "monitor_w*.45 monitor_h*.45" },
}

for _, r in ipairs(floating_rules) do
    hl.window_rule({
        name  = "float-" .. (r.class or r.title or "unknown"),
        match = { class = r.class, title = r.title },
        float = true,
        center = true,
        size  = r.size,
    })
end

hl.window_rule({ name = "plasma-changeicons", match = { class = "^(plasma-changeicons)$" }, float = true, no_initial_focus = true, move = "999999 999999" })
hl.window_rule({ name = "dolphin-copy",       match = { title = "^(Copying — Dolphin)$" }, move = "40 80" })
hl.window_rule({ name = "warp-tile",          match = { class = "^dev\\.warp\\.Warp$" },   tile = true })

hl.window_rule({
    name  = "pip",
    match = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" },
    float = true,
    keep_aspect_ratio = true,
    move  = "monitor_w*.73 monitor_h*.72",
    size  = "monitor_w*.25 monitor_h*.25",
    pin   = true,
})

hl.window_rule({ name = "tearing-exe",    match = { title = ".*\\.exe" },             immediate = true })
hl.window_rule({ name = "tearing-mc",     match = { title = ".*minecraft.*" },        immediate = true })
hl.window_rule({ name = "tearing-steam",  match = { class = "^steam_app" },       immediate = true })
hl.window_rule({ name = "jetbrains-fix",  match = { class = "^jetbrains-.*$", float = true, title = "^$|^\\s$|^win\\d+$" }, no_initial_focus = true })
hl.window_rule({ name = "no-shadow-tiled", match = { float = false },                 no_shadow = true })

-- Custom rules
hl.window_rule({ name = "ws-facebook", match = { title = "^(facebook)$" }, workspace = "11:silent" })
hl.window_rule({ name = "kitty-opacity",  match = { class = "^(kitty)$" },            opacity = 0.95, no_blur = true, xray = true })
hl.window_rule({ name = "float-utils",    match = { class = "^(blueman-manager|polkit-gnome-authentication-agent-1|org.gnome.polkit|lxpolkit)$" }, float = true, center = true, no_blur = true })
hl.window_rule({ name = "float-blueman", match = { class = "^(blueman-manager)$" },   size = { 800, 500 } })
hl.window_rule({ name = "steam-sub-float", match = { class = "^(steam)$" }, float = true, center = true })
hl.window_rule({ name = "ws-steam",       match = { class = "^(steam)$", title = "^(Steam)$" }, workspace = 2, float = false })
hl.window_rule({ name = "steam-settings-float", match = { class = "^(steam)$", title = ".*(Properties|Settings|Game Settings).*" }, float = true, center = true })
hl.window_rule({ name = "disable-glass-steam-games", match = { class = "^steam_app_.*" }, tag = "+hyprglass_disabled" })
hl.window_rule({ name = "disable-glass-xwayland-fs", match = { xwayland = true, fullscreen = true }, tag = "+hyprglass_disabled" })
hl.window_rule({ name = "float-theme-tools", match = { class = "^(nwg-look|qt5ct|qt6ct|kvantummanager)$" }, float = true, center = true })
hl.window_rule({ name = "float-qalculate", match = { class = "^(qalculate-gtk)$" },   float = true, center = true })
hl.window_rule({ name = "default-float-center", match = { float = true },             center = true })
hl.window_rule({ name = "float-mc",     match = { class = "^(Minecraft.*|com\\.adamcake\\.Bolt|net\\.runelite\\.client\\.RuneLite)$" },        float = true })
hl.window_rule({ name = "float-crimson-desert", match = { title = ".*Crimson Desert.*" }, float = true, center = true })

-----------------------
---- LAYER RULES ----
-----------------------

hl.layer_rule({ match = { namespace = ".*" },        xray = true })
hl.layer_rule({ match = { namespace = "walker" },    no_anim = true })
hl.layer_rule({ match = { namespace = "selection" }, no_anim = true })
hl.layer_rule({ match = { namespace = "overview" },  no_anim = true })
hl.layer_rule({ match = { namespace = "anyrun" },    no_anim = true })
hl.layer_rule({ match = { namespace = "indicator.*" }, no_anim = true })
hl.layer_rule({ match = { namespace = "osk" },       no_anim = true })
hl.layer_rule({ match = { namespace = "hyprpicker" }, no_anim = true })
hl.layer_rule({ match = { namespace = "noanim" },    no_anim = true })
hl.layer_rule({ match = { namespace = "gtk4-layer-shell" }, no_anim = true })

local layer_blur = {
    "gtk-layer-shell", "launcher", "notifications",
    "session[0-9]*", "bar[0-9]*", "barcorner.*", "dock[0-9]*",
    "indicator.*", "overview[0-9]*", "cheatsheet[0-9]*",
    "sideright[0-9]*", "sideleft[0-9]*", "osk[0-9]*",
    "quickshell:.*", "quickshell:session",
}
for _, ns in ipairs(layer_blur) do
    hl.layer_rule({ match = { namespace = ns }, blur = true })
end

hl.layer_rule({ match = { namespace = "launcher" },      ignore_alpha = 0.5  })
hl.layer_rule({ match = { namespace = "notifications" }, ignore_alpha = 0.69 })

local layer_ignore = {
    "bar[0-9]*", "barcorner.*", "dock[0-9]*", "indicator.*",
    "overview[0-9]*", "cheatsheet[0-9]*", "sideright[0-9]*",
    "sideleft[0-9]*", "osk[0-9]*",
}
for _, ns in ipairs(layer_ignore) do
    hl.layer_rule({ match = { namespace = ns }, ignore_alpha = 0.6 })
end

hl.layer_rule({ match = { namespace = "quickshell:.*" },                 ignore_alpha = 0.79                    })
hl.layer_rule({ match = { namespace = "quickshell:bar" },                animation = "slide"                    })
hl.layer_rule({ match = { namespace = "quickshell:cheatsheet" },         animation = "slide bottom"             })
hl.layer_rule({ match = { namespace = "quickshell:dock" },               animation = "slide"                    })
hl.layer_rule({ match = { namespace = "quickshell:screenCorners" },      animation = "popin 120%"               })
hl.layer_rule({ match = { namespace = "quickshell:notificationPopup" },  animation = "fade"                     })
hl.layer_rule({ match = { namespace = "quickshell:overlay" },            ignore_alpha = 1                       })
hl.layer_rule({ match = { namespace = "quickshell:popup" },              xray = false, ignore_alpha = 1         })
hl.layer_rule({ match = { namespace = "quickshell:mediaControls" },      ignore_alpha = 1                       })
hl.layer_rule({ match = { namespace = "quickshell:reloadPopup" },        animation = "slide"                    })
hl.layer_rule({ match = { namespace = "quickshell:sidebarRight" },       animation = "slide right"              })
hl.layer_rule({ match = { namespace = "quickshell:sidebarLeft" },        animation = "slide left"               })
hl.layer_rule({ match = { namespace = "quickshell:verticalBar" },        animation = "slide"                    })
hl.layer_rule({ match = { namespace = "quickshell:osk" },                order = -1                             })
hl.layer_rule({ match = { namespace = "quickshell:wallpaperSelector" },  animation = "slide top"                })
hl.layer_rule({ match = { namespace = "quickshell:wTaskView" },          ignore_alpha = 0                       })
hl.layer_rule({ match = { namespace = "quickshell:wallpaperChanger" },   blur = true, ignore_alpha = 0.6, animation = "slide bottom" })

local quickshell_no_anim = {
    "quickshell:actionCenter", "quickshell:lockWindowPusher",
    "quickshell:overlay", "quickshell:overview", "quickshell:polkit",
    "quickshell:regionSelector", "quickshell:screenshot", "quickshell:session",
    "quickshell:wNotificationCenter", "quickshell:wOnScreenDisplay",
    "quickshell:wStartMenu", "quickshell:wTaskView",
}
for _, ns in ipairs(quickshell_no_anim) do
    hl.layer_rule({ match = { namespace = ns }, no_anim = true })
end

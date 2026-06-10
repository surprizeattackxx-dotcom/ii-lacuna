-- hyprnostretch.lua — No-stretch smooth animations; clean slide with eased exits

hl.curve("hyprnostretch", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.0 } } })   -- no stretch, smooth settle
hl.curve("easeOutCirc",   { type = "bezier", points = { { 0.0, 0.55 }, { 0.45, 1.0 } } })  -- snappy exit
hl.curve("easeOutExpo",   { type = "bezier", points = { { 0.16, 1.0 }, { 0.3, 1.0 } } })   -- workspace transition
hl.curve("menu_decel",    { type = "bezier", points = { { 0.1, 1.0 }, { 0.0, 1.0 } } })
hl.curve("menu_accel",    { type = "bezier", points = { { 0.38, 0.04 }, { 1.0, 0.07 } } })
hl.curve("liner",         { type = "bezier", points = { { 1, 1 }, { 1, 1 } } })

hl.animation({ leaf = "windows",       enabled = true, speed = 5, bezier = "hyprnostretch", style = "slide" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 5, bezier = "hyprnostretch", style = "slide" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 4, bezier = "easeOutCirc",   style = "slide" })
hl.animation({ leaf = "windowsMove",   enabled = true, speed = 5, bezier = "hyprnostretch", style = "slide" })

hl.animation({ leaf = "fade",          enabled = true, speed = 3, bezier = "hyprnostretch" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 3, bezier = "hyprnostretch" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 2, bezier = "easeOutCirc" })
hl.animation({ leaf = "fadeDim",       enabled = true, speed = 3, bezier = "hyprnostretch" })
hl.animation({ leaf = "fadeShadow",    enabled = true, speed = 3, bezier = "hyprnostretch" })

hl.animation({ leaf = "layersIn",      enabled = true, speed = 3, bezier = "menu_decel", style = "slide" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 2, bezier = "menu_accel" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 2, bezier = "menu_decel" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 2, bezier = "menu_accel" })

hl.animation({ leaf = "border",        enabled = true, speed = 1,  bezier = "liner" })
hl.animation({ leaf = "borderangle",   enabled = true, speed = 10, bezier = "liner", style = "once" })

hl.animation({ leaf = "workspaces",       enabled = true, speed = 5, bezier = "easeOutExpo",   style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4, bezier = "hyprnostretch", style = "slidevert" })

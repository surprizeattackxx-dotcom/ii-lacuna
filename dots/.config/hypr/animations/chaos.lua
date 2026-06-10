-- chaos.lua — Chaotic, high-energy animations with wild curves

hl.curve("crazyshot",       { type = "bezier", points = { { 0.1, 1.5 }, { 0.76, 0.92 } } })
hl.curve("OutBack",         { type = "bezier", points = { { 0.34, 1.56 }, { 0.64, 1.0 } } })
hl.curve("emphasizedDecel", { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1.0 } } })
hl.curve("emphasizedAccel", { type = "bezier", points = { { 0.3, 0.0 }, { 0.8, 0.15 } } })
hl.curve("easeOutExpo",     { type = "bezier", points = { { 0.16, 1.0 }, { 0.3, 1.0 } } })
hl.curve("easeOutCirc",     { type = "bezier", points = { { 0.0, 0.55 }, { 0.45, 1.0 } } })
hl.curve("menu_decel",      { type = "bezier", points = { { 0.1, 1.0 }, { 0.0, 1.0 } } })
hl.curve("menu_accel",      { type = "bezier", points = { { 0.38, 0.04 }, { 1.0, 0.07 } } })
hl.curve("liner",           { type = "bezier", points = { { 1, 1 }, { 1, 1 } } })

hl.animation({ leaf = "windows",       enabled = true, speed = 5,   bezier = "OutBack",         style = "popin 50%" })   -- spring in from center
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4,   bezier = "crazyshot",       style = "slide top" })   -- snap in from top
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 3,   bezier = "emphasizedAccel", style = "slide bottom" }) -- fall out the bottom
hl.animation({ leaf = "windowsMove",   enabled = true, speed = 5,   bezier = "easeOutCirc",     style = "slide" })

hl.animation({ leaf = "fade",          enabled = true, speed = 4,   bezier = "emphasizedDecel" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 4,   bezier = "emphasizedDecel" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 2.5, bezier = "emphasizedAccel" })
hl.animation({ leaf = "fadeDim",       enabled = true, speed = 4,   bezier = "emphasizedDecel" })
hl.animation({ leaf = "fadeShadow",    enabled = true, speed = 3,   bezier = "easeOutCirc" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 3,   bezier = "menu_decel" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 2,   bezier = "menu_accel" })

hl.animation({ leaf = "layersIn",  enabled = true, speed = 3, bezier = "menu_decel", style = "slide" }) -- slide in
hl.animation({ leaf = "layersOut", enabled = true, speed = 2, bezier = "emphasizedAccel" })             -- fade out

hl.animation({ leaf = "border",       enabled = true, speed = 1,  bezier = "liner" })
hl.animation({ leaf = "borderangle",  enabled = true, speed = 10, bezier = "liner", style = "once" })

-- Workspaces fade — contrasts with sliding windows
hl.animation({ leaf = "workspaces",       enabled = true, speed = 5, bezier = "easeOutExpo", style = "slidefade 15%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4, bezier = "OutBack",     style = "slidefadevert 20%" })

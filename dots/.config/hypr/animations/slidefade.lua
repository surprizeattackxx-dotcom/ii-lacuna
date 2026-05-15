-- slidefade.lua — Ghost slide: 20% directional slide + fade for workspace transitions

hl.curve("softAcDecel", { type = "bezier", points = { { 0.26, 0.26 }, { 0.15, 1.0 } } })  -- gentle ease in then decelerate
hl.curve("md3_decel",   { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1.0 } } })
hl.curve("md3_accel",   { type = "bezier", points = { { 0.3, 0.0 }, { 0.8, 0.15 } } })
hl.curve("menu_decel",  { type = "bezier", points = { { 0.1, 1.0 }, { 0.0, 1.0 } } })
hl.curve("menu_accel",  { type = "bezier", points = { { 0.38, 0.04 }, { 1.0, 0.07 } } })
hl.curve("easeOutCirc", { type = "bezier", points = { { 0.0, 0.55 }, { 0.45, 1.0 } } })

hl.animation({ leaf = "windows",       enabled = true, speed = 4, bezier = "md3_decel", style = "popin 65%" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4, bezier = "md3_decel", style = "popin 65%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 3, bezier = "md3_accel", style = "popin 80%" })
hl.animation({ leaf = "windowsMove",   enabled = true, speed = 4, bezier = "md3_decel", style = "slide" })

hl.animation({ leaf = "fade",          enabled = true, speed = 3, bezier = "md3_decel" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 3, bezier = "md3_decel" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 2, bezier = "md3_accel" })
hl.animation({ leaf = "fadeDim",       enabled = true, speed = 3, bezier = "md3_decel" })
hl.animation({ leaf = "fadeShadow",    enabled = true, speed = 3, bezier = "md3_decel" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 2, bezier = "menu_decel" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 2, bezier = "menu_accel" })

hl.animation({ leaf = "layersIn",      enabled = true, speed = 3, bezier = "menu_decel", style = "slide" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 2, bezier = "menu_accel" })

hl.animation({ leaf = "border",        enabled = true, speed = 10, bezier = "default" })

-- The ghost slide — 20% horizontal direction + fade
hl.animation({ leaf = "workspaces",       enabled = true, speed = 6, bezier = "softAcDecel", style = "slidefade 20%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4, bezier = "md3_decel",   style = "slidefade 10%" })

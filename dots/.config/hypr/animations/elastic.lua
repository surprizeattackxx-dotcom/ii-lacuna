-- elastic.lua — Springy overshoot animations with OutBack bounce

hl.curve("OutBack",     { type = "bezier", points = { { 0.34, 1.56 }, { 0.64, 1.0 } } })   -- spring past and rebound
hl.curve("InBack",      { type = "bezier", points = { { 0.36, 0.0 }, { 0.66, -0.56 } } })  -- pull back before launching
hl.curve("easeOutCirc", { type = "bezier", points = { { 0.0, 0.55 }, { 0.45, 1.0 } } })
hl.curve("md3_decel",   { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1.0 } } })
hl.curve("menu_decel",  { type = "bezier", points = { { 0.1, 1.0 }, { 0.0, 1.0 } } })
hl.curve("menu_accel",  { type = "bezier", points = { { 0.38, 0.04 }, { 1.0, 0.07 } } })
hl.curve("liner",       { type = "bezier", points = { { 1, 1 }, { 1, 1 } } })

hl.animation({ leaf = "windows",       enabled = true, speed = 5, bezier = "OutBack",     style = "popin 55%" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 5, bezier = "OutBack",     style = "popin 55%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 3, bezier = "easeOutCirc", style = "popin 80%" })
hl.animation({ leaf = "windowsMove",   enabled = true, speed = 5, bezier = "OutBack",     style = "slide" })

hl.animation({ leaf = "fade",          enabled = true, speed = 4, bezier = "md3_decel" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 4, bezier = "md3_decel" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 3, bezier = "easeOutCirc" })
hl.animation({ leaf = "fadeDim",       enabled = true, speed = 4, bezier = "md3_decel" })
hl.animation({ leaf = "fadeShadow",    enabled = true, speed = 4, bezier = "md3_decel" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 3, bezier = "menu_decel" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 2, bezier = "menu_accel" })

hl.animation({ leaf = "layersIn",      enabled = true, speed = 4, bezier = "OutBack",    style = "slide" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 2, bezier = "menu_accel" })

hl.animation({ leaf = "border",        enabled = true, speed = 1,  bezier = "liner" })
hl.animation({ leaf = "borderangle",   enabled = true, speed = 30, bezier = "liner", style = "loop" })

hl.animation({ leaf = "workspaces",       enabled = true, speed = 6, bezier = "OutBack", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 5, bezier = "OutBack", style = "slidevert" })

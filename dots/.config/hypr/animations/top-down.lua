-- top-down.lua — Windows drop in from top with gravity; fall out the bottom

hl.curve("drop",       { type = "bezier", points = { { 0.0, 0.9 }, { 0.3, 1.05 } } })   -- gravity decel with micro-bounce
hl.curve("fall",       { type = "bezier", points = { { 0.4, 0.0 }, { 1.0, 0.6 } } })    -- fast fall exit
hl.curve("menu_decel", { type = "bezier", points = { { 0.1, 1.0 }, { 0.0, 1.0 } } })
hl.curve("menu_accel", { type = "bezier", points = { { 0.38, 0.04 }, { 1.0, 0.07 } } })
hl.curve("liner",      { type = "bezier", points = { { 1, 1 }, { 1, 1 } } })

hl.animation({ leaf = "windows",       enabled = true, speed = 5, bezier = "drop", style = "slide top" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 5, bezier = "drop", style = "slide top" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 3, bezier = "fall", style = "slide bottom" })
hl.animation({ leaf = "windowsMove",   enabled = true, speed = 5, bezier = "drop", style = "slide" })

hl.animation({ leaf = "fade",          enabled = true, speed = 4, bezier = "drop" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 4, bezier = "drop" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 2, bezier = "fall" })
hl.animation({ leaf = "fadeDim",       enabled = true, speed = 4, bezier = "drop" })
hl.animation({ leaf = "fadeShadow",    enabled = true, speed = 4, bezier = "drop" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 3, bezier = "menu_decel" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 2, bezier = "menu_accel" })

hl.animation({ leaf = "layersIn",      enabled = true, speed = 4, bezier = "menu_decel", style = "slide top" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 2, bezier = "menu_accel" })

hl.animation({ leaf = "border",        enabled = true, speed = 1,  bezier = "liner" })
hl.animation({ leaf = "borderangle",   enabled = true, speed = 30, bezier = "liner", style = "loop" })

hl.animation({ leaf = "workspaces",       enabled = true, speed = 6, bezier = "drop", style = "slidevert" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 5, bezier = "drop", style = "slidefadevert 25%" })

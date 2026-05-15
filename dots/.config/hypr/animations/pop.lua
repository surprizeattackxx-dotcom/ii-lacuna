-- pop.lua — Bouncy popin animations; fun and lively feel

hl.curve("popIn",      { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.08 } } })   -- slight overshoot into place
hl.curve("popOut",     { type = "bezier", points = { { 0.3, 0.0 }, { 0.8, 0.1 } } })     -- quick collapse
hl.curve("popBounce",  { type = "bezier", points = { { 0.08, 1.1 }, { 0.15, 0.95 } } })  -- bouncy pop
hl.curve("menu_decel", { type = "bezier", points = { { 0.1, 1.0 }, { 0.0, 1.0 } } })
hl.curve("menu_accel", { type = "bezier", points = { { 0.38, 0.04 }, { 1.0, 0.07 } } })
hl.curve("liner",      { type = "bezier", points = { { 1, 1 }, { 1, 1 } } })

hl.animation({ leaf = "windows",       enabled = true, speed = 5, bezier = "popBounce", style = "popin 45%" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 5, bezier = "popIn",     style = "popin 50%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 3, bezier = "popOut",    style = "popin 85%" })
hl.animation({ leaf = "windowsMove",   enabled = true, speed = 5, bezier = "popIn",     style = "slide" })

hl.animation({ leaf = "fade",          enabled = true, speed = 4, bezier = "popIn" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 4, bezier = "popIn" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 2, bezier = "popOut" })
hl.animation({ leaf = "fadeDim",       enabled = true, speed = 4, bezier = "popIn" })
hl.animation({ leaf = "fadeShadow",    enabled = true, speed = 4, bezier = "popIn" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 3, bezier = "menu_decel" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 2, bezier = "menu_accel" })

hl.animation({ leaf = "layersIn",      enabled = true, speed = 4, bezier = "menu_decel", style = "popin 70%" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 2, bezier = "menu_accel" })

hl.animation({ leaf = "border",        enabled = true, speed = 1,  bezier = "liner" })
hl.animation({ leaf = "borderangle",   enabled = true, speed = 30, bezier = "liner", style = "loop" })

hl.animation({ leaf = "workspaces",       enabled = true, speed = 6, bezier = "popIn", style = "slidefade 15%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 5, bezier = "popIn", style = "slidefadevert 20%" })

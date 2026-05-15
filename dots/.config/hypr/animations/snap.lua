-- snap.lua — Fast, snappy animations; responsive feel without gaming-level spareness

hl.curve("snapDecel",  { type = "bezier", points = { { 0.1, 0.95 }, { 0.05, 1.0 } } })   -- fast settle
hl.curve("snapAccel",  { type = "bezier", points = { { 0.5, 0.0 }, { 0.9, 0.1 } } })     -- quick exit
hl.curve("snapMove",   { type = "bezier", points = { { 0.15, 0.9 }, { 0.1, 1.0 } } })    -- slightly softer for moves
hl.curve("menu_decel", { type = "bezier", points = { { 0.1, 1.0 }, { 0.0, 1.0 } } })
hl.curve("menu_accel", { type = "bezier", points = { { 0.38, 0.04 }, { 1.0, 0.07 } } })
hl.curve("liner",      { type = "bezier", points = { { 1, 1 }, { 1, 1 } } })

hl.animation({ leaf = "windows",       enabled = true, speed = 3, bezier = "snapDecel", style = "slide" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 3, bezier = "snapDecel", style = "slide" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 2, bezier = "snapAccel" })
hl.animation({ leaf = "windowsMove",   enabled = true, speed = 3, bezier = "snapMove",  style = "slide" })

hl.animation({ leaf = "fade",          enabled = true, speed = 2.5, bezier = "snapDecel" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 2.5, bezier = "snapDecel" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.5, bezier = "snapAccel" })
hl.animation({ leaf = "fadeDim",       enabled = true, speed = 2.5, bezier = "snapDecel" })
hl.animation({ leaf = "fadeShadow",    enabled = true, speed = 2.5, bezier = "snapDecel" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 2,   bezier = "menu_decel" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.5, bezier = "menu_accel" })

hl.animation({ leaf = "layersIn",      enabled = true, speed = 2.5, bezier = "menu_decel", style = "slide" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5, bezier = "menu_accel" })

hl.animation({ leaf = "border",        enabled = true, speed = 1, bezier = "liner" })

hl.animation({ leaf = "workspaces",       enabled = true, speed = 4, bezier = "snapDecel", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3, bezier = "snapDecel", style = "slidevert" })

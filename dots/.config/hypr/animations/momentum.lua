-- momentum.lua — Feels like a real viewport scroll; fast launch, hard decelerate

hl.curve("momentum",    { type = "bezier", points = { { 0.0, 0.9 }, { 0.0, 1.0 } } })   -- fast launch, hard decel
hl.curve("momentumOut", { type = "bezier", points = { { 0.9, 0.0 }, { 1.0, 0.0 } } })   -- fast out
hl.curve("coast",       { type = "bezier", points = { { 0.0, 0.75 }, { 0.15, 1.0 } } }) -- smooth coast to stop
hl.curve("menu_decel",  { type = "bezier", points = { { 0.1, 1.0 }, { 0.0, 1.0 } } })
hl.curve("menu_accel",  { type = "bezier", points = { { 0.38, 0.04 }, { 1.0, 0.07 } } })
hl.curve("liner",       { type = "bezier", points = { { 1, 1 }, { 1, 1 } } })

hl.animation({ leaf = "windows",       enabled = true, speed = 5,   bezier = "momentum",    style = "slide" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 5,   bezier = "momentum",    style = "slide" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 2.5, bezier = "momentumOut", style = "slide" })
hl.animation({ leaf = "windowsMove",   enabled = true, speed = 4,   bezier = "momentum",    style = "slide" })

hl.animation({ leaf = "fade",          enabled = true, speed = 4, bezier = "coast" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 4, bezier = "coast" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 2, bezier = "momentumOut" })
hl.animation({ leaf = "fadeDim",       enabled = true, speed = 4, bezier = "coast" })
hl.animation({ leaf = "fadeShadow",    enabled = true, speed = 4, bezier = "coast" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 3, bezier = "menu_decel" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 2, bezier = "menu_accel" })

hl.animation({ leaf = "layersIn",      enabled = true, speed = 3, bezier = "menu_decel", style = "slide" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 2, bezier = "menu_accel" })

hl.animation({ leaf = "border",        enabled = true, speed = 1, bezier = "liner" })

-- Workspace pan — feels like a real viewport scroll
hl.animation({ leaf = "workspaces",       enabled = true, speed = 7, bezier = "coast",    style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 5, bezier = "momentum", style = "slidevert" })

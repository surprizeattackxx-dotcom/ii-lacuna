-- liquid.lua — Fluid, flowing animations with symmetric S-curves

hl.curve("liquid",     { type = "bezier", points = { { 0.85, 0.0 }, { 0.15, 1.0 } } })   -- full symmetric S-curve
hl.curve("liquidIn",   { type = "bezier", points = { { 0.4, 0.0 }, { 0.6, 1.0 } } })     -- ease-in-out
hl.curve("liquidOut",  { type = "bezier", points = { { 0.0, 0.6 }, { 0.4, 1.0 } } })     -- flipped
hl.curve("flow",       { type = "bezier", points = { { 0.25, 0.46 }, { 0.45, 0.94 } } }) -- medium ease-out (iOS-like)
hl.curve("menu_decel", { type = "bezier", points = { { 0.1, 1.0 }, { 0.0, 1.0 } } })
hl.curve("menu_accel", { type = "bezier", points = { { 0.38, 0.04 }, { 1.0, 0.07 } } })

hl.animation({ leaf = "windows",       enabled = true, speed = 6, bezier = "liquid",   style = "slide" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 6, bezier = "liquidIn", style = "slide" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 4, bezier = "liquidOut" })
hl.animation({ leaf = "windowsMove",   enabled = true, speed = 6, bezier = "liquid",   style = "slide" })

hl.animation({ leaf = "fade",          enabled = true, speed = 5, bezier = "flow" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 5, bezier = "flow" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 4, bezier = "liquidOut" })
hl.animation({ leaf = "fadeDim",       enabled = true, speed = 5, bezier = "flow" })
hl.animation({ leaf = "fadeShadow",    enabled = true, speed = 5, bezier = "flow" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 4, bezier = "menu_decel" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 3, bezier = "menu_accel" })

hl.animation({ leaf = "layersIn",      enabled = true, speed = 5, bezier = "menu_decel", style = "slide" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 3, bezier = "menu_accel" })

hl.animation({ leaf = "border",        enabled = true, speed = 10, bezier = "default" })

hl.animation({ leaf = "workspaces",       enabled = true, speed = 7, bezier = "liquid", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 6, bezier = "liquid", style = "slidefadevert 15%" })

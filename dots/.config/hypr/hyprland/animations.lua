-- butter.lua — Smooth, buttery animations with no overshoot

hl.curve("butter",      { type = "bezier", points = { { 0.25, 1.0 }, { 0.5, 1.0 } } })   -- smooth decel, no overshoot
hl.curve("butterIn",    { type = "bezier", points = { { 0.4, 0.0 }, { 0.6, 1.0 } } })    -- ease-in-out symmetric
hl.curve("butterOut",   { type = "bezier", points = { { 0.4, 0.0 }, { 1.0, 1.0 } } })    -- ease-in, hard stop
hl.curve("fluent",      { type = "bezier", points = { { 0.1, 1.0 }, { 0.0, 1.0 } } })    -- fluent design decel
hl.curve("menu_decel",  { type = "bezier", points = { { 0.1, 1.0 }, { 0.0, 1.0 } } })
hl.curve("menu_accel",  { type = "bezier", points = { { 0.38, 0.04 }, { 1.0, 0.07 } } })

hl.animation({ leaf = "windows",       enabled = true, speed = 6,  bezier = "butter",    style = "slide" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 6,  bezier = "butter",    style = "slide" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 5,  bezier = "butterOut", style = "slide" })
hl.animation({ leaf = "windowsMove",   enabled = true, speed = 6,  bezier = "butter",    style = "slide" })

hl.animation({ leaf = "fade",          enabled = true, speed = 5,  bezier = "fluent" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 5,  bezier = "fluent" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 4,  bezier = "butterOut" })
hl.animation({ leaf = "fadeDim",       enabled = true, speed = 5,  bezier = "fluent" })
hl.animation({ leaf = "fadeShadow",    enabled = true, speed = 5,  bezier = "fluent" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 4,  bezier = "fluent" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 3,  bezier = "menu_accel" })

hl.animation({ leaf = "layersIn",      enabled = true, speed = 5,  bezier = "menu_decel", style = "slide" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 4,  bezier = "menu_accel" })

hl.animation({ leaf = "border",        enabled = true, speed = 10, bezier = "default" })

hl.animation({ leaf = "workspaces",       enabled = true, speed = 8, bezier = "butter",  style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 6, bezier = "butter",  style = "slidefadevert 20%" })

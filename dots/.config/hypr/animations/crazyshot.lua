-- crazyshot.lua — Elastic overshoot snap animations
-- NOTE: original .conf had a typo ("nimations" instead of "animations") — preserved faithfully here

hl.curve("crazyshot",  { type = "bezier", points = { { 0.1, 1.5 }, { 0.76, 0.92 } } })   -- elastic overshoot snap
hl.curve("md3_decel",  { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1.0 } } })    -- smooth settle
hl.curve("md3_accel",  { type = "bezier", points = { { 0.3, 0.0 }, { 0.8, 0.15 } } })    -- quick exit
hl.curve("menu_decel", { type = "bezier", points = { { 0.1, 1.0 }, { 0.0, 1.0 } } })     -- layer slide in
hl.curve("menu_accel", { type = "bezier", points = { { 0.38, 0.04 }, { 1.0, 0.07 } } })  -- layer slide out
hl.curve("liner",      { type = "bezier", points = { { 1, 1 }, { 1, 1 } } })

hl.animation({ leaf = "windows",       enabled = true, speed = 4, bezier = "crazyshot", style = "popin 50%" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4, bezier = "crazyshot", style = "popin 50%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 3, bezier = "md3_accel", style = "popin 80%" })
hl.animation({ leaf = "windowsMove",   enabled = true, speed = 4, bezier = "md3_decel", style = "slide" })

hl.animation({ leaf = "fade",          enabled = true, speed = 3, bezier = "md3_decel" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 3, bezier = "md3_decel" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 2, bezier = "md3_accel" })
hl.animation({ leaf = "fadeDim",       enabled = true, speed = 3, bezier = "md3_decel" })
hl.animation({ leaf = "fadeShadow",    enabled = true, speed = 3, bezier = "md3_decel" })

hl.animation({ leaf = "layersIn",      enabled = true, speed = 3, bezier = "menu_decel", style = "slide" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 2, bezier = "menu_accel" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 2, bezier = "menu_decel" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 2, bezier = "menu_accel" })

hl.animation({ leaf = "border",       enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "borderangle",  enabled = true, speed = 30, bezier = "liner", style = "loop" })

hl.animation({ leaf = "workspaces",       enabled = true, speed = 5, bezier = "md3_decel", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4, bezier = "md3_decel", style = "slidevert" })

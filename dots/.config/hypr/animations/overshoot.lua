-- overshoot.lua — Big dramatic overshoot on everything; high energy preset

hl.curve("bigShot",    { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.15 } } })   -- strong overshoot
hl.curve("bigShotIn",  { type = "bezier", points = { { 0.1, 1.2 }, { 0.1, 0.9 } } })     -- overshoot and bounce
hl.curve("quickExit",  { type = "bezier", points = { { 0.3, 0.0 }, { 0.9, 0.1 } } })
hl.curve("menu_decel", { type = "bezier", points = { { 0.1, 1.0 }, { 0.0, 1.0 } } })
hl.curve("menu_accel", { type = "bezier", points = { { 0.38, 0.04 }, { 1.0, 0.07 } } })
hl.curve("liner",      { type = "bezier", points = { { 1, 1 }, { 1, 1 } } })

hl.animation({ leaf = "windows",       enabled = true, speed = 6, bezier = "bigShot",   style = "slide" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 6, bezier = "bigShotIn", style = "popin 40%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 3, bezier = "quickExit", style = "popin 90%" })
hl.animation({ leaf = "windowsMove",   enabled = true, speed = 6, bezier = "bigShot",   style = "slide" })

hl.animation({ leaf = "fade",          enabled = true, speed = 5, bezier = "bigShot" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 5, bezier = "bigShot" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 3, bezier = "quickExit" })
hl.animation({ leaf = "fadeDim",       enabled = true, speed = 5, bezier = "bigShot" })
hl.animation({ leaf = "fadeShadow",    enabled = true, speed = 5, bezier = "bigShot" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 4, bezier = "menu_decel" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 2, bezier = "menu_accel" })

hl.animation({ leaf = "layersIn",      enabled = true, speed = 5, bezier = "bigShot",   style = "slide" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 2, bezier = "menu_accel" })

hl.animation({ leaf = "border",        enabled = true, speed = 1,  bezier = "liner" })
hl.animation({ leaf = "borderangle",   enabled = true, speed = 30, bezier = "liner", style = "loop" })

hl.animation({ leaf = "workspaces",       enabled = true, speed = 7, bezier = "bigShot",   style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 6, bezier = "bigShotIn", style = "slidevert" })

-- retro.lua — Fast-to-start, linear settle; retro terminal aesthetic

hl.curve("retro",    { type = "bezier", points = { { 0.0, 1.0 }, { 0.6, 1.0 } } })   -- fast to start, linear settle
hl.curve("retroOut", { type = "bezier", points = { { 0.6, 0.0 }, { 1.0, 0.0 } } })   -- hard out
hl.curve("liner",    { type = "bezier", points = { { 1, 1 }, { 1, 1 } } })

hl.animation({ leaf = "windows",       enabled = true, speed = 4, bezier = "retro",    style = "popin 70%" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4, bezier = "retro",    style = "popin 70%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 2, bezier = "retroOut", style = "popin 90%" })
hl.animation({ leaf = "windowsMove",   enabled = true, speed = 4, bezier = "retro",    style = "slide" })

hl.animation({ leaf = "fade",          enabled = true, speed = 3,   bezier = "retro" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 3,   bezier = "retro" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 2,   bezier = "retroOut" })
hl.animation({ leaf = "fadeDim",       enabled = true, speed = 3,   bezier = "retro" })
hl.animation({ leaf = "fadeShadow",    enabled = true, speed = 3,   bezier = "retro" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 2,   bezier = "retro" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.5, bezier = "retroOut" })

hl.animation({ leaf = "layersIn",      enabled = true, speed = 3, bezier = "retro",    style = "slide" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 2, bezier = "retroOut" })

hl.animation({ leaf = "border",        enabled = true, speed = 1,  bezier = "liner" })
hl.animation({ leaf = "borderangle",   enabled = true, speed = 30, bezier = "liner", style = "once" })

hl.animation({ leaf = "workspaces",       enabled = true, speed = 5, bezier = "retro",    style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4, bezier = "retro",    style = "slidevert" })

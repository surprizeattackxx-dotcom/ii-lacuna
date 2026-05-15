-- gaming.lua — Minimal-latency animations for gaming; sub-2s everything

hl.curve("snap",      { type = "bezier", points = { { 0.15, 1.0 }, { 0.25, 1.0 } } })   -- instant settle, no overshoot
hl.curve("snapExit",  { type = "bezier", points = { { 0.25, 0.0 }, { 0.75, 0.0 } } })   -- fast disappear
hl.curve("liner",     { type = "bezier", points = { { 1, 1 }, { 1, 1 } } })

hl.animation({ leaf = "windows",       enabled = true, speed = 1.2, bezier = "snap",     style = "slide" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 1.2, bezier = "snap",     style = "slide" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 0.8, bezier = "snapExit" })
hl.animation({ leaf = "windowsMove",   enabled = true, speed = 1.5, bezier = "snap",     style = "slide" })

hl.animation({ leaf = "fade",          enabled = true, speed = 1.5, bezier = "snap" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.5, bezier = "snap" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.0, bezier = "snapExit" })
hl.animation({ leaf = "fadeDim",       enabled = true, speed = 1.0, bezier = "snap" })
hl.animation({ leaf = "fadeShadow",    enabled = true, speed = 1.0, bezier = "snap" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.0, bezier = "snap" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 0.8, bezier = "snapExit" })

hl.animation({ leaf = "layersIn",      enabled = true, speed = 1.0, bezier = "snap" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 0.8, bezier = "snapExit" })

hl.animation({ leaf = "border",      enabled = false })
hl.animation({ leaf = "borderangle", enabled = false })

hl.animation({ leaf = "workspaces",       enabled = true, speed = 1.5, bezier = "snap", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 1.2, bezier = "snap", style = "slidevert" })

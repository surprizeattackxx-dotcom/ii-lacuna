-- material-you.lua — MD3 Material You official easing curves

-- MD3 official easing curves
hl.curve("emphasized",      { type = "bezier", points = { { 0.2, 0.0 }, { 0.0, 1.0 } } })   -- MD3 Emphasized
hl.curve("emphasizedDecel", { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1.0 } } })  -- MD3 Emphasized-Decelerate
hl.curve("emphasizedAccel", { type = "bezier", points = { { 0.3, 0.0 }, { 0.8, 0.15 } } })  -- MD3 Emphasized-Accelerate
hl.curve("standard",        { type = "bezier", points = { { 0.2, 0.0 }, { 0.0, 1.0 } } })   -- MD3 Standard
hl.curve("standardDecel",   { type = "bezier", points = { { 0.0, 0.0 }, { 0.0, 1.0 } } })   -- MD3 Standard-Decelerate
hl.curve("standardAccel",   { type = "bezier", points = { { 0.3, 0.0 }, { 1.0, 1.0 } } })   -- MD3 Standard-Accelerate

-- Windows — MD3 container enter/exit
hl.animation({ leaf = "windows",     enabled = true, speed = 4,   bezier = "emphasizedDecel", style = "popin 60%" })
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 4,   bezier = "emphasizedDecel", style = "popin 60%" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 2.5, bezier = "emphasizedAccel", style = "popin 90%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4,   bezier = "emphasized",      style = "slide" })

-- Fades — MD3 fade through
hl.animation({ leaf = "fade",       enabled = true, speed = 3, bezier = "standardDecel" })
hl.animation({ leaf = "fadeIn",     enabled = true, speed = 3, bezier = "standardDecel" })
hl.animation({ leaf = "fadeOut",    enabled = true, speed = 2, bezier = "standardAccel" })
hl.animation({ leaf = "fadeDim",    enabled = true, speed = 3, bezier = "standardDecel" })
hl.animation({ leaf = "fadeShadow", enabled = true, speed = 3, bezier = "standardDecel" })

-- Layers — MD3 menu/sheet motion
hl.animation({ leaf = "layersIn",      enabled = true, speed = 3,   bezier = "emphasizedDecel", style = "slide" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 2,   bezier = "emphasizedAccel" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 2.5, bezier = "standardDecel" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.8, bezier = "standardAccel" })

hl.animation({ leaf = "border",        enabled = true, speed = 10, bezier = "default" })

-- Workspaces — MD3 page transition
hl.animation({ leaf = "workspaces",       enabled = true, speed = 5, bezier = "emphasized",      style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4, bezier = "emphasizedDecel", style = "slidefadevert 15%" })

-- cinematic.lua — Slow, dramatic, film-like animations

hl.curve("cinIn",         { type = "bezier", points = { { 0.0, 0.0 }, { 0.2, 1.0 } } })    -- slow start, dramatic decel
hl.curve("cinOut",        { type = "bezier", points = { { 0.8, 0.0 }, { 1.0, 1.0 } } })    -- hard exit
hl.curve("cinCross",      { type = "bezier", points = { { 0.4, 0.0 }, { 0.6, 1.0 } } })    -- symmetric crossfade
hl.curve("menu_decel",    { type = "bezier", points = { { 0.1, 1.0 }, { 0.0, 1.0 } } })
hl.curve("menu_accel",    { type = "bezier", points = { { 0.38, 0.04 }, { 1.0, 0.07 } } })
hl.curve("easeInOutCirc", { type = "bezier", points = { { 0.85, 0.0 }, { 0.15, 1.0 } } })

hl.animation({ leaf = "windows",      enabled = true, speed = 8,  bezier = "cinIn",  style = "slide bottom" })
hl.animation({ leaf = "windowsIn",    enabled = true, speed = 8,  bezier = "cinIn",  style = "slide bottom" })
hl.animation({ leaf = "windowsOut",   enabled = true, speed = 5,  bezier = "cinOut", style = "slide top" })
hl.animation({ leaf = "windowsMove",  enabled = true, speed = 7,  bezier = "cinIn",  style = "slide" })

hl.animation({ leaf = "fade",         enabled = true, speed = 7,  bezier = "cinCross" })
hl.animation({ leaf = "fadeIn",       enabled = true, speed = 7,  bezier = "cinCross" })
hl.animation({ leaf = "fadeOut",      enabled = true, speed = 5,  bezier = "cinOut" })
hl.animation({ leaf = "fadeDim",      enabled = true, speed = 7,  bezier = "cinCross" })
hl.animation({ leaf = "fadeShadow",   enabled = true, speed = 7,  bezier = "cinCross" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 6,  bezier = "cinIn" })
hl.animation({ leaf = "fadeLayersOut",enabled = true, speed = 4,  bezier = "cinOut" })

hl.animation({ leaf = "layersIn",  enabled = true, speed = 6, bezier = "menu_decel", style = "slide" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 4, bezier = "menu_accel" })

hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "default" })

hl.animation({ leaf = "workspaces",       enabled = true, speed = 10, bezier = "easeInOutCirc", style = "slidefadevert 25%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 8,  bezier = "cinIn",         style = "slidefadevert 30%" })

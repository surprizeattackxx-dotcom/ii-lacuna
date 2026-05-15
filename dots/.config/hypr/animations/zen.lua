-- zen.lua — Minimal, calm fade-only animations; no sliding, no borders

hl.curve("zenIn",  { type = "bezier", points = { { 0.3, 0.0 }, { 0.7, 1.0 } } })  -- symmetric ease, no personality
hl.curve("zenOut", { type = "bezier", points = { { 0.3, 0.0 }, { 0.7, 1.0 } } })

hl.animation({ leaf = "windows",       enabled = true, speed = 2,   bezier = "zenIn",  style = "fade" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 2,   bezier = "zenIn",  style = "fade" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.5, bezier = "zenOut", style = "fade" })
hl.animation({ leaf = "windowsMove",   enabled = true, speed = 2,   bezier = "zenIn" })

hl.animation({ leaf = "fade",          enabled = true, speed = 2,   bezier = "zenIn" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 2,   bezier = "zenIn" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.5, bezier = "zenOut" })
hl.animation({ leaf = "fadeDim",       enabled = true, speed = 2,   bezier = "zenIn" })
hl.animation({ leaf = "fadeShadow",    enabled = true, speed = 2,   bezier = "zenIn" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 2,   bezier = "zenIn" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.5, bezier = "zenOut" })

hl.animation({ leaf = "layersIn",      enabled = true, speed = 2,   bezier = "zenIn",  style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5, bezier = "zenOut", style = "fade" })

hl.animation({ leaf = "border",      enabled = false })
hl.animation({ leaf = "borderangle", enabled = false })

hl.animation({ leaf = "workspaces",       enabled = true, speed = 3, bezier = "zenIn", style = "fade" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3, bezier = "zenIn", style = "slidefadevert 5%" })

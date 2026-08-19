-- cyberpunk.lua — Neon overshoot, sharp transitions, futuristic feel

-- Cyberpunk easing curves
hl.curve("cpSharp",      { type = "bezier", points = { { 0.0, 0.0 }, { 0.0, 1.0 } } })             -- sharp decelerate
hl.curve("cpSnap",       { type = "bezier", points = { { 0.12, 0.0 }, { 0.39, 0.0 } } })            -- snappy exit
hl.curve("cpOvershoot",  { type = "bezier", points = { { 0.15, 1.2 }, { 0.24, 1.0 } } })            -- neon overshoot in
hl.curve("cpGlide",      { type = "bezier", points = { { 0.25, 0.1 }, { 0.25, 1.0 } } })            -- smooth glide
hl.curve("cpFlicker",    { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.0 } } })             -- fast flicker-in
hl.curve("cpFade",       { type = "bezier", points = { { 0.0, 0.0 }, { 0.05, 0.9 } } })             -- quick fade-out

-- Windows — pop in with overshoot, slide out sharp
hl.animation({ leaf = "windows",     enabled = true, speed = 5,   bezier = "cpOvershoot", style = "popin 55%" })
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 5,   bezier = "cpOvershoot", style = "popin 55%" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 4,   bezier = "cpSnap",      style = "popin 95%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 5,   bezier = "cpGlide",     style = "slide" })

-- Fades — quick flicker in, fast out
hl.animation({ leaf = "fade",       enabled = true, speed = 4, bezier = "cpFlicker" })
hl.animation({ leaf = "fadeIn",     enabled = true, speed = 4, bezier = "cpFlicker" })
hl.animation({ leaf = "fadeOut",    enabled = true, speed = 3, bezier = "cpFade" })
hl.animation({ leaf = "fadeDim",    enabled = true, speed = 3, bezier = "cpSharp" })
hl.animation({ leaf = "fadeShadow", enabled = true, speed = 3, bezier = "cpSharp" })

-- Layers — slide in from edge, snap out
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,   bezier = "cpGlide",   style = "slide" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 3,   bezier = "cpSnap" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 3.5, bezier = "cpFlicker" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 2.5, bezier = "cpFade" })

-- Border — fast color sweep
hl.animation({ leaf = "border",        enabled = true, speed = 8, bezier = "default" })

-- Workspaces — slide with overshoot
hl.animation({ leaf = "workspaces",       enabled = true, speed = 4, bezier = "cpOvershoot", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4, bezier = "cpGlide",     style = "slidefadevert 20%" })

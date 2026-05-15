-- vertical.lua — Vertical workspace gestures preset; popin windows, slidefadevert workspaces
-- Note: original conf included gesture directives outside animations {} block — those are
-- not part of the animation config and should be set in your main hyprland config instead:
--   gesture = 3, horizontal, unset
--   gesture = 3, vertical, workspace

hl.curve("fluent_decel",  { type = "bezier", points = { { 0, 0.2 }, { 0.4, 1 } } })
hl.curve("easeOutCirc",   { type = "bezier", points = { { 0, 0.55 }, { 0.45, 1 } } })
hl.curve("easeOutCubic",  { type = "bezier", points = { { 0.33, 1 }, { 0.68, 1 } } })
hl.curve("easeinoutsine", { type = "bezier", points = { { 0.37, 0 }, { 0.63, 1 } } })

-- Windows
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 1.5, bezier = "easeinoutsine", style = "popin 60%" })  -- window open
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 1.5, bezier = "easeOutCubic",  style = "popin 60%" })  -- window close
hl.animation({ leaf = "windowsMove", enabled = true, speed = 1.5, bezier = "easeinoutsine", style = "slide" })      -- move/drag/resize

-- Fading
hl.animation({ leaf = "fade",         enabled = true,  speed = 2.5, bezier = "fluent_decel" })
hl.animation({ leaf = "fadeLayersIn", enabled = false })
hl.animation({ leaf = "border",       enabled = false })

-- Layers
hl.animation({ leaf = "layers", enabled = true, speed = 1.5, bezier = "easeinoutsine", style = "popin" })

-- Workspaces
-- hl.animation({ leaf = "workspaces", enabled = true, speed = 3, bezier = "fluent_decel", style = "slidefade 30%" })
hl.animation({ leaf = "workspaces",       enabled = true, speed = 3, bezier = "fluent_decel", style = "slidefadevert 30%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2, bezier = "fluent_decel", style = "slidefade 10%" })

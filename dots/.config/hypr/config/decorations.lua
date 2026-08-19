-- Look and feel — Cyberpunk Neon

hl.config({
    general = {
        gaps_in = 4,
        gaps_out = 8,
        border_size = 3,
        extend_border_grab_area = 10,
        resize_on_border = true,
        col = {
            active_border = {
                colors = { CACHYLGREEN, CACHYLBLUE },
                angle = 135,
            },
            inactive_border = CACHYGRAY,
        },
    },
    group = {
        col = {
            border_active = CACHYLBLUE,
            border_inactive = CACHYGRAY,
            border_locked_active = "rgba(ff00aaff)",
            border_locked_inactive = CACHYGRAY,
        },
        groupbar = {
            col = {
                active = CACHYLGREEN,
                inactive = CACHYGRAY,
                locked_active = "rgba(ff00aaff)",
                locked_inactive = CACHYGRAY,
            },
        },
    },
    decoration = {
        dim_special = 0.4,
        rounding = 12,
        rounding_power = 2,
        active_opacity = 0.88,
        inactive_opacity = 0.78,
        fullscreen_opacity = 1,
        blur = {
            enabled = true,
            size = 20,
            passes = 8,
            noise = 0.04,
            vibrancy = 0.5,
            special = true,
        },
        shadow = {
            enabled = true,
            range = 30,
            render_power = 3,
            color = "rgba(00f0ff33)",
            offset = "0 4",
            blur = true,
        },
    },
})

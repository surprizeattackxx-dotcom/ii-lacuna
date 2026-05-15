-- Look and Feel

hl.config({
    general = {
        gaps_in = 4,
        gaps_out = 5,
        gaps_workspaces = 50,
        border_size = 3,
        col = {
            active_border = "rgba(0DB7D455)",
            inactive_border = "rgba(31313600)",
        },
        resize_on_border = true,
        no_focus_fallback = true,
        allow_tearing = true,
        layout = "dwindle",
    },

    dwindle = {
        preserve_split = true,
        smart_split = false,
        smart_resizing = false,
    },

    decoration = {
        rounding = 18,
        rounding_power = 4,

        blur = {
            enabled = false,
            size = 10,
            passes = 3,
            xray = true,
            special = false,
            new_optimizations = true,
            brightness = 1,
            noise = 0.05,
            contrast = 0.89,
            vibrancy = 0.5,
            vibrancy_darkness = 0.5,
            popups = false,
            popups_ignorealpha = 0.6,
            input_methods = true,
            input_methods_ignorealpha = 0.8,
        },

        shadow = {
            enabled = false,
            range = 50,
            render_power = 10,
            color = "rgba(00000027)",
            offset = { 0, 4 },
        },

        dim_inactive = true,
        dim_strength = 0.05,
        dim_special = 0.2,
    },

    animations = {
        enabled = true,
    },

    misc = {
        disable_hyprland_logo = true,
        force_default_wallpaper = 0,
        mouse_move_enables_dpms = true,
        key_press_enables_dpms = true,
    },

    debug = {
        damage_tracking = 2,
        disable_logs = true,
        disable_time = true,
    },
})

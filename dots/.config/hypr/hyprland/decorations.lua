-- Look and feel configuration

hl.config({
    general = {
        gaps_in = 3,
        gaps_out = 8,
        border_size = 2,
        extend_border_grab_area = 10,
        resize_on_border = true,
        col = {
            active_border = {
                colors = { '0xff6C7778', '0xff121C1D' },
                angle = 45,
            },
            inactive_border = '0xffDFE3E3',
        },
    },
    group = {
        col = {
            border_active = '0xff6C7778',
            border_inactive = '0xffDFE3E3',
            border_locked_active = '0xff6C7778',
            border_locked_inactive = '0xffDFE3E3',
        },
        groupbar = {
            col = {
                active = '0xff6C7778',
                inactive = '0xffDFE3E3',
                locked_active = '0xff6C7778',
                locked_inactive = '0xffDFE3E3',
            },
        },
    },
    decoration = {
        dim_special = 0.3,
        rounding = 10,
        active_opacity = 0.95,
        inactive_opacity = 0.85,
        fullscreen_opacity = 1,
        blur = {
            size = 5,
            passes = 4,
            special = true,
        },
    },
})

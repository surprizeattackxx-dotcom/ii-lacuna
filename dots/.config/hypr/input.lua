-- Input & Gestures

hl.config({
    input = {
        kb_layout = "us",
        follow_mouse = 1,
        sensitivity = 0,

        touchpad = {
            natural_scroll = false,
            disable_while_typing = true,
            tap_to_click = true,
        },
    },
})

hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})

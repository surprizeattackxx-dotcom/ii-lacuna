-- Look and Feel

hl.config({
  -- ─── Animations ──────────────────────────────────
  animations = {
    enabled = true,
    workspace_wraparound = true
  },
  -- ─── Debug ───────────────────────────────────────
  debug = {
    damage_tracking = 2,
    disable_logs = true,
    disable_time = true
  },
  -- ─── Decoration ──────────────────────────────────
  decoration = {
    blur = {
      brightness = 1,
      contrast = 0.89,
      enabled = true,
      ignore_opacity = true,
      input_methods = true,
      input_methods_ignorealpha = 0.8,
      new_optimizations = true,
      noise = 0.05,
      passes = 3,
      popups = true,
      popups_ignorealpha = 0.6,
      size = 10,
      special = false,
      vibrancy = 0.5,
      vibrancy_darkness = 0,
      xray = true
    },
    border_part_of_window = true,
    dim_inactive = true,
    dim_special = 0.2,
    dim_strength = 0.05,
    glow = {
      enabled = true,
      range = 6,
      render_power = 3
    },
    rounding = 18,
    rounding_power = 4,
    shadow = {
      color = "rgba(00000027)",
      enabled = true,
      offset = {
        0,
        4
      },
      range = 2,
      render_power = 3
    }
  },
  -- ─── Dwindle Layout ──────────────────────────────
  dwindle = {
    preserve_split = false,
    smart_resizing = false,
    smart_split = false
  },
  -- ─── General ─────────────────────────────────────
  general = {
    allow_tearing = true,
    border_size = 3,
    col = {
      active_border = "rgba(0DB7D455)",
      inactive_border = "rgba(31313600)"
    },
    gaps_in = 6,
    gaps_out = 4,
    gaps_workspaces = 50,
    layout = "dwindle",
    no_focus_fallback = true,
    resize_on_border = true,
    snap = {
      enabled = true,
      respect_gaps = true
    }
  },
  -- ─── Misc ────────────────────────────────────────
  misc = {
    allow_session_lock_restore = true,
    animate_manual_resizes = true,
    animate_mouse_windowdragging = true,
    close_special_on_empty = true,
    disable_hyprland_logo = true,
    enable_swallow = false,
    force_default_wallpaper = 0,
    key_press_enables_dpms = true,
    mouse_move_enables_dpms = true,
    initial_workspace_tracking = false,
    mouse_move_focuses_monitor = false,
    vrr = 1
  },
  binds = {
    hide_special_on_workspace_change = true,
    scroll_event_delay = 0
  },
  xwayland = {
    force_zero_scaling = true
  }
})

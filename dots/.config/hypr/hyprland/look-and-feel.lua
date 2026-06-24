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
    border_part_of_window = true,
    dim_inactive = false,
    dim_special = 0.2,
    dim_strength = 0.05,
    glow = {
      enabled = false,
      range = 2,
      render_power = 3
    },
    inactive_opacity = 1.0,
    active_opacity = 1.0,
    blur = {
      enabled = true,
      size = 16,
      passes = 4,
      xray = true,
      noise = 0.015,
      contrast = 0.85,
      brightness = 1.15,
      vibrancy = 1.0,
      vibrancy_darkness = 0.3,
    },
    rounding = 18,
    rounding_power = 4,
    shadow = {
      color = "rgba(00000027)",
      enabled = false,
      offset = {
        0,
        4
      },
      range = 2,
      render_power = 1
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
    gaps_in = 2,
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
    mouse_move_focuses_monitor = true,
    vrr = 1
  },
  binds = {
    hide_special_on_workspace_change = true,
    scroll_event_delay = 0
  },
  xwayland = {
    force_zero_scaling = true
  },
  -- ─── OSRS Stone Borders (borders-plus-plus) ──────
})

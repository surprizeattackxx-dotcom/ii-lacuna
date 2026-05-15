-- Environment Variables

hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("NIXOS_OZONE_WL", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("QT_QPA_PLATFORMTHEME", "kde")
hl.env("XDG_MENU_PREFIX", "plasma-")
hl.env("XDG_DATA_DIRS", "$HOME/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share")
hl.env("ILLOGICAL_IMPULSE_VIRTUAL_ENV", "~/.local/state/quickshell/.venv")
hl.env("TERMINAL", "kitty -1")
hl.env("EDITOR", "kate")

-- NVIDIA / DRM
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("AQ_DRM_DEVICES", "/dev/dri/card1")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("LIBVA_DRIVER_NAME", "nvidia")
--hl.env("__GL_GSYNC_ALLOWED", "")
--hl.env("__GL_VRR_ALLOWED", "")

-- Cursor / Theme
hl.env("XCURSOR_THEME", "oreo_gruvbox_grey_cursors")
hl.env("XCURSOR_SIZE", "24")
hl.env("XDG_ICON_THEME", "Papirus-Light")
_G.editor = "kate"

-- Environmental variables
-- if you don't use UWSM, define your variables here (e.g. hl.env("QT_QPA_PLATFORM", "wayland"))

-- ─── NVIDIA / DRM ──────────────────────────────
--hl.env("__GL_GSYNC_ALLOWED", "")
--hl.env("__GL_VRR_ALLOWED", "")

-- ─── Desktop & Session ─────────────────────────
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("QT_QPA_PLATFORMTHEME", "kde")
hl.env("XDG_MENU_PREFIX", "plasma-")
hl.env("XDG_DATA_DIRS", os.getenv("HOME") .. "/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share")

-- ─── Tools & Editors ──────────────────────────
hl.env("TERMINAL", "kitty -1")
hl.env("EDITOR", "kate")

-- ─── Graphics & Display ───────────────────────
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("AQ_DRM_DEVICES", "/dev/dri/card1:card0")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("NVD_BACKEND", "direct")
hl.env("GSK_RENDERER","opengl")

-- ─── Theme & Icons ─────────────────────────────
hl.env("XCURSOR_SIZE", "24")
hl.env("XDG_ICON_THEME", "Papirus-Light")

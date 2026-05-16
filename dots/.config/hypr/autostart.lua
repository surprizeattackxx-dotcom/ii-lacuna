-- Autostart

hl.on("hyprland.start", function()
    -- Load plugins (hyprpm-managed + local)
    hl.exec_cmd("hyprpm reload -n")

    -- Load local plugins
    local plugin_base = os.getenv("HOME") .. "/projects"
    hl.exec_cmd("sleep 5 && " ..
        "hyprctl plugin load " .. plugin_base .. "/hypr-plugins/hymission/build-cmake/libhymission.so" )
    hl.exec_cmd("sleep 5 && " ..
        "hyprctl plugin load " .. plugin_base .. "/hypr-gamma/build/libhyprgamma.so" )
    hl.exec_cmd("sleep 5 && " ..
        "hyprctl plugin load " .. plugin_base .. "/hypr-plugins/hypr-dynamic-cursors/out/dynamic-cursors.so" )
    hl.exec_cmd("sleep 5 && " ..
        "hyprctl plugin load " .. plugin_base .. "/hypr-plugins/hyprtrails/Build/libhyprtrails.so" )
    -- hyprglass disabled — crashes Hyprland on XWayland fullscreen games (Forza Horizon 5)
    -- "sleep 1 && hyprctl plugin load " .. plugin_base .. "/hypr-plugins/hyprglass/hyprglass.so")

    -- Dynamic monitor daemon (hotplug → auto-migrate workspaces)
    hl.exec_cmd("~/.config/hypr/scripts/monitor-watch.sh")
    hl.exec_cmd("~/.config/hypr/scripts/update_notifier.sh")

    -- Pin workspaces to monitors after startup (fixes init race where monitors
    -- may connect before workspace rules fire, leaving secondary monitors unreachable)
    -- Reads monitor-state.lua for user's actual monitor names
    hl.exec_cmd(
        "sleep 3 && " ..
        "bash -c 'STATE=\"$HOME/.config/hypr/monitor-state.lua\"; " ..
        "if [ -f \"$STATE\" ]; then " ..
        "  MONS=$(grep -oP '\"[A-Z0-9-]+\"' \"$STATE\" | tr -d \\'\"\\' | head -3); " ..
        "  IFS=$\\'\\n\\' read -r -a ARR <<< \"$MONS\"; " ..
        "  [ ${#ARR[@]} -ge 2 ] && hyprctl dispatch moveworkspacetomonitor 11 ${ARR[1]}; " ..
        "  [ ${#ARR[@]} -ge 3 ] && hyprctl dispatch moveworkspacetomonitor 21 ${ARR[2]}; " ..
        "  [ ${#ARR[@]} -ge 1 ] && hyprctl dispatch focusmonitor ${ARR[0]}; " ..
        "fi'"
    )

    -- Core services
    hl.exec_cmd("nm-applet")
    hl.exec_cmd("qs -c ii")
    -- hamr-daemon is now managed by systemd user service
    hl.exec_cmd("hamr-gtk")

    -- From hyprland/execs.conf
    hl.exec_cmd("~/.config/hypr/hyprland/scripts/start_geoclue_agent.sh")
    hl.exec_cmd("qs -c $qsConfig")
    hl.exec_cmd("~/.config/hypr/custom/scripts/__restore_video_wallpaper.sh")
    hl.exec_cmd("sleep 3 && bash ~/.config/quickshell/ii/scripts/colors/switchwall.sh --restore")
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    hl.exec_cmd("dbus-update-activation-environment --all")
    hl.exec_cmd("sleep 1 && dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("easyeffects --hide-window --service-mode")
    hl.exec_cmd("wl-paste --type text --watch bash -c 'cliphist store && qs -c $qsConfig ipc call cliphistService update'")
    hl.exec_cmd("wl-paste --type image --watch bash -c 'cliphist store && qs -c $qsConfig ipc call cliphistService update'")

    -- Apps (staggered for smoother startup)
    hl.exec_cmd("sleep 1 && thunderbird")
    hl.exec_cmd("sleep 2 && discord")
    hl.exec_cmd("sleep 4 && steam")
    hl.exec_cmd("sleep 1 && hamr")
    hl.exec_cmd("openrgb --start-minimized --profile 'Default'")

    -- Cursor setup
    hl.exec_cmd("hyprctl setcursor oreo_gruvbox_grey_cursors 24")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme oreo_gruvbox_grey_cursors")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-size 24")
    hl.exec_cmd("mkdir -p ~/.icons/default && printf '[Icon Theme]\\nInherits=oreo_gruvbox_grey_cursors\\n' > ~/.icons/default/index.theme")
end)

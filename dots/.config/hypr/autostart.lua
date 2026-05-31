-- Autostart

hl.on("hyprland.start", function()
  -- ─── Hardware & Services ────────────────────────
  hl.exec_cmd("hyprpm reload -n")
  hl.exec_cmd("~/.config/hypr/scripts/monitor-watch.sh")
  hl.exec_cmd("~/.config/hypr/scripts/update_notifier.sh")
  hl.exec_cmd("sleep 3 && bash -c 'STATE=\"$HOME/.config/hypr/monitor-state.lua\"; if [ -f \"$STATE\" ]; then   MONS=$(grep -oP '\"[A-Z0-9-]+\"' \"$STATE\" | tr -d \\'\"\\' | head -3);   IFS=$\\'\\n\\' read -r -a ARR <<< \"$MONS\";   [ ${#ARR[@]} -ge 2 ] && hyprctl dispatch moveworkspacetomonitor 11 ${ARR[1]};   [ ${#ARR[@]} -ge 3 ] && hyprctl dispatch moveworkspacetomonitor 21 ${ARR[2]};   [ ${#ARR[@]} -ge 1 ] && hyprctl dispatch focusmonitor ${ARR[0]}; fi'")

  -- ─── Desktop Services ───────────────────────────
  hl.exec_cmd("nm-applet")
  hl.exec_cmd("kdeconnectd")
  -- quickshell now runs as a systemd user service (quickshell-ii.service) for a
  -- persistent raised FD limit; enabled via WantedBy=graphical-session.target
  hl.exec_cmd("systemctl --user start quickshell-ii.service")
  hl.exec_cmd("~/.config/hypr/hyprland/scripts/start_geoclue_agent.sh")
  hl.exec_cmd("~/.config/hypr/custom/scripts/__restore_video_wallpaper.sh")
  hl.exec_cmd("sleep 3 && bash ~/.config/quickshell/ii/scripts/colors/switchwall.sh --restore")

  -- ─── Auth & Keyring ─────────────────────────────
  hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
  hl.exec_cmd("dbus-update-activation-environment --all")
  hl.exec_cmd("sleep 1 && dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")

  -- ─── Audio & Clipboard ──────────────────────────
  hl.exec_cmd("easyeffects --hide-window --service-mode")
  hl.exec_cmd("wl-paste --type text --watch bash -c 'cliphist store && qs -c $qsConfig ipc call cliphistService update'")
  hl.exec_cmd("wl-paste --type image --watch bash -c 'cliphist store && qs -c $qsConfig ipc call cliphistService update'")

  -- ─── Apps ───────────────────────────────────────
  hl.exec_cmd("sleep 1 && thunderbird")
  hl.exec_cmd("sleep 2 && discord")
  hl.exec_cmd("sleep 4 && steam")
  hl.exec_cmd("openrgb --start-minimized --profile 'Default'")

  -- ─── Theme & Cursor ─────────────────────────────
  hl.exec_cmd("hyprctl setcursor oreo_red_cursors 24")
  hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme oreo_red_cursors")
  hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-size 24")
  hl.exec_cmd("mkdir -p ~/.icons/default && printf '[Icon Theme]\\nInherits=oreo_red_cursors\\n' > ~/.icons/default/index.theme")
end)

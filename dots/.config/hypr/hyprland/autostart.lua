-- Autostart

hl.on("hyprland.start", function()
  -- ─── Hardware & Services ────────────────────────
  hl.exec_cmd("hyprpm reload -n")
  hl.exec_cmd("hypridle")
  hl.exec_cmd("~/.config/hypr/scripts/monitor-watch.sh")
  hl.exec_cmd("~/.config/hypr/scripts/update_notifier.sh")
  hl.exec_cmd("sleep 3 && ~/.config/hypr/scripts/restore-workspaces.sh")

  -- ─── Desktop Services ───────────────────────────
  hl.exec_cmd("nm-applet")
  hl.exec_cmd("kdeconnectd")
  hl.exec_cmd("pypr")
  -- quickshell (ii) replaced by waybar to reclaim ~30% idle GPU on triple-4K.
  -- To revert: re-enable the service and remove the waybar line below.
  -- hl.exec_cmd("systemctl --user start quickshell-ii.service")
  hl.exec_cmd("~/.config/hypr/hyprland/scripts/start_geoclue_agent.sh")
  hl.exec_cmd("sleep 1 && ~/.config/waybar/scripts/wallpaper.sh --restore")

  -- ─── Auth & Keyring ─────────────────────────────
  hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
  hl.exec_cmd("dbus-update-activation-environment --all")
  hl.exec_cmd("sleep 1 && dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")

  -- ─── Audio & Clipboard ──────────────────────────
  hl.exec_cmd("easyeffects --hide-window --service-mode")
  -- Android notification ding on every notification
  hl.exec_cmd("~/.config/hypr/scripts/osrs-notify-sound.sh")
  hl.exec_cmd("wl-paste --type text --watch bash -c 'cliphist store && qs -c $qsConfig ipc call cliphistService update'")
  hl.exec_cmd("wl-paste --type image --watch bash -c 'cliphist store && qs -c $qsConfig ipc call cliphistService update'")

  -- ─── Apps ───────────────────────────────────────
  hl.exec_cmd("sleep 1 && uwsm app -- thunderbird")
  hl.exec_cmd("sleep 2 && uwsm app -- discord")
  hl.exec_cmd("sleep 4 && uwsm app -- steam")
  hl.exec_cmd("uwsm app -- openrgb --start-minimized --profile 'Default'")

  -- ─── Theme & Cursor ─────────────────────────────
  hl.exec_cmd("hyprctl setcursor oreo_red_cursors 24")
  hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme oreo_red_cursors")
  hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-size 24")
  hl.exec_cmd("mkdir -p ~/.icons/default && printf '[Icon Theme]\\nInherits=oreo_red_cursors\\n' > ~/.icons/default/index.theme")
end)

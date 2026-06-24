#!/usr/bin/env bash
# hyprlock-watchdog: respawn hyprlock if the session is locked but the lock
# client has died. Without this, an hyprlock crash (e.g. EGL_BAD_ALLOC on a
# multi-4K setup) leaves Hyprland locked with no unlock UI, stranding you in a
# TTY. Relies on misc:allow_session_lock_restore = true so a fresh hyprlock can
# re-attach to the existing session lock.
set -u

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

resolve_env() {
    # Newest Hyprland instance, if HYPRLAND_INSTANCE_SIGNATURE isn't inherited.
    if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        local d
        d=$(ls -1dt "$XDG_RUNTIME_DIR"/hypr/*/ 2>/dev/null | head -1)
        [ -n "$d" ] && export HYPRLAND_INSTANCE_SIGNATURE="$(basename "$d")"
    fi
    # Wayland socket, if not inherited.
    if [ -z "${WAYLAND_DISPLAY:-}" ]; then
        local w
        w=$(ls -1 "$XDG_RUNTIME_DIR"/wayland-[0-9]* 2>/dev/null \
            | grep -vE '\.(lock|sock)$' | head -1)
        [ -n "$w" ] && export WAYLAND_DISPLAY="$(basename "$w")"
    fi
}

is_locked()   { hyprctl locked 2>/dev/null | grep -q true; }
lock_alive()  { pidof hyprlock >/dev/null 2>&1; }

while true; do
    resolve_env
    if is_locked && ! lock_alive; then
        # Re-confirm after a beat to avoid racing a legitimate unlock
        # (hyprlock exits right as it clears the lock).
        sleep 1
        if is_locked && ! lock_alive; then
            setsid hyprlock >/tmp/hyprlock-watchdog.log 2>&1 &
            # Give it time to bind before polling again.
            sleep 3
        fi
    fi
    sleep 2
done

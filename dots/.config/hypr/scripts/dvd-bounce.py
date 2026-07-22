#!/usr/bin/env python3
import subprocess, json, time, os, signal, sys, socket as sock

PIDFILE_DIR = "/tmp/hypr-dvd"
SPEED = 8
TICK = 1 / 60
CHECK_EVERY = 15  # ticks between "is the window still floating?" polls


def _socket_path():
    sig = os.environ["HYPRLAND_INSTANCE_SIGNATURE"]
    return f"{os.environ['XDG_RUNTIME_DIR']}/hypr/{sig}/.socket.sock"


def send(cmd):
    with sock.socket(sock.AF_UNIX, sock.SOCK_STREAM) as s:
        s.connect(_socket_path())
        s.sendall(cmd.encode())
        return s.recv(256).decode().strip()


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True)


def get_active_window():
    return json.loads(run(["hyprctl", "activewindow", "-j"]).stdout)


def get_client(addr):
    clients = json.loads(run(["hyprctl", "clients", "-j"]).stdout)
    return next((c for c in clients if c["address"] == addr), None)


def pid_alive(pid):
    # pid <= 1 must never reach os.kill: 0 signals our whole process group and
    # -1 signals every process we own.
    if pid <= 1:
        return False
    try:
        os.kill(pid, 0)
    except (ProcessLookupError, ValueError):
        return False
    except PermissionError:
        return True
    return True


def get_monitor(name):
    monitors = json.loads(run(["hyprctl", "monitors", "-j"]).stdout)
    return next((m for m in monitors if m["name"] == name), monitors[0])


def move_window(addr, x, y):
    send(f'dispatch hl.dsp.window.move({{x={int(x)}, y={int(y)}, window="address:{addr}"}})')


def float_window(addr):
    send(f'dispatch hl.dsp.window.float({{action="set", window="address:{addr}"}})')


def main():
    win = get_active_window()
    if not win or not win.get("address"):
        return

    addr = win["address"]
    pidfile = f"{PIDFILE_DIR}/{addr}.pid"
    os.makedirs(PIDFILE_DIR, exist_ok=True)

    if os.path.exists(pidfile):
        try:
            with open(pidfile) as f:
                pid = int(f.read().strip())
        except (ValueError, OSError):
            pid = -1
        try:
            os.remove(pidfile)
        except FileNotFoundError:
            pass
        # A live bouncer means this press is the "off" half of the toggle.
        # A stale pidfile must not swallow the press; fall through and start.
        if pid_alive(pid):
            try:
                os.kill(pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            return

    with open(pidfile, "w") as f:
        f.write(str(os.getpid()))

    def cleanup(sig=None, frame=None):
        try:
            os.remove(pidfile)
        except FileNotFoundError:
            pass
        sys.exit(0)

    signal.signal(signal.SIGTERM, cleanup)
    signal.signal(signal.SIGINT, cleanup)

    float_window(addr)
    time.sleep(0.15)

    client = get_client(addr)
    if not client:
        cleanup()
        return

    w, h = client["size"]
    monitors = json.loads(run(["hyprctl", "monitors", "-j"]).stdout)

    min_x = min(m["x"] for m in monitors)
    min_y = min(m["y"] for m in monitors)
    max_x = max(m["x"] + int(m["width"] / m.get("scale", 1.0)) for m in monitors)
    max_y = max(m["y"] + int(m["height"] / m.get("scale", 1.0)) for m in monitors)

    mx, my = min_x, min_y
    mw = max_x - min_x
    mh = max_y - min_y

    x = float(mx + (mw - w) / 2)
    y = float(my + (mh - h) / 2)
    dx, dy = float(SPEED), float(SPEED)

    max_x = mx + mw - w
    max_y = my + mh - h

    tick = 0
    try:
        while True:
            x += dx
            y += dy

            if x <= mx:
                x = float(mx)
                dx = abs(dx)
            elif x >= max_x:
                x = float(max_x)
                dx = -abs(dx)

            if y <= my:
                y = float(my)
                dy = abs(dy)
            elif y >= max_y:
                y = float(max_y)
                dy = -abs(dy)

            move_window(addr, x, y)
            time.sleep(TICK)

            tick += 1
            if tick % CHECK_EVERY == 0:
                client = get_client(addr)
                if not client or not client.get("floating"):
                    break
    finally:
        cleanup()


if __name__ == "__main__":
    main()

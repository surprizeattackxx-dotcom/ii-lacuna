#!/usr/bin/env python3
"""Register game windows with Feral gamemoded automatically.

Nothing on this box ever asked gamemoded to engage. pyprland's [gamemode]
plugin only toggles Hyprland eye candy (animations/blur/shadows/gaps/rounding)
and never talks to gamemoded; the noctalia game-mode plugin is the same kind of
thing. The only real requesters were per-game `gamemoderun %command%` launch
options, which have to be re-applied every time a new game is installed.

This watcher closes that gap. It listens on Hyprland's event socket and, when a
game window opens, registers that window's PID with gamemoded over D-Bus
(RegisterGameByPID). When the window closes it unregisters. gamemoded then does
its normal job: CPU governor -> performance, and the /etc/gamemode.ini custom
scripts flip sched-ext bpfland into Gaming mode.

"Is it a game" is answered by Hyprland's own contentType == "game", which is set
by the rules in ~/.config/hypr/config/windowrules.lua for `^(steam_app.*|gamescope)$`
and the RS3 classes. Reusing that tag rather than keeping a second list here means
this never drifts out of sync with the window rules Donnie already maintains, and
new Steam installs are covered with no changes. EXTRA_CLASS_PATTERNS below is the
escape hatch for games that don't get tagged (some native Linux titles keep their
own WM_CLASS instead of steam_app_*).

Safe to run alongside the `gamemoderun %command%` launch options: gamemoded
refcounts its clients, and a duplicate registration is logged and ignored here.

It also hands the GPU back before a game starts. Ollama is no longer pinned to
CPU, and offloading a 30B MoE to the 4070 is worth 2.2x throughput at lower power
(Local Inference Benchmarks, Result 8) - but it parks ~10.8 GB in 12 GB of VRAM,
which is the whole card. Ollama sizes its offload to *free* VRAM at load time, so
"game first, then inference" already degrades gracefully on its own. The case that
does not self-solve is the reverse: a model already resident when a game launches.
That is exactly the moment this watcher fires, so RELEASE_GPU_ON_GAME below unloads
any GPU-resident model when a game window opens. Models still on CPU are left alone
- evicting those would slow Jarvis down for no gain.
"""

import json
import os
import re
import signal
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request

# Classes that should count as games but don't get contentType=game from the
# window rules. Add regexes here as they come up.
EXTRA_CLASS_PATTERNS = [
    # r"^some_native_game$",
]

# Hand the GPU back to games: unload any GPU-resident Ollama model when a game
# window opens. Set False to disable without removing the code.
RELEASE_GPU_ON_GAME = True
OLLAMA_HOST = os.environ.get("OLLAMA_HOST", "http://127.0.0.1:11434")
OLLAMA_TIMEOUT = 3  # seconds; must stay short - this runs on the game-launch path

DBUS_DEST = "com.feralinteractive.GameMode"
DBUS_PATH = "/com/feralinteractive/GameMode"
DBUS_IFACE = "com.feralinteractive.GameMode"

# Window rules are applied when the window maps, which can land just after the
# openwindow event. Re-check a few times before deciding it isn't a game.
LOOKUP_RETRIES = 6
LOOKUP_DELAY = 0.25

registered = {}  # hyprland address (no 0x) -> pid
_extra = [re.compile(p) for p in EXTRA_CLASS_PATTERNS]


def log(msg):
    print(f"gamemode-watcher: {msg}", flush=True)


def event_socket_path():
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    xdg = os.environ.get("XDG_RUNTIME_DIR")
    if not sig or not xdg:
        log("ERROR: HYPRLAND_INSTANCE_SIGNATURE / XDG_RUNTIME_DIR unset - not in a Hyprland session")
        sys.exit(1)
    return f"{xdg}/hypr/{sig}/.socket2.sock"


def hypr_clients():
    try:
        out = subprocess.run(
            ["hyprctl", "clients", "-j"], capture_output=True, text=True, timeout=5
        )
        if out.returncode != 0:
            return []
        return json.loads(out.stdout)
    except (subprocess.TimeoutExpired, json.JSONDecodeError, OSError) as e:
        log(f"hyprctl clients failed: {e}")
        return []


def is_game(client):
    if client.get("contentType") == "game":
        return True
    cls = client.get("class") or ""
    return any(p.search(cls) for p in _extra)


def dbus_call(method, pid):
    """Call gamemoded. Returns True on success. Never raises."""
    try:
        out = subprocess.run(
            ["busctl", "--user", "call", DBUS_DEST, DBUS_PATH, DBUS_IFACE,
             method, "ii", str(os.getpid()), str(pid)],
            capture_output=True, text=True, timeout=10,
        )
    except (subprocess.TimeoutExpired, OSError) as e:
        log(f"{method} for pid {pid} failed to run: {e}")
        return False

    if out.returncode != 0:
        # gamemoded not running, or the pid already registered via gamemoderun.
        log(f"{method} for pid {pid} rejected: {out.stderr.strip() or out.stdout.strip()}")
        return False
    return True


def register(addr, client):
    pid = client.get("pid")
    if not pid or pid <= 0 or addr in registered:
        return
    if dbus_call("RegisterGameByPID", pid):
        registered[addr] = pid
        log(f"registered pid {pid} ({client.get('class')!r}) - gamemode requested")


def unregister(addr):
    pid = registered.pop(addr, None)
    if pid is None:
        return
    if dbus_call("UnregisterGameByPID", pid):
        log(f"unregistered pid {pid} - gamemode released")


def handle_open(addr):
    """Look the window up and register it if it's a game.

    Retries because window rules (and therefore contentType) may not be applied
    at the instant the openwindow event fires.
    """
    for _ in range(LOOKUP_RETRIES):
        for c in hypr_clients():
            if str(c.get("address", "")).removeprefix("0x") != addr:
                continue
            if is_game(c):
                register(addr, c)
                return
            break  # found the window, not a game (yet)
        time.sleep(LOOKUP_DELAY)


def scan_existing():
    """Catch games already running when the watcher starts."""
    for c in hypr_clients():
        if is_game(c):
            register(str(c.get("address", "")).removeprefix("0x"), c)


def cleanup(signum=None, frame=None):
    for addr in list(registered):
        unregister(addr)
    log("exiting")
    sys.exit(0)


def main():
    signal.signal(signal.SIGTERM, cleanup)
    signal.signal(signal.SIGINT, cleanup)

    path = event_socket_path()
    log(f"watching {path}")
    scan_existing()

    backoff = 1
    while True:
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
                s.connect(path)
                backoff = 1
                buf = ""
                while True:
                    data = s.recv(4096)
                    if not data:
                        raise ConnectionError("hyprland closed the event socket")
                    buf += data.decode("utf-8", "replace")
                    while "\n" in buf:
                        line, buf = buf.split("\n", 1)
                        if ">>" not in line:
                            continue
                        event, _, payload = line.partition(">>")
                        if event == "openwindow":
                            handle_open(payload.split(",", 1)[0])
                        elif event == "closewindow":
                            unregister(payload.strip())
        except (ConnectionError, FileNotFoundError, OSError) as e:
            # Hyprland restarted or the socket went away. Drop every
            # registration so a dead pid can't hold gamemode on forever.
            for addr in list(registered):
                registered.pop(addr, None)
            log(f"event socket lost ({e}); retrying in {backoff}s")
            time.sleep(backoff)
            backoff = min(backoff * 2, 30)
            path = event_socket_path()


if __name__ == "__main__":
    main()

"""Kitty watcher — streams a particle-burst event to the Quickshell renderer
for each detected single-character-typed or backspace event, while a kitty
window is focused. See docs/superpowers/specs/2026-07-26-kitty-typing-particles-design.md.

Registered via `watcher particles_watcher.py` in kitty.conf. Kitty loads this
file with runpy and looks up on_focus_change/on_resize/on_close by name — see
kitty/launch.py:load_watch_modules in the kitty source for the loading contract.
"""
import os
import socket
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from particles_detect import detect_event, parse_snapshot  # noqa: E402

from kitty.fast_data_types import add_timer, remove_timer  # type: ignore  # noqa: E402

POLL_INTERVAL = 0.02  # seconds, ~50Hz
SOCKET_PATH = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "particles.sock")

_timers: dict[int, int] = {}  # window.id -> timer_id
_sock: "socket.socket | None" = None


def _get_socket() -> "socket.socket | None":
    global _sock
    if _sock is not None:
        return _sock
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(SOCKET_PATH)
        s.setblocking(False)
        _sock = s
    except OSError:
        _sock = None
    return _sock


def _send(px: float, py: float, kind: str) -> None:
    global _sock
    sock = _get_socket()
    if sock is None:
        return
    try:
        sock.sendall(f"{px},{py},{kind}\n".encode())
    except OSError:
        _sock = None


def _make_poller(window):
    state = {"snapshot": None}

    def _poll(timer_id):
        try:
            text = window.as_text(add_cursor=True)
            snap = parse_snapshot(text, window.screen.columns)
            if snap is None:
                return
            event = detect_event(state["snapshot"], snap)
            state["snapshot"] = snap
            if event is not None:
                row, col, kind = event
                geo = window.geometry
                cell_w = (geo.right - geo.left) / geo.xnum
                cell_h = (geo.bottom - geo.top) / geo.ynum
                px = geo.left + (col + 0.5) * cell_w
                py = geo.top + (row + 0.5) * cell_h
                _send(px, py, kind)
        except Exception:
            return

    return _poll


def _ensure_timer(window) -> None:
    if window.id in _timers:
        return
    timer_id = add_timer(_make_poller(window), POLL_INTERVAL, True)
    _timers[window.id] = timer_id


def on_focus_change(boss, window, data):
    if data.get("focused"):
        _ensure_timer(window)
    else:
        timer_id = _timers.pop(window.id, None)
        if timer_id is not None:
            remove_timer(timer_id)


def on_resize(boss, window, data):
    # Kitty's own on_focus_change hook only fires when its internal focus
    # flag actually flips (kitty/window.py:focus_changed), which depends on
    # an explicit OS/compositor "keyboard entered this window" event timing
    # out cleanly. A just-created window doesn't always get that first
    # transition reported before you start typing. on_resize is a reliable
    # fallback: every new window forces one resize/layout pass on creation
    # (kitty/window.py sets needs_layout = True in __init__), so this always
    # fires at least once regardless of the focus-event race above.
    _ensure_timer(window)


def on_close(boss, window, data):
    timer_id = _timers.pop(window.id, None)
    if timer_id is not None:
        remove_timer(timer_id)

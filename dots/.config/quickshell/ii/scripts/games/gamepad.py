#!/usr/bin/env python3
import struct, sys, glob, time, os, select

EVENT_SIZE = 8
JS_EVENT_BUTTON = 0x01
JS_EVENT_AXIS = 0x02
JS_EVENT_INIT = 0x80
DEAD = 18000
INITIAL_DELAY = 0.35   # hold this long before auto-repeat kicks in
REPEAT = 0.07          # repeat interval while held

BUTTONS = {
    0: 'a', 1: 'b', 2: 'x', 3: 'y',
    4: 'lb', 5: 'rb', 6: 'back', 7: 'start',
}


def find_js():
    js = sorted(glob.glob('/dev/input/js*'))
    return js[0] if js else None


def emit_dir(group, d):
    if group == 'h':
        print('right' if d == 1 else 'left', flush=True)
    else:
        print('down' if d == 1 else 'up', flush=True)


def main():
    path = None
    for _ in range(60):
        path = find_js()
        if path:
            break
        time.sleep(1)
    if not path:
        return
    try:
        fd = os.open(path, os.O_RDONLY)
    except OSError:
        return

    held = {'h': 0, 'v': 0}      # currently-held direction per axis group
    next_t = {'h': 0.0, 'v': 0.0}  # when to fire the next repeat

    while True:
        now = time.monotonic()
        waits = [next_t[g] - now for g in ('h', 'v') if held[g] != 0]
        timeout = max(0.0, min(waits)) if waits else None

        r, _, _ = select.select([fd], [], [], timeout)

        if r:
            data = os.read(fd, EVENT_SIZE)
            if not data or len(data) < EVENT_SIZE:
                break
            _t, value, etype, number = struct.unpack('IhBB', data)
            if etype & JS_EVENT_INIT:
                continue
            etype &= ~JS_EVENT_INIT

            if etype == JS_EVENT_BUTTON:
                if value == 1 and number in BUTTONS:
                    print(BUTTONS[number], flush=True)
            elif etype == JS_EVENT_AXIS:
                group = 'h' if number in (0, 6) else ('v' if number in (1, 7) else None)
                if group is None:
                    continue
                d = 1 if value > DEAD else (-1 if value < -DEAD else 0)
                if d != held[group]:
                    held[group] = d
                    if d != 0:
                        emit_dir(group, d)
                        next_t[group] = time.monotonic() + INITIAL_DELAY
        else:
            now = time.monotonic()
            for g in ('h', 'v'):
                if held[g] != 0 and now >= next_t[g]:
                    emit_dir(g, held[g])
                    next_t[g] = now + REPEAT


if __name__ == '__main__':
    try:
        main()
    except (BrokenPipeError, KeyboardInterrupt):
        pass

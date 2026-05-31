#!/usr/bin/env python3
import struct, sys, glob, time

EVENT_SIZE = 8
JS_EVENT_BUTTON = 0x01
JS_EVENT_AXIS = 0x02
JS_EVENT_INIT = 0x80
DEAD = 18000

# Xbox-style button map (Linux xpad / joystick API)
BUTTONS = {
    0: 'a', 1: 'b', 2: 'x', 3: 'y',
    4: 'lb', 5: 'rb', 6: 'back', 7: 'start',
}


def find_js():
    js = sorted(glob.glob('/dev/input/js*'))
    return js[0] if js else None


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
        f = open(path, 'rb')
    except OSError:
        return

    axis_dir = {}
    while True:
        data = f.read(EVENT_SIZE)
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
            if number in (0, 6):       # left stick X / dpad X
                d = 1 if value > DEAD else (-1 if value < -DEAD else 0)
                if d != axis_dir.get(number, 0):
                    axis_dir[number] = d
                    if d == 1: print('right', flush=True)
                    elif d == -1: print('left', flush=True)
            elif number in (1, 7):     # left stick Y / dpad Y
                d = 1 if value > DEAD else (-1 if value < -DEAD else 0)
                if d != axis_dir.get(number, 0):
                    axis_dir[number] = d
                    if d == 1: print('down', flush=True)
                    elif d == -1: print('up', flush=True)


if __name__ == '__main__':
    try:
        main()
    except (BrokenPipeError, KeyboardInterrupt):
        pass

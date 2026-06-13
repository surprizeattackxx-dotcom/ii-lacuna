#!/usr/bin/env python3
import json
import os
import socket
import subprocess
import sys
import time

ADDR = os.environ.get("BUDS_MAC", "F4:2B:8C:D4:53:2E")
CACHE = os.path.expanduser("~/.cache/galaxybuds_channel")

BOM = 0xFD
EOM = 0xDD

# message ids
EXTENDED_STATUS_UPDATED = 97
STATUS_UPDATED = 96
SET_NOISE_REDUCTION = 152      # legacy boolean ANC (Buds Live/+)
NOISE_CONTROLS = 120           # 3-way Off/ANC/Ambient (Buds Pro/2/FE)
EQUALIZER = 134
LOCK_TOUCHPAD = 144
FIND_MY_EARBUDS_START = 160
FIND_MY_EARBUDS_STOP = 161

NOISE = {"off": 0, "anc": 1, "ambient": 2}
NOISE_NAME = {0: "off", 1: "anc", 2: "ambient"}
EQ = {"normal": 0, "bass": 1, "soft": 2, "dynamic": 3, "clear": 4, "treble": 5}
EQ_NAME = {0: "normal", 1: "bass", 2: "soft", 3: "dynamic", 4: "clear", 5: "treble"}


def crc16_xmodem(data):
    crc = 0
    for b in data:
        crc ^= b << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) & 0xFFFF if crc & 0x8000 else (crc << 1) & 0xFFFF
    return crc


def build(msg_id, payload=b""):
    body = bytes([msg_id]) + bytes(payload)
    crc = crc16_xmodem(body)
    seg = body + bytes([crc & 0xFF, (crc >> 8) & 0xFF])
    header = len(seg) & 0x3FF
    return bytes([BOM, header & 0xFF, (header >> 8) & 0xFF]) + seg + bytes([EOM])


def parse_frames(buf):
    frames = []
    i = 0
    while i < len(buf):
        if buf[i] != BOM:
            i += 1
            continue
        if i + 3 > len(buf):
            break
        seg_len = (buf[i + 1] | (buf[i + 2] << 8)) & 0x3FF
        end = i + 3 + seg_len  # index of EOM
        if end >= len(buf):
            break
        if buf[end] != EOM:
            i += 1
            continue
        msg_id = buf[i + 3]
        payload = buf[i + 4: i + 1 + seg_len]  # strip id + 2 crc
        frames.append((msg_id, payload))
        i = end + 1
    return frames


def is_connected():
    try:
        out = subprocess.run(["bluetoothctl", "info", ADDR], capture_output=True, text=True, timeout=3).stdout
        return "Connected: yes" in out
    except Exception:
        return False


def open_channel(ch, timeout=2.0):
    s = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_STREAM, socket.BTPROTO_RFCOMM)
    s.settimeout(timeout)
    s.connect((ADDR, ch))
    return s


def detect_channel():
    if os.path.exists(CACHE):
        try:
            ch = int(open(CACHE).read().strip())
            s = open_channel(ch, 2.0)
            return s, ch, b""
        except Exception:
            pass
    for ch in range(1, 31):
        try:
            s = open_channel(ch, 1.2)
        except OSError:
            continue
        try:
            s.settimeout(1.5)
            data = s.recv(1024)
            if data and BOM in data and any(
                mid in (EXTENDED_STATUS_UPDATED, STATUS_UPDATED, 99, 98)
                for mid, _ in parse_frames(data)
            ):
                with open(CACHE, "w") as f:
                    f.write(str(ch))
                return s, ch, data
        except OSError:
            pass
        s.close()
    raise SystemExit("could not find Galaxy Buds SPP channel")


def read_status(timeout=3.0):
    if not is_connected():
        return {"connected": False}
    s, ch, primer = detect_channel()
    buf = bytearray(primer)
    s.settimeout(1.2)
    deadline = time.time() + timeout
    ext = None
    while time.time() < deadline:
        for mid, pl in parse_frames(buf):
            if mid == EXTENDED_STATUS_UPDATED and len(pl) >= 13:
                ext = pl
        if ext is not None:
            break
        try:
            chunk = s.recv(1024)
            if not chunk:
                break
            buf += chunk
        except OSError:
            break
    s.close()
    if ext is None:
        return {"connected": True, "channel": ch, "parsed": False}

    def sb(b):  # signed battery
        return b - 256 if b > 127 else b

    return {
        "connected": True,
        "channel": ch,
        "parsed": True,
        "battery_left": sb(ext[2]),
        "battery_right": sb(ext[3]),
        "battery_case": sb(ext[7]),
        "equalizer": EQ_NAME.get(ext[9], "unknown"),
        "equalizer_id": ext[9],
        "noise": NOISE_NAME.get(ext[12], "unknown"),
        "noise_id": ext[12],
        "touch_locked": not bool(ext[10] & 0x80),
        "wearing_left": (ext[6] & 0x0F) == 1,
        "wearing_right": ((ext[6] >> 4) & 0x0F) == 1,
    }


def send(msg_id, payload=b""):
    if not is_connected():
        return
    s, ch, _ = detect_channel()
    s.send(build(msg_id, payload))
    time.sleep(0.2)
    s.close()


def main():
    if len(sys.argv) < 2:
        print("usage: buds.py status|noise <off|anc|ambient>|eq <preset>|lock <on|off>|find <on|off>")
        return 1
    cmd = sys.argv[1]
    if cmd == "status":
        print(json.dumps(read_status()))
    elif cmd == "noise":
        send(NOISE_CONTROLS, [NOISE[sys.argv[2]]])
    elif cmd == "eq":
        send(EQUALIZER, [EQ[sys.argv[2]]])
    elif cmd == "lock":
        # FE byte = "touch controls enabled": 1 = unlocked, 0 = locked
        send(LOCK_TOUCHPAD, [0 if sys.argv[2] == "on" else 1])
    elif cmd == "find":
        send(FIND_MY_EARBUDS_START if sys.argv[2] == "on" else FIND_MY_EARBUDS_STOP)
    else:
        print("unknown command", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

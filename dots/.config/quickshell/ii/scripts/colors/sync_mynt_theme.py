#!/usr/bin/env python3
"""Sync the MYNT new-tab extension's colors with the shell theme.

Usage: sync_mynt_theme.py [colors.json]

Sets MYNT's customThemeColor to the theme primary and preferredTheme to the
shell color mode via CDP localStorage. Exits silently if Chrome/CDP is down.
"""
import asyncio
import json
import os
import sys
import urllib.request

MYNT_ID = "jjpokbgpiljgndebfoljdeihhkpcpfgl"
STATE = os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state"))
CONFIG = os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))


async def main(colors_path: str) -> None:
    try:
        with open(colors_path) as f:
            colors = json.load(f)
        primary = colors.get("primary", "#89b4fa")
    except Exception:
        return

    mode = "dark"
    try:
        with open(f"{CONFIG}/illogical-impulse/config.json") as f:
            mode = json.load(f)["appearance"].get("colorMode", "dark")
    except Exception:
        pass

    try:
        with urllib.request.urlopen("http://localhost:9222/json/version", timeout=2) as r:
            ws_url = json.loads(r.read())["webSocketDebuggerUrl"]
    except Exception:
        return

    try:
        import websockets
        async with websockets.connect(ws_url, open_timeout=3) as ws:
            mid = 0

            async def call(method, params=None, session=None):
                nonlocal mid
                mid += 1
                msg = {"id": mid, "method": method, "params": params or {}}
                if session:
                    msg["sessionId"] = session
                await ws.send(json.dumps(msg))
                my = mid
                while True:
                    resp = json.loads(await asyncio.wait_for(ws.recv(), timeout=10))
                    if resp.get("id") == my:
                        return resp

            t = await call("Target.createTarget", {
                "url": f"chrome-extension://{MYNT_ID}/index.html",
                "background": True,
            })
            tid = t["result"]["targetId"]
            s = await call("Target.attachToTarget", {"targetId": tid, "flatten": True})
            sid = s["result"]["sessionId"]
            await asyncio.sleep(0.8)
            js = (
                f"localStorage.setItem('customThemeColor', '{primary}');"
                f"localStorage.removeItem('selectedTheme');"
                f"localStorage.setItem('preferredTheme', '{mode}');"
            )
            await call("Runtime.evaluate", {"expression": js}, session=sid)
            await call("Target.closeTarget", {"targetId": tid})
    except Exception:
        return


if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else f"{STATE}/quickshell/user/generated/colors.json"
    asyncio.run(main(path))

#!/usr/bin/env python3
"""Seed Chrome's full GM3 palette (side panel, menus, bubbles) from the theme.

Usage: chrome_seed_color.py [colors.json]

Writes BrowserThemeColor to the managed policy file (must be pre-created and
owned by the user), then triggers a live policy reload via CDP chrome://policy.
Exits silently if the policy file isn't writable or CDP is down.
"""
import asyncio
import json
import os
import sys

POLICY_FILE = "/etc/opt/chrome/policies/managed/ii-theme-color.json"
STATE = os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state"))


async def reload_policies() -> None:
    import urllib.request
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

            t = await call("Target.createTarget", {"url": "chrome://policy", "background": True})
            tid = t["result"]["targetId"]
            s = await call("Target.attachToTarget", {"targetId": tid, "flatten": True})
            sid = s["result"]["sessionId"]
            await asyncio.sleep(1)
            # the reload button lives in light DOM on some versions, shadow DOM on others
            js = """(() => {
                const direct = document.querySelector('#reload-policies');
                if (direct) { direct.click(); return 'clicked-direct'; }
                for (const host of document.querySelectorAll('*')) {
                    const b = host.shadowRoot?.querySelector?.('#reload-policies');
                    if (b) { b.click(); return 'clicked-shadow'; }
                }
                return 'not-found';
            })()"""
            res = await call("Runtime.evaluate", {"expression": js, "returnByValue": True}, session=sid)
            print(res["result"]["result"].get("value"))
            await asyncio.sleep(1)
            await call("Target.closeTarget", {"targetId": tid})
    except Exception:
        return


def main() -> None:
    colors_path = sys.argv[1] if len(sys.argv) > 1 else f"{STATE}/quickshell/user/generated/colors.json"
    try:
        with open(colors_path) as f:
            primary = json.load(f).get("primary")
    except Exception:
        return
    if not primary:
        return
    try:
        with open(POLICY_FILE, "w") as f:
            json.dump({"BrowserThemeColor": primary}, f)
    except OSError:
        return
    asyncio.run(reload_policies())


if __name__ == "__main__":
    main()

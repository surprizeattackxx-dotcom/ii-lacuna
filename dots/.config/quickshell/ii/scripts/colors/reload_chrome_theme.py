#!/usr/bin/env python3
"""Reload ii-lacuna Chrome theme via Chrome DevTools Protocol.

Usage: reload_chrome_theme.py <theme_dir>

Exits silently if Chrome is not running or CDP is unavailable.
Requires: websockets (pip install websockets)
"""
import asyncio
import json
import sys
import urllib.request
from pathlib import Path


async def reload(theme_dir: str) -> None:
    import websockets

    # Get CDP WebSocket URL from Chrome's debug endpoint
    try:
        with urllib.request.urlopen("http://localhost:9222/json/version", timeout=2) as r:
            ws_url = json.loads(r.read())["webSocketDebuggerUrl"]
    except Exception:
        return  # Chrome not running or --remote-debugging-port not set

    try:
        async with websockets.connect(ws_url, open_timeout=3) as ws:
            await ws.send(json.dumps({
                "id": 1,
                "method": "Extensions.loadUnpacked",
                "params": {"path": str(Path(theme_dir).resolve())},
            }))
            await asyncio.wait_for(ws.recv(), timeout=3)
    except Exception:
        return  # Chrome closed, timed out, or CDP rejected — ignore


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <theme_dir>", file=sys.stderr)
        sys.exit(1)
    asyncio.run(reload(sys.argv[1]))

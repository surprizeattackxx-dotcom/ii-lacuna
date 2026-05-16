#!/usr/bin/env python3
import asyncio
import json
import urllib.request
import websockets
from pathlib import Path
import sys

async def debug_reload(theme_dir: str):
    print(f"DEBUG: Starting reload for {theme_dir}")
    try:
        with urllib.request.urlopen("http://localhost:9222/json/version", timeout=5) as r:
            data = json.loads(r.read())
            print(f"DEBUG: Got response: {data}")
            ws_url = data["webSocketDebuggerUrl"]
    except Exception as e:
        print(f"DEBUG: Error connecting to CDP: {e}")
        return

    try:
        print(f"DEBUG: Connecting to {ws_url}")
        async with websockets.connect(ws_url, open_timeout=5) as ws:
            payload = {
                "id": 1,
                "method": "Extensions.loadUnpacked",
                "params": {"path": str(Path(theme_dir).resolve())},
            }
            print(f"DEBUG: Sending payload: {payload}")
            await ws.send(json.dumps(payload))
            response = await asyncio.wait_for(ws.recv(), timeout=5)
            print(f"DEBUG: Got response: {response}")
    except Exception as e:
        print(f"DEBUG: Error during WebSocket comms: {e}")

if __name__ == "__main__":
    asyncio.run(debug_reload(sys.argv[1]))

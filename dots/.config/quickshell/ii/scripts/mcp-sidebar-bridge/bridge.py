#!/usr/bin/env python3
"""Minimal HTTP bridge that exposes the user's stdio MCP servers to the Quickshell
AI sidebar (Aria). Speaks the loose contract Ai.qml expects:

  GET  /health             -> 200
  GET  /catalog            -> { server: [ {name, description}, ... ], ... }
  POST /call {server,tool,arguments} -> tool result text

Server definitions are read from opencode.json's `mcp` section so there is a
single source of truth for the user's MCP servers.
"""
import asyncio
import json
import os
import sys

from aiohttp import web
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

CONFIG_PATH = os.path.expanduser("~/.config/opencode/opencode.json")
HOST = os.environ.get("MCP_BRIDGE_HOST", "127.0.0.1")
PORT = int(os.environ.get("MCP_BRIDGE_PORT", "3847"))
CONNECT_TIMEOUT = 60


def load_servers():
    with open(CONFIG_PATH) as f:
        cfg = json.load(f)
    servers = {}
    for name, c in (cfg.get("mcp") or {}).items():
        if c.get("enabled") is False or c.get("type") != "local":
            continue
        cmd = c.get("command") or []
        if not cmd:
            continue
        env = dict(os.environ)
        env.update(c.get("env") or {})
        params = StdioServerParameters(command=cmd[0], args=cmd[1:], env=env)
        servers[name] = Server(name, params)
    return servers


class Server:
    def __init__(self, name, params):
        self.name = name
        self.params = params
        self.session = None
        self.tools = []
        self.error = None
        self.lock = asyncio.Lock()

    async def connect(self, stack):
        async with self.lock:
            if self.session or self.error:
                return
            try:
                read, write = await stack.enter_async_context(stdio_client(self.params))
                session = await stack.enter_async_context(ClientSession(read, write))
                await asyncio.wait_for(session.initialize(), CONNECT_TIMEOUT)
                listed = await asyncio.wait_for(session.list_tools(), CONNECT_TIMEOUT)
                self.session = session
                self.tools = listed.tools
            except Exception as e:  # keep the bridge alive even if one server is broken
                self.error = f"{type(e).__name__}: {e}"

    async def call(self, tool, arguments):
        if not self.session:
            return f"[{self.name}] not connected: {self.error or 'unknown error'}"
        async with self.lock:
            res = await asyncio.wait_for(self.session.call_tool(tool, arguments or {}), CONNECT_TIMEOUT)
        out = []
        for part in res.content:
            if getattr(part, "type", None) == "text":
                out.append(part.text)
            else:
                out.append(json.dumps(part.model_dump() if hasattr(part, "model_dump") else str(part)))
        text = "\n".join(out).strip()
        if getattr(res, "isError", False):
            return f"[{self.name}/{tool}] error: {text}"
        return text or "(no output)"


def make_app(servers, stack):
    routes = web.RouteTableDef()

    @routes.get("/health")
    async def health(_req):
        return web.json_response({"ok": True, "servers": list(servers)})

    @routes.get("/catalog")
    async def catalog(_req):
        await asyncio.gather(*(s.connect(stack) for s in servers.values()))
        out = {}
        for name, s in servers.items():
            if s.error:
                out[name] = {"error": s.error}
            else:
                out[name] = [
                    {"name": t.name, "description": (t.description or "").strip()}
                    for t in s.tools
                ]
        return web.json_response(out)

    @routes.post("/call")
    async def call(req):
        body = await req.json()
        name = body.get("server", "")
        tool = body.get("tool", "")
        args = body.get("arguments") or {}
        s = servers.get(name)
        if not s:
            return web.Response(text=f"Unknown server '{name}'. Available: {', '.join(servers)}", status=404)
        await s.connect(stack)
        try:
            return web.Response(text=await s.call(tool, args))
        except Exception as e:
            return web.Response(text=f"[{name}/{tool}] {type(e).__name__}: {e}", status=500)

    app = web.Application()
    app.add_routes(routes)
    return app


async def main():
    from contextlib import AsyncExitStack
    servers = load_servers()
    print(f"[mcp-bridge] {len(servers)} servers: {', '.join(servers)}", file=sys.stderr)
    async with AsyncExitStack() as stack:
        app = make_app(servers, stack)
        runner = web.AppRunner(app)
        await runner.setup()
        site = web.TCPSite(runner, HOST, PORT)
        await site.start()
        print(f"[mcp-bridge] listening on http://{HOST}:{PORT}", file=sys.stderr)
        await asyncio.Event().wait()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass

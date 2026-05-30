#!/usr/bin/env bash
# Launch the MCP sidebar bridge. Deps are fetched ephemerally by uv.
exec uv run --no-project --with "mcp>=1.2" --with aiohttp python "$(dirname "$0")/bridge.py"

#!/usr/bin/env bash
# ai-search.sh - Web search via Firecrawl for the sidebar AI
# Usage: ai-search.sh "your search query"

QUERY="$*"
[ -z "$QUERY" ] && { echo "Usage: ai-search.sh <query>"; exit 1; }

KEY="${FIRECRAWL_API_KEY:-}"
KEYFILE="$HOME/.config/illogical-impulse/firecrawl_api_key"
[ -z "$KEY" ] && [ -f "$KEYFILE" ] && KEY="$(tr -d '[:space:]' < "$KEYFILE")"
if [ -z "$KEY" ]; then
    echo "Web search unavailable: no Firecrawl API key. Set FIRECRAWL_API_KEY or write $KEYFILE. Do NOT retry."
    exit 0
fi

BODY=$(QUERY="$QUERY" python3 -c 'import json,os; print(json.dumps({"query": os.environ["QUERY"], "limit": 5}))')
RESULT=$(curl -s --max-time 25 -X POST https://api.firecrawl.dev/v2/search \
    -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" -d "$BODY")

if [ -z "$RESULT" ]; then
    echo "Web search failed: no response from Firecrawl. Do NOT retry — tell the user search is down."
    exit 0
fi

echo "$RESULT" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print("Web search failed: bad response. Do NOT retry."); sys.exit(0)
if not d.get("success"):
    print("Web search error:", d.get("error", "unknown"), "- Do NOT retry."); sys.exit(0)
data = d.get("data", {})
items = data.get("web", []) if isinstance(data, dict) else data
if not items:
    print("No results found. Do NOT retry — tell the user search returned nothing."); sys.exit(0)
for r in items[:5]:
    title = r.get("title") or "No title"
    url = r.get("url", "")
    desc = (r.get("description") or r.get("snippet") or r.get("markdown") or "").strip()
    desc = " ".join(desc.split())[:500]
    print("### " + title)
    if desc:
        print(desc)
    print("Source: " + url)
    print()
'

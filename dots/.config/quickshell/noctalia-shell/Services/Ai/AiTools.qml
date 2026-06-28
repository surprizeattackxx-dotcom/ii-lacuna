pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Tool layer for the AI assistant (Stage 2). Canonical tool definitions +
// per-provider formatting + a sequential shell executor. Tools are self-contained
// and work natively on this Hyprland/Linux desktop.
Singleton {
    id: root

    property var _cb: null

    function shellEsc(s) { return "'" + ("" + s).replace(/'/g, "'\\''") + "'"; }

    // Canonical tool definitions (provider-neutral JSON schema).
    readonly property var defs: [
        {
            name: "run_shell_command",
            description: "Run a bash command on the user's Linux desktop and return its combined stdout/stderr (truncated). Use for system info, file inspection, package queries, etc. Avoid destructive commands unless the user clearly asked.",
            parameters: { type: "object", properties: { command: { type: "string", description: "The bash command to execute." } }, required: ["command"] }
        },
        {
            name: "control_hyprland",
            description: "Run a hyprctl command to inspect or control the Hyprland Wayland compositor (e.g. 'clients -j', 'monitors -j', 'dispatch workspace 2', 'dispatch killactive').",
            parameters: { type: "object", properties: { command: { type: "string", description: "Arguments passed to hyprctl, e.g. 'dispatch workspace 3' or 'activewindow -j'." } }, required: ["command"] }
        },
        {
            name: "control_media",
            description: "Control media playback via playerctl.",
            parameters: { type: "object", properties: { action: { type: "string", description: "One of: play-pause, play, pause, next, previous, stop, status." } }, required: ["action"] }
        },
        {
            name: "list_windows",
            description: "List currently open windows (class and title) across all workspaces.",
            parameters: { type: "object", properties: {}, required: [] }
        },
        {
            name: "get_system_logs",
            description: "Read recent systemd journal logs. Optionally filter by unit.",
            parameters: { type: "object", properties: { unit: { type: "string", description: "Optional systemd unit to filter, e.g. 'NetworkManager'." }, lines: { type: "integer", description: "Number of recent lines (default 50)." } }, required: [] }
        },
        {
            name: "calculate",
            description: "Evaluate a math expression and return the numeric result.",
            parameters: { type: "object", properties: { expression: { type: "string", description: "A math expression, e.g. '(2+3)*4/7'." } }, required: ["expression"] }
        },
        {
            name: "web_search",
            description: "Search the web for current facts via DuckDuckGo. Returns a short instant-answer / related snippets summary.",
            parameters: { type: "object", properties: { query: { type: "string", description: "The search query." } }, required: ["query"] }
        },
        {
            name: "read_url",
            description: "Fetch a web page and return its text content (HTML stripped, truncated). Best for article/text pages, not JavaScript-heavy sites.",
            parameters: { type: "object", properties: { url: { type: "string", description: "The URL to fetch." } }, required: ["url"] }
        },
        {
            name: "opencode_task",
            description: "Delegate a coding or deep technical task to OpenCode — an autonomous coding agent that can edit files, run shell/build/test/git, and use LSP. Use for writing/refactoring/debugging code, editing project files, or any multi-step engineering work. Give ONE complete, self-contained task. Returns OpenCode's final result. NOTE: this can take a while and runs real commands.",
            parameters: { type: "object", properties: {
                task: { type: "string", description: "Complete, self-contained coding/technical task for OpenCode to perform." },
                cwd: { type: "string", description: "Optional absolute working directory (the project to work in). Defaults to home." }
            }, required: ["task"] }
        }
    ]

    // Control tools (handled specially by AiService, not executed as shell commands).
    readonly property var callAgentDef: ({
        name: "call_agent",
        description: "Delegate a self-contained task to a specialist agent and get its result back. "
            + "Agents: 'scout' = web research (web_search, read_url); 'forge' = Linux system/shell/hyprland/media/logs; "
            + "'vector' = desktop windows & compositor control; 'sage' = general helper. "
            + "Give ONE complete, self-contained task. Returns the agent's final result. Do simple things yourself instead.",
        parameters: { type: "object", properties: {
            agent: { type: "string", description: "One of: scout, forge, vector, sage" },
            task: { type: "string", description: "Complete, self-contained task description for the agent." }
        }, required: ["agent", "task"] }
    })
    readonly property var returnResultDef: ({
        name: "return_result",
        description: "Return your final result to the coordinator. Call this exactly once when your task is complete.",
        parameters: { type: "object", properties: {
            result: { type: "string", description: "Your final answer / summary for the coordinator." }
        }, required: ["result"] }
    })

    // Format an explicit list of tool defs for a given provider api_format.
    function formatDefs(apiFormat, arr) {
        const plain = arr.map(function (d) { return { name: d.name, description: d.description, parameters: d.parameters }; });
        if (apiFormat === "gemini") {
            return [{ functionDeclarations: plain }];
        }
        // openai + mistral
        return plain.map(function (d) { return { type: "function", function: d }; });
    }
    function formatTools(apiFormat) { return formatDefs(apiFormat, defs); }

    // Build the bash command for a tool (null => handled inline / unknown).
    function buildCmd(name, args) {
        args = args || {};
        switch (name) {
        case "run_shell_command":
            return args.command || "";
        case "control_hyprland":
            return "hyprctl " + (args.command || "");
        case "control_media":
            return "playerctl " + (args.action || "play-pause");
        case "list_windows":
            return "hyprctl clients -j | jq -r '.[] | \"[\\(.workspace.id)] \\(.class) — \\(.title)\"'";
        case "get_system_logs":
            return "journalctl --no-pager -n " + (parseInt(args.lines) || 50) + (args.unit ? " -u " + shellEsc(args.unit) : "");
        case "web_search": {
            // DDG instant-answer (entity abstracts) + Wikipedia search (general facts).
            // DDG's HTML/lite endpoints block automated requests, so we use these reliable JSON APIs.
            const q = encodeURIComponent(args.query || "");
            return "{ "
                + "curl -s --max-time 8 'https://api.duckduckgo.com/?format=json&no_html=1&skip_disambig=1&q=" + q + "' "
                + "| jq -r '[.Heading, .AbstractText, .Answer, .Definition] | map(select(. != null and . != \"\")) | .[]'; "
                + "curl -s --max-time 8 'https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=" + q + "&format=json&srlimit=5' "
                + "| jq -r '.query.search[]? | \"- \" + .title + \": \" + (.snippet | gsub(\"<[^>]*>\";\"\"))'; "
                + "} 2>/dev/null | head -30";
        }
        case "opencode_task": {
            const cwd = (args.cwd && ("" + args.cwd).length > 0) ? shellEsc(args.cwd) : "\"$HOME\"";
            // One-shot non-interactive delegation; strip ANSI, keep the tail (final result).
            return "export PATH=\"$HOME/.opencode/bin:$PATH\"; cd " + cwd + " 2>/dev/null; "
                + "timeout 600 opencode run " + shellEsc(args.task || "") + " 2>&1 "
                + "| sed -r 's/\\x1b\\[[0-9;]*[a-zA-Z]//g' | tail -c 3500";
        }
        case "read_url":
            return "curl -sL --max-time 12 -A 'Mozilla/5.0' " + shellEsc(args.url || "")
                + " | (command -v lynx >/dev/null && lynx -stdin -dump -nolist 2>/dev/null || python3 -c 'import sys,re,html; t=sys.stdin.read(); t=re.sub(r\"(?is)<(script|style).*?>.*?</\\1>\",\" \",t); t=re.sub(r\"(?s)<[^>]+>\",\" \",t); print(html.unescape(re.sub(r\"\\s+\",\" \",t)))') | head -c 4000";
        }
        return null;
    }

    // Execute a tool, calling cb(resultString) when done.
    function execute(name, args, cb) {
        args = args || {};
        if (name === "calculate") {
            cb(calc(args.expression));
            return;
        }
        const cmd = buildCmd(name, args);
        if (cmd === null) { cb("Error: unknown tool '" + name + "'"); return; }
        root._cb = cb;
        toolProc.command = ["bash", "-lc", "{ " + cmd + " ; } 2>&1"];
        toolProc.running = true;
    }

    function calc(expr) {
        try {
            if (!/^[-+*/%(). 0-9eE]+$/.test("" + expr)) return "Error: only basic arithmetic is allowed.";
            const r = Function('"use strict"; return (' + expr + ')')();
            return "" + r;
        } catch (e) {
            return "Error: " + e;
        }
    }

    Process {
        id: toolProc
        stdout: StdioCollector { id: toolOut }
        onExited: (code, status) => {
            if (!root._cb) return;
            const cb = root._cb;
            root._cb = null;
            let out = toolOut.text || "";
            if (out.length > 4000) out = out.slice(0, 4000) + "\n[truncated]";
            cb(out.length > 0 ? out : "(no output)");
        }
    }
}

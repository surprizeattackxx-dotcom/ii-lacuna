pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common.functions as CF
import qs.modules.common
import qs.services
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.services.ai
import "ai/aitools.js" as AiTools

/**
 * LLM chat service. API formats:
 * - `openai`: OpenAI Chat Completions (also used for Ollama, OpenRouter, Mistral — all OpenAI-compatible).
 * - `gemini`: Google Gemini `streamGenerateContent`.
 */
Singleton {
    id: root

    property Component aiMessageComponent: AiMessageData {}
    property Component aiModelComponent: AiModel {}
    property Component geminiApiStrategy: GeminiApiStrategy {}
    property Component openaiApiStrategy: OpenAiApiStrategy {}
    readonly property string interfaceRole: "interface"
    readonly property string apiKeyEnvVarName: "API_KEY"

    signal responseFinished()
    signal requestHideSidebars()
    signal requestRestoreSidebars()
    property bool _inputLeftWasOpen: false
    property bool _inputRightWasOpen: false

    Timer {
        id: sidebarHideTimer
        interval: 380
        repeat: false
        property var pendingAction: null
        onTriggered: { if (pendingAction) { pendingAction(); pendingAction = null; } }
    }

    Timer {
        id: mcpBridgePingTimer
        interval: 500
        repeat: false
        running: true
        onTriggered: root._pingMcpBridge()
    }

    property string systemPrompt: {
        let prompt = Config.options?.ai?.systemPrompt ?? "";
        for (let key in root.promptSubstitutions) {
            // prompt = prompt.replaceAll(key, root.promptSubstitutions[key]);
            // QML/JS doesn't support replaceAll, so use split/join
            prompt = prompt.split(key).join(root.promptSubstitutions[key]);
        }
        const memory = root.aiMemoryContent.trim();
        if (memory.length > 0) {
            prompt += `\n\n## Your memory of the user\n${memory}`;
        }
        return prompt;
    }
    // property var messages: []
    property var messageIDs: []
    property var messageByID: ({})

    // ── Multi-agent state ──────────────────────────────────────────────────────
    property string activeAgentType: ""       // "" = Aria (coordinator) mode
    property string _pendingAgentResult: ""   // set by return_result, consumed by markDone
    property bool _pendingDesktopAction: false // true while commandExecutionProc runs a desktop action — suppresses premature requestRestoreSidebars
    property var agentCallStack: []           // [{parentAgentType, toolCallId, savedCalls}]
    property var agentMsgIDs: ({})            // agentType -> [id, ...]
    property var agentMsgByID: ({})           // id -> AiMessageData (agent-private, not in UI)

    // Default cloud model for agent escalation — used when local model delegates via call_agent
    readonly property string agentCloudModel: "minimax-m2.7:cloud"

    readonly property var agentDefs: ({
        "desktop": {
            displayName: "Vector",
            emoji: "🖥️",
            useCloudModel: true,
            systemPrompt: "You are Vector, a desktop automation specialist on a Linux/Wayland desktop (Hyprland, 3 monitors). Your job: control the desktop by taking screenshots, clicking UI elements, typing text, scrolling, and launching apps. Always take a screenshot first to see current state. Work step by step, verify each action. When your task is complete, call return_result with a clear summary.",
            toolNames: ["run_task", "take_screenshot", "click_at", "click_cell", "type_text", "press_key",
                        "scroll", "drag_to", "hover", "launch_app", "kill_process", "open_file", "capture_region",
                        "ocr_region", "read_clipboard_text", "write_clipboard", "read_clipboard_image",
                        "read_screen_text", "manage_tabs", "wait_and_screenshot",
                        "control_hyprland", "return_result"]
        },
        "research": {
            displayName: "Scout",
            emoji: "🔍",
            useCloudModel: true,
            systemPrompt: "You are Scout, a research specialist. Your job: search the web, read URLs, and gather accurate information. Be thorough and cite sources. ALWAYS end by calling return_result with your findings — never produce a plain text response without calling return_result first.\n\nIMPORTANT: For any news request (headlines, NPR, BBC, current events), ALWAYS use get_news. Do NOT use read_url for news — most news sites require JavaScript and read_url will return empty results.\n\nFor JavaScript-heavy sites (YouTube, Google, Twitter, Reddit), read_url will return 0 elements — use web_search instead to find URLs and information, then return_result with what you found.",
            toolNames: ["get_news", "web_search", "read_url", "execute_js", "search_app", "calculate", "rag_search", "return_result"]
        },
        "system": {
            displayName: "Forge",
            emoji: "⚙️",
            useCloudModel: true,
            systemPrompt: "You are Forge, a system administration specialist on Linux. Your job: execute shell commands, manage processes, control media, interact with Hyprland, and modify shell config. Be careful with destructive commands. When your task is complete, call return_result with the outcome.",
            toolNames: ["run_task", "run_shell_command", "get_system_logs", "control_media", "control_hyprland",
                        "get_shell_config", "set_shell_config", "calculate", "workspace_layout", "return_result"]
        },
        "personal": {
            displayName: "Sage",
            emoji: "📚",
            useCloudModel: true,
            systemPrompt: "You are Sage, a personal assistant specialist. Your job: manage memory, notes, todos, timers, and scheduled tasks. Organise information clearly. When your task is complete, call return_result with a summary.",
            toolNames: ["remember", "memory_file", "search_memory", "manage_notes",
                        "create_todo", "set_timer", "schedule_task", "kg_store", "kg_query", "calendar", "dream", "return_result"]
        }
    })

    // Injected tool definitions (not in static tools property — added dynamically by getActiveTools)
    readonly property var _callAgentDefGemini: ({
        "name": "call_agent",
        "description": "Delegate a task to a specialist agent. Vector=desktop UI/clicking, Scout=deep web research only, Forge=system/shell, Sage=memory/notes/todos. Do NOT use Scout for browser interaction — use execute_js directly. Do NOT use for news (get_news), music (play_music), apps (run_task/open_app), or anything you can do yourself with available tools.",
        "parameters": { "type": "object", "properties": {
            "agent": { "type": "string", "description": "Agent type: 'desktop' (Vector), 'research' (Scout), 'system' (Forge), 'personal' (Sage)" },
            "task":  { "type": "string", "description": "Complete self-contained task description with all required context" }
        }, "required": ["agent", "task"] }
    })
    readonly property var _callAgentDefOai: ({
        "type": "function", "function": {
            "name": "call_agent",
            "description": "Delegate a task to a specialist agent. Vector=desktop UI/clicking, Scout=deep web research only, Forge=system/shell, Sage=memory/notes/todos. Do NOT use Scout for browser interaction — use execute_js directly. Do NOT use for news (get_news), music (play_music), apps (run_task/open_app), or anything you can do yourself with available tools.",
            "parameters": { "type": "object", "properties": {
                "agent": { "type": "string", "description": "Agent type: 'desktop' (Vector), 'research' (Scout), 'system' (Forge), 'personal' (Sage)" },
                "task":  { "type": "string", "description": "Complete self-contained task description with all required context" }
            }, "required": ["agent", "task"] }
        }
    })
    readonly property var _returnResultDefGemini: ({
        "name": "return_result",
        "description": "Signal task completion and return the result to Aria (coordinator). Call this when your task is fully done.",
        "parameters": { "type": "object", "properties": {
            "result": { "type": "string", "description": "Clear summary of what was accomplished or the answer found" }
        }, "required": ["result"] }
    })
    readonly property var _returnResultDefOai: ({
        "type": "function", "function": {
            "name": "return_result",
            "description": "Signal task completion and return the result to Aria (coordinator). Call this when your task is fully done.",
            "parameters": { "type": "object", "properties": {
                "result": { "type": "string", "description": "Clear summary of what was accomplished or the answer found" }
            }, "required": ["result"] }
        }
    })

    /** Local Jan-compatible MCP bridge (run ~/.config/quickshell/scripts/mcp-sidebar-bridge/run.sh) */
    property bool mcpBridgeAvailable: false
    property string mcpBridgeUrl: "http://127.0.0.1:3847"
    readonly property var _mcpListCatalogGemini: ({
        "name": "mcp_list_catalog",
        "description": "Compact MCP index: server keys and tool names with short blurbs only (no JSON schemas—keeps context small). Prefer skipping this if the user already named a server/tool; call mcp_call directly when possible.",
        "parameters": { "type": "object", "properties": {} }
    })
    readonly property var _mcpCallGemini: ({
        "name": "mcp_call",
        "description": "Invoke one tool on a configured MCP server (stdio). Use mcp_list_catalog only when you truly do not know server or tool names. Server keys match Jan: e.g. filesystem, git, github, ollama, time.",
        "parameters": {
            "type": "object",
            "properties": {
                "server": { "type": "string", "description": "Server key from catalog (e.g. filesystem, git, homeassistant)" },
                "tool": { "type": "string", "description": "Tool name from that server" },
                "arguments": { "type": "object", "description": "Arguments object for the tool (may be empty)" }
            },
            "required": ["server", "tool"]
        }
    })
    readonly property var _mcpListCatalogOai: ({
        "type": "function",
        "function": {
            "name": "mcp_list_catalog",
            "description": "Compact MCP index: server keys and tool names with short blurbs only (no JSON schemas). Prefer skipping if the user already named a server/tool; call mcp_call directly when possible.",
            "parameters": { "type": "object", "properties": {} }
        }
    })
    readonly property var _mcpCallOai: ({
        "type": "function",
        "function": {
            "name": "mcp_call",
            "description": "Invoke one tool on a configured MCP server (stdio). Use mcp_list_catalog only when you do not know server or tool names. Server keys match Jan (filesystem, git, github, ollama, etc.).",
            "parameters": {
                "type": "object",
                "properties": {
                    "server": { "type": "string", "description": "Server key from catalog" },
                    "tool": { "type": "string", "description": "Tool name from that server" },
                    "arguments": { "type": "object", "description": "Tool arguments (optional)" }
                },
                "required": ["server", "tool"]
            }
        }
    })

    // ── Auto-routing tool system ──────────────────────────────────────────────
    // Instead of forcing model to delegate via call_agent, the code detects
    // intent from the user message and gives the model only relevant tools.
    // Small models get focused subsets; cloud/large models get everything.

    property string _lastUserMessageText: ""

    // Tool sets by intent category
    readonly property var _toolSets: ({
        "desktop": ["take_screenshot", "click_at", "click_cell", "type_text", "press_key",
                     "scroll", "drag_to", "hover", "launch_app", "open_file", "wait_for_app",
                     "wait_and_screenshot", "manage_tabs", "read_screen_text"],
        "media":   ["play_music", "control_media"],
        "research":["web_search", "read_url", "get_news", "calculate"],
        "memory":  ["remember", "search_memory", "forget_memory", "dream"],
        "system":  ["run_shell_command", "control_hyprland", "kill_process", "get_system_logs"],
        "comms":   ["notify", "speak", "send_message"],
        "clipboard":["read_clipboard_text", "write_clipboard"],
        "coding":  ["opencode_task"],
        // Advanced tools — only for large/cloud models
        "advanced":["execute_js", "search_app", "capture_region", "ocr_region",
                    "read_clipboard_image", "memory_file", "kg_store", "kg_query",
                    "rag_search", "rag_index", "schedule_task", "set_timer",
                    "create_todo", "manage_notes", "get_notifications", "reply_notification",
                    "control_system", "get_shell_config", "set_shell_config",
                    "workspace_layout", "open_app", "run_task", "calendar",
                    "pick_color", "export_chat", "call_agent", "show_plan", "dream",
                    "mcp_list_catalog", "mcp_call"],
        "mcp": ["mcp_list_catalog", "mcp_call"]
    })

    // Intent detection keywords
    readonly property var _intentKeywords: ({
        "desktop": ["screenshot", "screen", "click", "drag", "open ", "launch", "close ",
                     "tab", "hover", "scroll", "type ", "press ", "file manager", "browser",
                     "window", "app", "application", "desktop"],
        "media":   ["music", "play ", "song", "spotify", "pause", "skip", "shuffle",
                     "next song", "previous", "volume", "queue", "playlist", "album",
                     "artist", "track", "listen"],
        "research":["search", "look up", "find ", "what is", "what are", "who is",
                     "how to", "why ", "news", "article", "website", "url", "google",
                     "calculate", "math"],
        "memory":  ["remember", "recall", "forget", "memory", "you know", "last time",
                     "previously", "dream", "consolidate", "clean up memories"],
        "system":  ["command", "terminal", "shell", "logs", "process", "kill ",
                     "workspace", "monitor", "volume", "brightness", "shutdown",
                     "reboot", "restart"],
        "comms":   ["notify", "notification", "speak", "say ", "tell ", "message",
                     "send ", "text "],
        "clipboard":["clipboard", "copy", "paste", "copied"],
        "coding":  ["code", "refactor", "debug", "implement", "function", "bug", "git ",
                     "compile", "build ", "unit test", "repository", "repo", "codebase",
                     "opencode", "script", "stack trace", "pull request"],
        "mcp": ["mcp", "model context", "jan mcp", "mcp server", "home assistant",
                "gmail", "calendar", "pull request", "github issue", "discord message", "sqlite",
                "searx", "notion", "google drive", "filesystem mcp"]
    })

    // Detect model tier: "small" (<14B local), "medium" (14-30B local), "large" (cloud or 30B+)
    function _getModelTier() {
        const provider = root.currentModelId || "";
        // Cloud providers are always "large"
        if (provider === "openrouter" || provider === "google" || provider === "mistral") return "large";
        // Ollama: parse model name for size hints
        const modelName = (root.currentModel || "").toLowerCase();
        // Check for size indicators in model name
        const sizeMatch = modelName.match(/(\d+)b/);
        if (sizeMatch) {
            const paramB = parseInt(sizeMatch[1]);
            if (paramB >= 30) return "large";
            if (paramB >= 14) return "medium";
            return "small";
        }
        // No size in name — assume small for safety
        return "small";
    }

    // Detect intents from user message
    function _detectIntents(message) {
        const msg = message.toLowerCase();
        const detected = [];
        const intentKeys = Object.keys(root._intentKeywords);
        for (let i = 0; i < intentKeys.length; i++) {
            const intent = intentKeys[i];
            const keywords = root._intentKeywords[intent];
            for (let k = 0; k < keywords.length; k++) {
                if (msg.includes(keywords[k])) {
                    detected.push(intent);
                    break; // One match per intent is enough
                }
            }
        }
        // Default: if nothing detected, give desktop + research (most common)
        if (detected.length === 0) detected.push("desktop", "research");
        return detected;
    }

    // Build tool list based on intent + model tier
    function _getToolsForContext() {
        const tier = root._getModelTier();

        // Large models get everything — no filtering
        if (tier === "large") return null; // null = no filtering

        const intents = root._detectIntents(root._lastUserMessageText);
        let toolNames = [];

        // Collect tools from detected intents
        for (let i = 0; i < intents.length; i++) {
            const intentTools = root._toolSets[intents[i]];
            if (intentTools) {
                for (let t = 0; t < intentTools.length; t++) {
                    if (toolNames.indexOf(intentTools[t]) === -1) toolNames.push(intentTools[t]);
                }
            }
        }

        // Medium models also get clipboard + advanced subset
        if (tier === "medium") {
            const extras = root._toolSets["clipboard"].concat([
                "run_task", "open_app", "show_plan", "execute_js", "search_app",
                "control_system", "workspace_layout", "call_agent",
                "opencode_task", "mcp_list_catalog", "mcp_call"
            ]);
            for (let e = 0; e < extras.length; e++) {
                if (toolNames.indexOf(extras[e]) === -1) toolNames.push(extras[e]);
            }
        }

        // Always include clipboard for small models too (very useful)
        const clip = root._toolSets["clipboard"];
        for (let c = 0; c < clip.length; c++) {
            if (toolNames.indexOf(clip[c]) === -1) toolNames.push(clip[c]);
        }

        return toolNames;
    }

    function getActiveTools(apiFormat) {
        const isGemini = (apiFormat === "gemini");

        // Sub-agent mode: filter to agent's tool subset + inject return_result
        if (root.activeAgentType) {
            const agentDef = root.agentDefs[root.activeAgentType];
            if (!agentDef) return root.tools[apiFormat]["none"] || [];
            const toolNames = agentDef.toolNames;
            const allFunctions = root.tools[apiFormat]["functions"];
            if (isGemini) {
                const allDecls = allFunctions[0]?.functionDeclarations || [];
                const filtered = allDecls.filter(t => toolNames.includes(t.name));
                return [{ functionDeclarations: [...filtered, root._returnResultDefGemini] }];
            }
            const filtered = (allFunctions || []).filter(t => toolNames.includes(t.function?.name || t.name));
            return [...filtered, root._returnResultDefOai];
        }

        // Coordinator mode
        const base = root.tools[apiFormat][root.currentTool];
        if (root.currentTool !== "functions") return base;

        // Get context-aware tool filter
        const allowedTools = root._getToolsForContext();

        // All tiers get call_agent — small/medium models can escalate to cloud
        if (isGemini) {
            let decls = base[0]?.functionDeclarations || [];
            if (allowedTools !== null) {
                decls = decls.filter(t => allowedTools.includes(t.name));
            }
            const mcpG = root.mcpBridgeAvailable ? [root._mcpListCatalogGemini, root._mcpCallGemini] : [];
            return [{ functionDeclarations: [...decls, ...mcpG, root._callAgentDefGemini] }];
        }

        let filtered = base;
        if (allowedTools !== null) {
            filtered = base.filter(t => allowedTools.includes(t.function?.name || t.name));
        }
        const mcpO = root.mcpBridgeAvailable ? [root._mcpListCatalogOai, root._mcpCallOai] : [];
        return [...filtered, ...mcpO, root._callAgentDefOai];
    }

    function _finalizeCurrentAgent(result) {
        if (root.agentCallStack.length === 0) return;
        const frame = root.agentCallStack[root.agentCallStack.length - 1];
        root.agentCallStack = root.agentCallStack.slice(0, -1);
        const agentType = root.activeAgentType;
        const agentDisplay = root.agentDefs[agentType]?.displayName || agentType;
        // Log agent conversation for training data before cleanup
        root._logAgentTrace(agentType, result);
        // Clean up agent message objects
        const ids = root.agentMsgIDs[agentType] || [];
        for (const id of ids) { delete root.agentMsgByID[id]; }
        const newAgentMsgIDs = Object.assign({}, root.agentMsgIDs);
        delete newAgentMsgIDs[agentType];
        root.agentMsgIDs = newAgentMsgIDs;
        // Restore parent context
        root.activeAgentType = frame.parentAgentType;
        root.consecutiveToolCalls = frame.savedCalls;
        // Inject result into parent (coordinator) context
        root._pendingToolCallId = frame.toolCallId;
        root.addFunctionOutputMessage("call_agent", `[${agentDisplay}]: ${result}`);
        requester.makeRequest();
    }
    // ── End multi-agent ────────────────────────────────────────────────────────
    readonly property var apiKeys: KeyringStorage.keyringData?.apiKeys ?? {}
    readonly property var apiKeysLoaded: KeyringStorage.loaded
    readonly property bool currentModelHasApiKey: {
        const model = models[currentModelId];
        if (!model || !model.requires_key) return true;
        if (!apiKeysLoaded) return false;
        const key = apiKeys[model.key_id];
        return (key?.length > 0);
    }
    property var postResponseHook
    property real temperature: Persistent.states?.ai?.temperature ?? 0.5
    property QtObject tokenCount: QtObject {
        property int input: -1
        property int output: -1
        property int total: -1
    }

    function idForMessage(message) {
        // Generate a unique ID using timestamp and random value
        return Date.now().toString(36) + Math.random().toString(36).substr(2, 8);
    }

    function _pingMcpBridge() {
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            const up = (xhr.status >= 200 && xhr.status < 300);
            root.mcpBridgeAvailable = up;
            if (!up && (Config.options.ai?.mcpBridgeAutostart ?? true) && !mcpBridgeProc.running) {
                mcpBridgeProc.running = true;
                mcpBridgeRetryTimer.start();
            }
        };
        xhr.open("GET", root.mcpBridgeUrl + "/health");
        xhr.send();
    }

    Process {
        id: mcpBridgeProc
        command: ["bash", Quickshell.shellPath("scripts/mcp-sidebar-bridge/run.sh")]
    }

    Timer {
        id: mcpBridgeRetryTimer
        interval: 2500
        repeat: true
        property int tries: 0
        onTriggered: {
            tries++;
            root._pingMcpBridge();
            if (root.mcpBridgeAvailable || tries > 8) { stop(); tries = 0; }
        }
    }

    function _mcpHttpRequest(method, path, body, message, fnName) {
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr.status >= 200 && xhr.status < 300) {
                root.addFunctionOutputMessage(fnName, xhr.responseText || "(empty)");
            } else {
                root.addFunctionOutputMessage(fnName, "[MCP bridge] HTTP " + xhr.status + "\n" + (xhr.responseText || "") + "\n\nStart the bridge: ~/.config/quickshell/ii/scripts/mcp-sidebar-bridge/run.sh");
            }
            requester.makeRequest();
        };
        xhr.open(method, root.mcpBridgeUrl + path);
        if (body) {
            xhr.setRequestHeader("Content-Type", "application/json");
            xhr.send(body);
        } else {
            xhr.send();
        }
    }

    function safeModelName(modelName) {
        return modelName.replace(/:/g, "_").replace(/ /g, "-").replace(/\//g, "-")
    }

    property list<var> defaultPrompts: []
    property list<var> userPrompts: []
    property list<var> promptFiles: [...defaultPrompts, ...userPrompts]
    property list<var> savedChats: []

    property string openWindowsList: ""
    property string currentMediaTitle: ""
    property string activityContext: ""

    property var promptSubstitutions: {
        "{DISTRO}": SystemInfo.distroName,
        "{DATETIME}": `${DateTime.time}, ${DateTime.collapsedCalendarFormat}`,
        "{WINDOWCLASS}": ToplevelManager.activeToplevel?.appId ?? "Unknown",
        "{WINDOWTITLE}": ToplevelManager.activeToplevel?.title ?? "Unknown",
        "{CLIPBOARD}": (Quickshell.clipboardText ?? "").substring(0, 300),
        "{DE}": `${SystemInfo.desktopEnvironment} (${SystemInfo.windowingSystem})`,
        "{OPENWINDOWS}": root.openWindowsList,
        "{CURRENTMEDIA}": root.currentMediaTitle,
        "{ACTIVITY}": root.activityContext,
    }

    property string aiMemoryContent: ""
    FileView {
        id: memoryFileView
        path: Directories.aiMemoryPath
        onTextChanged: root.aiMemoryContent = memoryFileView.text() ?? ""
        Component.onCompleted: memoryFileView.reload()
    }

    // Gemini: https://ai.google.dev/gemini-api/docs/function-calling
    // OpenAI-compatible (Ollama, OpenRouter, Mistral, etc.): https://platform.openai.com/docs/guides/function-calling
    // Gemini `functionDeclarations` may include extras (e.g. switch_to_search_mode) not present under tools.openai.
    property string currentTool: Config?.options.ai.tool ?? "search"
    readonly property var tools: AiTools.tools()
    property list<var> availableTools: Object.keys(root.tools[models[currentModelId]?.api_format]) ?? []
    property var toolDescriptions: {
        "functions": Translation.tr("Commands, edit configs, search.\nTakes an extra turn to switch to search mode if that's needed"),
        "search": Translation.tr("Gives the model search capabilities (immediately)"),
        "none": Translation.tr("Disable tools")
    }

    readonly property string currentModel: Persistent.states.ai.model
    // Model properties:
    // - name: Name of the model
    // - icon: Icon name of the model
    // - description: Description of the model
    // - endpoint: Endpoint of the model
    // - model: Model name of the model
    // - requires_key: Whether the model requires an API key
    // - key_id: The identifier of the API key. Use the same identifier for models that can be accessed with the same key.
    // - key_get_link: Link to get an API key
    // - key_get_description: Description of pricing and how to get an API key
    // - api_format: The API format of the model. Can be "openai" or "gemini". Default is "openai".
    // - extraParams: Extra parameters to be passed to the model. This is a JSON object.
    property var models: Config.options.policies.ai === 2 ? {} : {
        "openrouter": aiModelComponent.createObject(this, {
            name: `OpenRouter - ${currentModel}`,
            icon: "openrouter-symbolic",
            description: Translation.tr("Online via %1 | %2's model")
                .arg("OpenRouter")
                .arg("Google"),
            homepage: `https://openrouter.ai/google/${currentModel}`, 
            endpoint: "https://openrouter.ai/api/v1/chat/completions",
            model: `${getModelProvider(Persistent.states.ai.provider,currentModel)}/${currentModel}`,
            requires_key: true,
            key_id: "openrouter",
            key_get_link: "https://openrouter.ai/settings/keys",
            key_get_description: Translation.tr(
                "**Pricing**: Pay-as-you-go (token based).\n\n" +
                "**Instructions**: Log into your OpenRouter account, " +
                "go to Keys in the top-right menu, and create an API key."
            ),
        }),
        // Ollama exposes `/v1/chat/completions` (OpenAI-compatible). Uses tools.openai + OpenAiApiStrategy — same path as OpenRouter/Mistral.
        "ollama": aiModelComponent.createObject(this, {
            "name": `Ollama - ${currentModel}`,
            "icon": guessModelLogo(currentModel),
                                                "description": Translation.tr("Local Ollama model | %1").arg(currentModel),
                                                "homepage": `https://ollama.com/library/${currentModel}`,
                                                "endpoint": "http://localhost:11434/v1/chat/completions",
                                                "model": currentModel,
                                                "requires_key": false,
                                                "api_format": "openai",
                                                "extraParams": { "num_ctx": 32768 },
        }),
        "google": aiModelComponent.createObject(this, {
            "name": `Google - ${currentModel}`,
            "icon": "google-gemini-symbolic",
            "description": Translation.tr("Online | Google's model\nNewer model that's slower than its predecessor but should deliver higher quality answers"),
            "homepage": "https://aistudio.google.com",
            "endpoint": `https://generativelanguage.googleapis.com/v1beta/models/${currentModel}:streamGenerateContent`,
            "model": `${currentModel}`,
            "requires_key": true,
            "key_id": "gemini",
            "key_get_link": "https://aistudio.google.com/app/apikey",
            "key_get_description": Translation.tr("**Pricing**: free. Data used for training.\n\n**Instructions**: Log into Google account, allow AI Studio to create Google Cloud project or whatever it asks, go back and click Get API key"),
            "api_format": "gemini",
        }),
        "mistral": aiModelComponent.createObject(this, {
            "name": `Mistral - ${currentModel}`,
            "icon": "mistral-symbolic",
            "description": Translation.tr("Online | %1's model | Delivers fast, responsive and well-formatted answers. Disadvantages: not very eager to do stuff; might make up unknown function calls").arg("Mistral"),
            "homepage": "https://mistral.ai/news/mistral-medium-3",
            "endpoint": "https://api.mistral.ai/v1/chat/completions",
            "model": `${currentModel}`,
            "requires_key": true,
            "key_id": "mistral",
            "key_get_link": "https://console.mistral.ai/api-keys",
            "key_get_description": Translation.tr("**Instructions**: Log into Mistral account, go to Keys on the sidebar, click Create new key"),
            "api_format": "openai",
        }),
    }
    property var modelList: Object.keys(root.models)
    property var currentModelId: Persistent.states?.ai?.provider || modelList[0]

    property var baseModels: {
        "openrouter": [
            {title: "Gemini 2.5 Flash-Lite", value: "gemini-2.5-flash-lite", modelProvider: "google"},
        ],
        "google": [
            { title: "Gemini 2.5 Flash-Lite", value: "gemini-2.5-flash-lite" },
            { title: "Gemini 2.5 Flash", value: "gemini-2.5-flash" },
            { title: "Gemini 3 Flash Preview", value: "gemini-3-flash-preview" }
        ],
        "mistral": [
            { title: "Mistral Medium 3", value: "mistral-medium-3" }
        ],
        "ollama": [
            { title: "Qwen 3.5 9B", value: "qwen3.5:9b" },
            { title: "Qwen 3.5 27B", value: "qwen3.5:27b" },
            { title: "Qwen 3 14B", value: "qwen3:14b" },
            { title: "Ministral 3 8B", value: "ministral-3:8b" },
            { title: "Qwen 2.5 VL 7B", value: "qwen2.5vl:7b" },
            { title: "Qwen 3 VL 8B", value: "qwen3-vl:8b" },
            { title: "Qwen 3 Claude", value: "qwen3-claude" },
            { title: "MiniMax M2.7 Cloud", value: "minimax-m2.7:cloud" },
        ],
    }

    property var modelsOfProviders: baseModels

    function mergeModelsFromList(base, extraList) {

        var result = {}
        for (var provider in base) {
            result[provider] = base[provider].slice()
        }
        
        if (extraList) {
            for (var i = 0; i < extraList.length; i++) {
                var item = extraList[i]
                for (var provider in item) {
                    if (result[provider]) {
                        result[provider] = result[provider].concat(item[provider])
                    } else {
                        result[provider] = item[provider].slice()
                    }
                }
            }
        }
        
        return result
    }

    function getModelProvider(providerKey, modelValue) {
        if (!modelsOfProviders[providerKey]) {
            return null
        }
        
        var models = modelsOfProviders[providerKey]
        for (var i = 0; i < models.length; i++) {
            if (models[i].value === modelValue) {
                return models[i].modelProvider || null
            }
        }
        
        return null
    }


    property var apiStrategies: {
        "openai": openaiApiStrategy.createObject(this),
        "gemini": geminiApiStrategy.createObject(this),
    }
    property ApiStrategy currentApiStrategy: apiStrategies[models[currentModelId]?.api_format || "openai"]

    property string requestScriptFilePath: "/tmp/quickshell/ai/request.sh"
    property string pendingFilePath: ""
    // True while the AI requester process is running (streaming a response)
    readonly property bool isGenerating: requester.running || commandExecutionProc.running

    // Screenshot scaling — used so 4K screenshots are downscaled to 1920px wide
    // before sending to the model. click_at coords are in the scaled space.
    property real lastScreenshotScale: 1.0
    property int lastScreenshotWidth: 0
    property int lastScreenshotHeight: 0
    property int lastScreenshotOffsetX: 0
    property int lastScreenshotOffsetY: 0
    property int lastGridCols: 8
    property int lastGridRows: 5
    property string _lastClickInfo: ""
    // Set before each screenshotProc run; consumed in makeRequest when attaching tool_choice after vision.
    // "explicit" = user/tool take_screenshot — force next tool. "execute_js" / "followup" = automation — do not force (avoids execute_js loops).
    property string _pendingVisionFollowUpKind: ""
    // One send_message per user turn — handler fires makeRequest immediately; model otherwise loops send_message dozens of times.
    property bool _sendMessageIssuedThisTurn: false
    property bool _sessionLogged: false

    Component.onCompleted: {
        // Ensure memories directory exists
        Quickshell.execDetached(["bash", "-c", `mkdir -p "${Directories.aiMemoryPath.replace("memory.md", "memories")}"`]);
        setModel(currentModelId, false, false); // Do necessary setup for model
        if (Config.options.ai.extraModels?.length > 0) {
            modelsOfProviders = mergeModelsFromList(baseModels, Config.options.ai.extraModels)
        }
    }

    Component.onDestruction: {
        // Save training data before QS reload destroys state
        if (root.activeAgentType && root.agentCallStack.length > 0) {
            root._logAgentTrace(root.activeAgentType, "[interrupted by reload]");
        }
        root._logCompletedSession();
        root.saveChat("lastSession");
    }

    function guessModelLogo(model) {
        if (model.includes("llama")) return "ollama-symbolic";
        if (model.includes("gemma")) return "google-gemini-symbolic";
        if (model.includes("deepseek")) return "deepseek-symbolic";
        if (/^phi\d*:/i.test(model)) return "microsoft-symbolic";
        return "ollama-symbolic";
    }

    function guessModelName(model) {
        const replaced = model.replace(/-/g, ' ').replace(/:/g, ' ');
        let words = replaced.split(' ');
        words[words.length - 1] = words[words.length - 1].replace(/(\d+)b$/, (_, num) => `${num}B`)
        words = words.map((word) => {
            return (word.charAt(0).toUpperCase() + word.slice(1))
        });
        if (words[words.length - 1] === "Latest") words.pop();
        else words[words.length - 1] = `(${words[words.length - 1]})`; // Surround the last word with square brackets
        const result = words.join(' ');
        return result;
    }

    function addModel(modelName, data) {
        root.models[modelName] = aiModelComponent.createObject(this, data);
    }

    Process {
        id: getOllamaModels
        running: true
        command: ["bash", "-c", "curl -s http://localhost:11434/api/tags | jq -c '[.models[].name]'"]
        stdout: StdioCollector {
            onStreamFinished: {
                console.log("Ollama output:", text);
                try {
                    if (text.length === 0) return;
                    const dataJson = JSON.parse(text.trim());
                    const EMBED_MODELS = ["nomic-embed", "mxbai-embed", "all-minilm", "snowflake-arctic-embed", "bge-m3", "bge-large"];
                    root.modelsOfProviders = Object.assign({}, root.modelsOfProviders, {
                        "ollama": dataJson
                            .filter(model => !EMBED_MODELS.some(e => model.toLowerCase().includes(e)))
                            .map(model => ({
                                title: guessModelName(model),
                                value: model
                            }))
                    });
                } catch (e) {
                    console.log("Could not fetch Ollama models:", e);
                }
            }
        }
    }

    Process {
        id: getDefaultPrompts
        running: true
        command: ["ls", "-1", Directories.defaultAiPrompts]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) return;
                root.defaultPrompts = text.split("\n")
                    .filter(fileName => fileName.endsWith(".md") || fileName.endsWith(".txt"))
                    .map(fileName => `${Directories.defaultAiPrompts}/${fileName}`)
            }
        }
    }

    Process {
        id: getUserPrompts
        running: true
        command: ["ls", "-1", Directories.userAiPrompts]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) return;
                root.userPrompts = text.split("\n")
                    .filter(fileName => fileName.endsWith(".md") || fileName.endsWith(".txt"))
                    .map(fileName => `${Directories.userAiPrompts}/${fileName}`)
            }
        }
    }

    Process {
        id: getSavedChats
        running: true
        command: ["ls", "-1", Directories.aiChats]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) return;
                root.savedChats = text.split("\n")
                    .filter(fileName => fileName.endsWith(".json"))
                    .map(fileName => `${Directories.aiChats}/${fileName}`)
            }
        }
    }

    FileView {
        id: promptLoader
        watchChanges: false;
        onLoadedChanged: {
            if (!promptLoader.loaded) return;
            Config.options.ai.systemPrompt = promptLoader.text();
            root.addMessage(Translation.tr("Loaded the following system prompt\n\n---\n\n%1").arg(Config.options.ai.systemPrompt), root.interfaceRole);
        }
    }

    function printPrompt() {
        root.addMessage(Translation.tr("The current system prompt is\n\n---\n\n%1").arg(Config.options.ai.systemPrompt), root.interfaceRole);
    }

    function loadPrompt(filePath) {
        promptLoader.path = "" // Unload
        promptLoader.path = filePath; // Load
        promptLoader.reload();
    }

    function addMessage(message, role) {
        if (message.length === 0) return;
        const aiMessage = aiMessageComponent.createObject(root, {
            "role": role,
            "content": message,
            "rawContent": message,
            "thinking": false,
            "done": true,
        });
        const id = idForMessage(aiMessage);
        root.messageIDs = [...root.messageIDs, id];
        root.messageByID[id] = aiMessage;
    }

    function removeMessage(index) {
        if (index < 0 || index >= messageIDs.length) return;
        const id = root.messageIDs[index];
        root.messageIDs.splice(index, 1);
        root.messageIDs = [...root.messageIDs];
        delete root.messageByID[id];
    }

    function addApiKeyAdvice(model) {
        root.addMessage(
            Translation.tr('To set an API key, pass it with the %4 command\n\nTo view the key, pass "get" with the command<br/>\n\n### For %1:\n\n**Link**: %2\n\n%3')
                .arg(model.name).arg(model.key_get_link).arg(model.key_get_description ?? Translation.tr("<i>No further instruction provided</i>")).arg("/key"), 
            Ai.interfaceRole
        );
    }

    function getModel() {
        return models[currentModelId];
    }

    function setModel(modelId, feedback = true, setPersistentState = true) {
        if (!modelId) modelId = ""
        modelId = modelId.toLowerCase()
        if (modelList.indexOf(modelId) !== -1) {
            const model = models[modelId]
            // See if policy prevents online models
            if (Config.options.policies.ai === 2 && !model.endpoint.includes("localhost")) {
                root.addMessage(
                    Translation.tr("Online models disallowed\n\nControlled by `policies.ai` config option"),
                    root.interfaceRole
                );
                return;
            }
            if (setPersistentState) Persistent.states.ai.model = modelId;
            if (feedback) root.addMessage(Translation.tr("Model set to %1").arg(model.name), root.interfaceRole);
            if (model.requires_key) {
                // If key not there show advice
                if (root.apiKeysLoaded && (!root.apiKeys[model.key_id] || root.apiKeys[model.key_id].length === 0)) {
                    root.addApiKeyAdvice(model)
                }
            }
        } else {
            if (feedback) root.addMessage(Translation.tr("Invalid model. Supported: \n```\n") + modelList.join("\n```\n```\n") + "\n```", Ai.interfaceRole)
        }
    }

    function setTool(tool) {
        if (!root.tools[models[currentModelId]?.api_format] || !(tool in root.tools[models[currentModelId]?.api_format])) {
            root.addMessage(Translation.tr("Invalid tool. Supported tools:\n- %1").arg(root.availableTools.join("\n- ")), root.interfaceRole);
            return false;
        }
        Config.options.ai.tool = tool;
        return true;
    }
    
    function getTemperature() {
        return root.temperature;
    }

    function setTemperature(value) {
        if (isNaN(value) || value < 0 || value > 2) {
            root.addMessage(Translation.tr("Temperature must be between 0 and 2"), Ai.interfaceRole);
            return;
        }
        Persistent.states.ai.temperature = value;
        root.temperature = value;
        root.addMessage(Translation.tr("Temperature set to %1").arg(value), Ai.interfaceRole);
    }

    function setApiKey(key) {
        const model = models[currentModelId];
        if (!model.requires_key) {
            root.addMessage(Translation.tr("%1 does not require an API key").arg(model.name), Ai.interfaceRole);
            return;
        }
        if (!key || key.length === 0) {
            const model = models[currentModelId];
            root.addApiKeyAdvice(model)
            return;
        }
        KeyringStorage.setNestedField(["apiKeys", model.key_id], key.trim());
        root.addMessage(Translation.tr("API key set for %1").arg(model.name), Ai.interfaceRole);
    }

    function printApiKey() {
        const model = models[currentModelId];
        if (model.requires_key) {
            const key = root.apiKeys[model.key_id];
            if (key) {
                root.addMessage(Translation.tr("API key:\n\n```txt\n%1\n```").arg(key), Ai.interfaceRole);
            } else {
                root.addMessage(Translation.tr("No API key set for %1").arg(model.name), Ai.interfaceRole);
            }
        } else {
            root.addMessage(Translation.tr("%1 does not require an API key").arg(model.name), Ai.interfaceRole);
        }
    }

    function printTemperature() {
        root.addMessage(Translation.tr("Temperature: %1").arg(root.temperature), Ai.interfaceRole);
    }

    function clearMessages() {
        root.messageIDs = [];
        root.messageByID = ({});
        root.tokenCount.input = -1;
        root.tokenCount.output = -1;
        root.tokenCount.total = -1;
    }

    FileView {
        id: requesterScriptFile
    }

    Process {
        id: requester
        property list<string> baseCommand: ["bash"]
        property AiMessageData message
        property ApiStrategy currentStrategy

        function markDone() {
            requester.message.done = true;
            // Sub-agent completion handling
            if (root.activeAgentType && root.agentCallStack.length > 0) {
                if (root._pendingAgentResult.length > 0) {
                    // Agent called return_result explicitly
                    const res = root._pendingAgentResult;
                    root._pendingAgentResult = "";
                    root._finalizeCurrentAgent(res);
                } else if (!requester.message.functionCall) {
                    // Agent produced a plain text response (no tool call) — use it as result
                    const res = requester.message.content || requester.message.rawContent || "[Agent produced no output]";
                    root._finalizeCurrentAgent(res);
                }
                // For intermediate tool-call steps: just return, makeRequest already scheduled
                return;
            }
            if (root.postResponseHook) {
                root.postResponseHook();
                root.postResponseHook = null;
            }
            if (!root._pendingDesktopAction) root.requestRestoreSidebars();
            root.saveChat("lastSession")
            root._logCompletedSession()
            // Notify user when the model's full turn is done (not mid-tool-chain)
            if (!requester.message.functionCall) {
                const snippet = (requester.message.content || requester.message.rawContent || "").replace(/<[^>]*>/g, "").trim();
                const preview = snippet.length > 150 ? snippet.substring(0, 150) + "…" : (snippet || "Done");
                Quickshell.execDetached(["notify-send", "-a", "ii AI", "-i", "neurology", "AI finished", preview]);
            }
            root.consecutiveToolCalls = 0;
            root.responseFinished()
        }

        function makeRequest() {
            // Check if active agent wants cloud model escalation
            let model = models[currentModelId];
            if (root.activeAgentType) {
                const agentDef = root.agentDefs[root.activeAgentType];
                if (agentDef?.useCloudModel && root.agentCloudModel) {
                    // Create a temporary model object pointing to the cloud Ollama model
                    model = {
                        name: `Ollama - ${root.agentCloudModel}`,
                        model: root.agentCloudModel,
                        endpoint: "http://localhost:11434/v1/chat/completions",
                        requires_key: false,
                        api_format: "openai",
                        extraParams: { "num_ctx": 32768 },
                    };
                }
            }

            // Guard against infinite tool-call loops
            root.consecutiveToolCalls++;
            if (root.consecutiveToolCalls > root.maxConsecutiveToolCalls) {
                root.consecutiveToolCalls = 0;
                root.addMessage(`[Stopped: ${root.maxConsecutiveToolCalls} consecutive tool calls without user input. Please check what went wrong.]`, root.interfaceRole);
                return;
            }

            // Fetch API keys if needed
            if (model?.requires_key && !KeyringStorage.loaded) KeyringStorage.fetchKeyringData();
            
            // Use strategy matching the model's api_format (may differ from currentApiStrategy if agent overrides model)
            requester.currentStrategy = root.apiStrategies[model.api_format || "openai"];
            requester.currentStrategy.reset(); // Reset strategy state

            /* Put API key in environment variable */
            if (model.requires_key) requester.environment[`${root.apiKeyEnvVarName}`] = root.apiKeys ? (root.apiKeys[model.key_id] ?? "") : ""

            /* Build endpoint, request data */
            const endpoint = root.currentApiStrategy.buildEndpoint(model);
            const messageArray = root.activeAgentType
                ? (root.agentMsgIDs[root.activeAgentType] || []).map(id => root.agentMsgByID[id]).filter(Boolean)
                : root.messageIDs.map(id => root.messageByID[id]);
            const filteredMessageArray = messageArray.filter(message => message.role !== Ai.interfaceRole);
            // Strip old file/image data from history — only the current pendingFilePath is sent.
            // Resending base64 screenshots in every message blows context on long agentic chains.
            const lastImgIdx = filteredMessageArray.reduce((last, m, i) => (m.fileUri?.length > 0 || m.filePath?.length > 0) ? i : last, -1);
            const trimmedMessageArray = filteredMessageArray.map((m, i) => {
                if (i < lastImgIdx && (m.fileUri?.length > 0 || m.filePath?.length > 0)) {
                    const stripped = Object.assign({}, m);
                    stripped.fileUri = "";
                    stripped.filePath = "";
                    stripped.fileMimeType = "";
                    return stripped;
                }
                return m;
            });
            // Context compaction: drop old tool results, truncate long ones, cap total context size
            const TOOL_RESULT_KEEP = 12;
            const MAX_TOOL_RESULT_CHARS = 2000;
            const MAX_CONTEXT_MESSAGES = 40;
            let contextArr = trimmedMessageArray;
            // Phase 1: Truncate long tool results (all but the most recent 4)
            const toolIndices = [];
            for (let i = 0; i < contextArr.length; i++) {
                if (contextArr[i].functionName && contextArr[i].functionName.length > 0) toolIndices.push(i);
            }
            if (toolIndices.length > 4) {
                for (let t = 0; t < toolIndices.length - 4; t++) {
                    const idx = toolIndices[t];
                    const m = contextArr[idx];
                    if (m.rawContent && m.rawContent.length > MAX_TOOL_RESULT_CHARS) {
                        const truncated = Object.assign({}, m);
                        truncated.rawContent = m.rawContent.substring(0, MAX_TOOL_RESULT_CHARS) + "\n[truncated]";
                        contextArr[idx] = truncated;
                    }
                }
            }
            // Phase 2: Drop old tool call/result pairs when too many
            if (contextArr.length > 30) {
                const toolMsgs = contextArr.filter(m => m.functionName && m.functionName.length > 0);
                if (toolMsgs.length > TOOL_RESULT_KEEP) {
                    const toDropTools = toolMsgs.slice(0, toolMsgs.length - TOOL_RESULT_KEEP);
                    const dropToolSet = new Set(toDropTools);
                    const indicesToRemove = new Set();
                    for (let i = 0; i < contextArr.length; i++) {
                        if (dropToolSet.has(contextArr[i])) {
                            indicesToRemove.add(i);
                            if (i > 0) {
                                const prev = contextArr[i - 1];
                                if (prev.role === "assistant" && prev.functionCall && prev.functionCall.name) {
                                    indicesToRemove.add(i - 1);
                                }
                            }
                        }
                    }
                    contextArr = contextArr.filter((_, i) => !indicesToRemove.has(i));
                    console.log(`[AI] Context compacted: dropped ${indicesToRemove.size} messages (${contextArr.length} remaining)`);
                }
            }
            // Phase 3: Hard cap — if still too many messages, keep first 4 + last MAX_CONTEXT_MESSAGES-4
            if (contextArr.length > MAX_CONTEXT_MESSAGES) {
                const head = contextArr.slice(0, 4);
                const tail = contextArr.slice(-(MAX_CONTEXT_MESSAGES - 4));
                contextArr = [...head, ...tail];
                console.log(`[AI] Context hard-capped to ${contextArr.length} messages`);
            }
            const agentSysPrompt = root.activeAgentType
                ? (root.agentDefs[root.activeAgentType]?.systemPrompt || root.systemPrompt)
                : root.systemPrompt;
            const data = root.currentApiStrategy.buildRequestData(model, contextArr, agentSysPrompt, root.temperature, root.getActiveTools(model.api_format), root.pendingFilePath);
            // After vision pipeline tool results, optionally force the next step to use a tool.
            // Do NOT force after automated follow-up screenshots (execute_js / click / search_app): tool_choice "required"
            // makes the model call execute_js again in a tight loop even when the first run succeeded.
            const fmt = model.api_format || "openai";
            if (data && data.tools && data.tools.length > 0 && fmt === "openai") {
                const last = contextArr.length > 0 ? contextArr[contextArr.length - 1] : null;
                const visionToolNames = ["take_screenshot", "capture_region", "read_clipboard_image"];
                if (last && last.functionName && visionToolNames.includes(last.functionName)) {
                    const vKind = root._pendingVisionFollowUpKind;
                    root._pendingVisionFollowUpKind = "";
                    if (vKind !== "execute_js" && vKind !== "followup") {
                        data.tool_choice = "required";
                    }
                }
            }
            // console.log("[Ai] Request data: ", JSON.stringify(data, null, 2));

            let requestHeaders = {
                "Content-Type": "application/json",
            }
            
            /* Create local message object */
            requester.message = root.aiMessageComponent.createObject(root, {
                "role": "assistant",
                "model": currentModelId,
                "content": "",
                "rawContent": "",
                "thinking": true,
                "done": false,
            });
            const id = idForMessage(requester.message);
            if (root.activeAgentType) {
                const ids = root.agentMsgIDs[root.activeAgentType] || [];
                root.agentMsgIDs[root.activeAgentType] = [...ids, id];
                root.agentMsgByID[id] = requester.message;
            } else {
                root.messageIDs = [...root.messageIDs, id];
                root.messageByID[id] = requester.message;
            }

            /* Build header string for curl */ 
            let headerString = Object.entries(requestHeaders)
                .filter(([k, v]) => v && v.length > 0)
                .map(([k, v]) => `-H '${k}: ${v}'`)
                .join(' ');

            // console.log("Request headers: ", JSON.stringify(requestHeaders));
            // console.log("Header string: ", headerString);

            /* Get authorization header from strategy */
            const authHeader = requester.currentStrategy.buildAuthorizationHeader(root.apiKeyEnvVarName);
            
            /* Script shebang */
            const scriptShebang = "#!/usr/bin/env bash\n";

            /* Create extra setup when there's an attached file */
            let scriptFileSetupContent = ""
            if (root.pendingFilePath && root.pendingFilePath.length > 0) {
                requester.message.localFilePath = root.pendingFilePath;
                scriptFileSetupContent = requester.currentStrategy.buildScriptFileSetup(root.pendingFilePath);
                root.pendingFilePath = ""
            }

            /* Create command string */
            let scriptRequestContent = ""
            scriptRequestContent += `curl --no-buffer --max-time 120 --connect-timeout 15 "${endpoint}"`
                + ` ${headerString}`
                + (authHeader ? ` ${authHeader}` : "")
                + ` --data '${CF.StringUtils.shellSingleQuoteEscape(JSON.stringify(data))}'`
                + "\n"
            
            /* Send the request */
            const scriptContent = requester.currentStrategy.finalizeScriptContent(scriptShebang + scriptFileSetupContent + scriptRequestContent)
            const shellScriptPath = CF.FileUtils.trimFileProtocol(root.requestScriptFilePath)
            requesterScriptFile.path = Qt.resolvedUrl(shellScriptPath)
            requesterScriptFile.setText(scriptContent)
            requester.command = baseCommand.concat([shellScriptPath]);
            requester.running = true
        }

        stdout: SplitParser {
            onRead: data => {
                if (data.length === 0) return;
                if (requester.message.thinking) requester.message.thinking = false;
                // console.log("[Ai] Raw response line: ", data);

                // Handle response line
                try {
                    const result = requester.currentStrategy.parseResponseLine(data, requester.message);
                    // console.log("[Ai] Parsed response result: ", JSON.stringify(result, null, 2));

                    if (result.functionCall) {
                        console.log("[AI] Dispatching functionCall:", result.functionCall.name);
                        requester.message.functionCall = result.functionCall;
                        requester.message.toolCallId = result.functionCall.id || "";
                        root._pendingToolCallId = result.functionCall.id || "";
                        root.handleFunctionCall(result.functionCall.name, result.functionCall.args, requester.message);
                    }
                    if (result.tokenUsage) {
                        root.tokenCount.input = result.tokenUsage.input;
                        root.tokenCount.output = result.tokenUsage.output;
                        root.tokenCount.total = result.tokenUsage.total;
                    }
                    if (result.finished) {
                        requester.markDone();
                    }
                    
                } catch (e) {
                    console.log("[AI] Could not parse response: ", e);
                    // Do NOT leak raw SSE data into message content
                }
            }
        }

        onExited: (exitCode, exitStatus) => {
            const result = requester.currentStrategy.onRequestFinished(requester.message);
            
            if (result.finished) {
                requester.markDone();
            } else if (!requester.message.done) {
                requester.markDone();
            }

            // Handle error responses
            if (requester.message.content.includes("API key not valid")) {
                root.addApiKeyAdvice(models[requester.message.model]);
            }
        }
    }

    property int consecutiveToolCalls: 0
    property bool _turnHadPlan: false
    property string _pendingToolCallId: ""
    readonly property int maxConsecutiveToolCalls: 25
    property var _toolCallCounts: ({})  // per-tool call count within a turn

    function sendUserMessage(message) {
        if (message.length === 0) return;
        root.consecutiveToolCalls = 0;
        root._turnHadPlan = false;
        root._pendingDesktopAction = false;
        root._pendingVisionFollowUpKind = "";
        root._toolCallCounts = ({});
        root._sendMessageIssuedThisTurn = false;
        root._sessionLogged = false;
        root._lastUserMessageText = message; // Store for intent detection
        root.requestRestoreSidebars();
        root.addMessage(message, "user");
        requester.makeRequest();
    }

    function attachFile(filePath: string) {
        root.pendingFilePath = CF.FileUtils.trimFileProtocol(filePath);
    }

    function regenerate(messageIndex) {
        if (messageIndex < 0 || messageIndex >= messageIDs.length) return;
        const id = root.messageIDs[messageIndex];
        const message = root.messageByID[id];
        if (message.role !== "assistant") return;
        // Remove all messages after this one
        for (let i = root.messageIDs.length - 1; i >= messageIndex; i--) {
            root.removeMessage(i);
        }
        requester.makeRequest();
    }

    function createFunctionOutputMessage(name, output, includeOutputInChat = true) {
        const callId = root._pendingToolCallId || `call_${name}`;
        root._pendingToolCallId = "";
        return aiMessageComponent.createObject(root, {
            "role": "user",
            "content": `[[ Output of ${name} ]]${includeOutputInChat ? ("\n\n<think>\n" + output + "\n</think>") : ""}`,
            "rawContent": `[[ Output of ${name} ]]${includeOutputInChat ? ("\n\n<think>\n" + output + "\n</think>") : ""}`,
            "functionName": name,
            "functionResponse": output,
            "toolCallId": callId,
            "thinking": false,
            "done": true,
            // "visibleToUser": false,
        });
    }

    function triggerAutoScreenshot(delayMs) {
        const delay = delayMs || 500;
        Qt.callLater(() => {
            root._pendingVisionFollowUpKind = "followup";
            const screenshotPath = `${Directories.aiSttTemp}/screenshot.png`;
            const dest = CF.FileUtils.trimFileProtocol(screenshotPath);
            screenshotProc.targetPath = dest;
            const cmd = `
sleep ${delay / 1000}
DEST="${dest}"
MONITORS=$(hyprctl monitors -j 2>/dev/null | tr -d '\\n' || echo '[]')
CURSOR=$(hyprctl cursorpos 2>/dev/null || echo "0, 0")
CX=$(echo "\${CURSOR}" | awk '{gsub(/,/,"",$1); print $1}')
CY=$(echo "\${CURSOR}" | awk '{print $2}')
MON_NAME=$(MONITORS="$MONITORS" python3 -c '
import json,os,sys,subprocess
mons=json.loads(os.environ.get("MONITORS","[]"))
try:
    aw=json.loads(subprocess.run(["hyprctl","activewindow","-j"],capture_output=True,text=True).stdout or "{}")
    mid=aw.get("monitor",-1)
    if mid>=0:
        for m in mons:
            if m.get("id")==mid: print(m.get("name","")); sys.exit()
except: pass
for m in mons:
    if m.get("focused"): print(m.get("name","")); sys.exit()
if mons: print(mons[0].get("name",""))
' 2>/dev/null || echo "")
MON_NAME=$(echo "$MON_NAME" | head -n1 | tr -d '\\r')
if [ -n "$MON_NAME" ]; then
    grim -o "$MON_NAME" "$DEST" 2>&1 || exit 1
else
    grim "$DEST" 2>&1 || exit 1
fi
META=$(DEST=$DEST CX=\${CX} CY=\${CY} MONITORS="$MONITORS" MON_NAME="$MON_NAME" python3 2>&1 << 'PYEOF'
from PIL import Image, ImageDraw, ImageFont
import os, json
dest = os.environ['DEST']
cx   = int(os.environ.get('CX', 0))
cy   = int(os.environ.get('CY', 0))
img  = Image.open(dest).convert('RGBA')
W, H = img.size
cols = 12
rows = max(5, round(cols * H / W))
cell_w = W // cols
cell_h = H // rows
overlay = Image.new('RGBA', (W, H), (0,0,0,0))
draw = ImageDraw.Draw(overlay)
font = None
for p in ['/usr/share/fonts/TTF/DejaVuSans-Bold.ttf',
          '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
          '/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf',
          '/usr/share/fonts/noto/NotoSans-Bold.ttf']:
    try: font = ImageFont.truetype(p, max(14, min(28, cell_h//8))); break
    except: pass
if font is None: font = ImageFont.load_default()
for row in range(rows):
    for col in range(cols):
        n  = row * cols + col + 1
        x1 = col * cell_w; y1 = row * cell_h
        x2 = x1 + cell_w - 1; y2 = y1 + cell_h - 1
        ccx = x1 + cell_w // 2; ccy = y1 + cell_h // 2
        draw.rectangle([x1,y1,x2,y2], outline=(255,255,255,60), width=1)
        t = str(n)
        bb = draw.textbbox((ccx,ccy), t, font=font, anchor='mm')
        draw.rectangle([bb[0]-3,bb[1]-3,bb[2]+3,bb[3]+3], fill=(0,0,0,150))
        draw.text((ccx,ccy), t, fill=(255,255,255,210), font=font, anchor='mm')
monitors = json.loads(os.environ.get('MONITORS','[]'))
mon_name = os.environ.get('MON_NAME','')
off_x, off_y = 0, 0
if mon_name:
    for m in monitors:
        if m.get('name') == mon_name:
            off_x = m.get('x', 0); off_y = m.get('y', 0); break
else:
    off_x = min((m.get('x',0) for m in monitors), default=0)
    off_y = min((m.get('y',0) for m in monitors), default=0)
cx_img = cx - off_x; cy_img = cy - off_y
r = 18
if 0 <= cx_img < W and 0 <= cy_img < H:
    draw.ellipse([cx_img-r,cy_img-r,cx_img+r,cy_img+r], outline=(255,60,60,230), width=3)
    draw.line([cx_img-26,cy_img,cx_img+26,cy_img], fill=(255,60,60,230), width=2)
    draw.line([cx_img,cy_img-26,cx_img,cy_img+26], fill=(255,60,60,230), width=2)
cx_in_bounds = 0 <= cx_img < W and 0 <= cy_img < H
composite = Image.alpha_composite(img, overlay).convert('RGB')
MAX_W = 1920
sf = 1.0
if W > MAX_W:
    sf = W / MAX_W
    new_h = round(H * MAX_W / W)
    composite = composite.resize((MAX_W, new_h), Image.LANCZOS)
    W_out, H_out = MAX_W, new_h
else:
    W_out, H_out = W, H
composite.save(dest)
cx_s = round(cx_img / sf) if cx_in_bounds else -1
cy_s = round(cy_img / sf) if cx_in_bounds else -1
print(f"GRID_META:{W_out}:{H_out}:{cols}:{rows}")
print(f"SCREENSHOT_OFFSET:{off_x}:{off_y}")
print(f"IMG_SCALE:{sf:.6f}")
print(f"CURSOR_S:{cx_s}:{cy_s}")
PYEOF
)
SS_OFFSET_X=$(echo "\${META}" | grep "^SCREENSHOT_OFFSET:" | cut -d: -f2)
SS_OFFSET_Y=$(echo "\${META}" | grep "^SCREENSHOT_OFFSET:" | cut -d: -f3)
SS_OFFSET_X=\${SS_OFFSET_X:-0}
SS_OFFSET_Y=\${SS_OFFSET_Y:-0}
GRID_LINE=$(echo "\${META}" | grep "^GRID_META:")
IMG_W=$(echo "\${GRID_LINE}" | cut -d: -f2)
IMG_H=$(echo "\${GRID_LINE}" | cut -d: -f3)
GRID_COLS=$(echo "\${GRID_LINE}" | cut -d: -f4)
GRID_ROWS=$(echo "\${GRID_LINE}" | cut -d: -f5)
SCALE=$(echo "\${META}" | grep "^IMG_SCALE:" | cut -d: -f2)
SCALE=\${SCALE:-1.0}
CURSOR_LINE=$(echo "\${META}" | grep "^CURSOR_S:")
CURSOR_SS_X=$(echo "\${CURSOR_LINE}" | cut -d: -f2)
CURSOR_SS_Y=$(echo "\${CURSOR_LINE}" | cut -d: -f3)
CURSOR_SS_X=\${CURSOR_SS_X:--1}
CURSOR_SS_Y=\${CURSOR_SS_Y:--1}
echo "CURSOR_POS:\${CURSOR_SS_X}:\${CURSOR_SS_Y}"
echo "GRID:\${GRID_COLS}:\${GRID_ROWS}"
echo "IMAGE_SIZE:\${IMG_W}:\${IMG_H}"
echo "IMAGE_SCALE:\${SCALE}"
echo "SCREENSHOT_OFFSET:\${SS_OFFSET_X}:\${SS_OFFSET_Y}"
`;
            screenshotProc.command = ["bash", "-c", cmd];
            screenshotProc.running = true;
        });
    }

    function addFunctionOutputMessage(name, output) {
        const aiMessage = createFunctionOutputMessage(name, output);
        const id = idForMessage(aiMessage);
        if (root.activeAgentType) {
            const ids = root.agentMsgIDs[root.activeAgentType] || [];
            root.agentMsgIDs[root.activeAgentType] = [...ids, id];
            root.agentMsgByID[id] = aiMessage;
        } else {
            root.messageIDs = [...root.messageIDs, id];
            root.messageByID[id] = aiMessage;
        }
    }

    function rejectCommand(message: AiMessageData) {
        if (!message.functionPending) return;
        message.functionPending = false; // User decided, no more "thinking"
        root._pendingToolCallId = message.toolCallId || "";
        addFunctionOutputMessage(message.functionName, Translation.tr("Command rejected by user"))
    }

    function approveCommand(message: AiMessageData) {
        if (!message.functionPending) return;
        message.functionPending = false; // User decided, no more "thinking"

        root._pendingToolCallId = message.toolCallId || "";
        const responseMessage = createFunctionOutputMessage(message.functionName, "", false);
        const id = idForMessage(responseMessage);
        root.messageIDs = [...root.messageIDs, id];
        root.messageByID[id] = responseMessage;

        commandExecutionProc.message = responseMessage;
        commandExecutionProc.baseMessageContent = responseMessage.content;
        commandExecutionProc.shellCommand = message.functionCall.args.command;
        commandExecutionProc.running = true; // Start the command execution
    }

    Process {
        id: commandExecutionProc
        property string shellCommand: ""
        property AiMessageData message
        property string baseMessageContent: ""
        property string currentToolName: ""
        command: ["bash", "-c", shellCommand]
        stdout: SplitParser {
            onRead: (output) => {
                const MAX_OUTPUT = 4000;
                commandExecutionProc.message.functionResponse += output + "\n\n";
                let responseText = commandExecutionProc.message.functionResponse;
                if (responseText.length > MAX_OUTPUT) {
                    responseText = responseText.substring(0, MAX_OUTPUT) + "\n\n[Output truncated]";
                }
                const updatedContent = commandExecutionProc.baseMessageContent + `\n\n<think>\n<tt>${responseText}</tt>\n</think>`;
                commandExecutionProc.message.rawContent = updatedContent;
                commandExecutionProc.message.content = updatedContent;
            }
        }
        onExited: (exitCode, exitStatus) => {
            commandExecutionProc.message.functionResponse += `[[ Command exited with code ${exitCode} (${exitStatus}) ]]\n`;
            const toolName = commandExecutionProc.currentToolName;
            commandExecutionProc.currentToolName = "";
            if (toolName === "send_message" || toolName === "run_task") {
                commandExecutionProc.message.functionResponse += `[[ Task delegated and complete. Report the above result to the user. Do not call any more tools. ]]\n`;
            } else if (toolName === "open_app" || toolName === "launch_app") {
                commandExecutionProc.message.functionResponse += `[[ App launch finished. Answer only about the user's request (e.g. media/app control). Do not pivot to messaging, WhatsApp, or send_message unless the user asked for that. Do not call more tools unless still needed. ]]\n`;
            } else if (toolName === "web_search") {
                commandExecutionProc.message.functionResponse += `[[ Search complete. Use the results above to answer the user's question. Do NOT search again — analyze these results and respond. If the user asked to buy/add to cart, open the product URL from the results. IMPORTANT: Only cite information and URLs that appear in the search results above. Do NOT make up product names, prices, URLs, or details that are not in these results. If the results don't have enough detail, say so honestly. ]]\n`;
            }
            root._pendingDesktopAction = false;
            requester.makeRequest();
        }
    }



    function handleFunctionCall(name, args: var, message: AiMessageData) {
        message.functionName = name; // Needed so approveCommand can label function output correctly
        // Per-tool repeat limit: block tools that are called too many times in one turn
        const toolLimits = { "web_search": 3, "read_url": 4, "execute_js": 5 };
        if (name in toolLimits) {
            root._toolCallCounts[name] = (root._toolCallCounts[name] || 0) + 1;
            if (root._toolCallCounts[name] > toolLimits[name]) {
                addFunctionOutputMessage(name, `[Blocked] You already called ${name} ${toolLimits[name]} times this turn. STOP calling ${name}. Use the results you already have and respond to the user in text.`);
                requester.makeRequest();
                return;
            }
        }
        // show_plan gate: disabled — small local models loop on show_plan instead of executing
        // The system prompt still encourages planning, but it's not enforced
        // const actionTools = ["click_at","click_cell","type_text","press_key","launch_app","scroll","drag_to","hover","manage_tabs"];
        // if (!root._turnHadPlan && root.consecutiveToolCalls >= 2 && actionTools.includes(name) && !root.activeAgentType) {
        //     addFunctionOutputMessage(name, `[Gate] You attempted '${name}' without calling show_plan first.`);
        //     requester.makeRequest();
        //     return;
        // }
        if (name === "mcp_list_catalog") {
            root._mcpHttpRequest("GET", "/catalog", null, message, "mcp_list_catalog");
        } else if (name === "mcp_call") {
            var rawArgs = args.arguments;
            if (typeof rawArgs === "string") {
                try {
                    rawArgs = JSON.parse(rawArgs);
                } catch (e) {
                    rawArgs = {};
                }
            }
            if (rawArgs === undefined || rawArgs === null)
                rawArgs = {};
            var payload = JSON.stringify({
                server: args.server || "",
                tool: args.tool || "",
                arguments: rawArgs
            });
            root._mcpHttpRequest("POST", "/call", payload, message, "mcp_call");
        } else if (name === "call_agent") {
            const agentType = (args.agent || "").toLowerCase().trim();
            const task = args.task || "";
            if (!root.agentDefs[agentType]) {
                addFunctionOutputMessage(name, `Unknown agent: '${agentType}'. Available: desktop (Vector), research (Scout), system (Forge), personal (Sage).`);
                requester.makeRequest();
                return;
            }
            const def = root.agentDefs[agentType];
            // Push coordinator state onto stack
            root.agentCallStack = [...root.agentCallStack, {
                parentAgentType: root.activeAgentType,
                toolCallId: root._pendingToolCallId,
                savedCalls: root.consecutiveToolCalls
            }];
            root._pendingToolCallId = "";
            root.consecutiveToolCalls = 0;
            // Init agent context: one user message = the task
            const taskMsg = aiMessageComponent.createObject(root, {
                "role": "user", "content": task, "rawContent": task,
                "thinking": false, "done": true
            });
            const taskId = idForMessage(taskMsg);
            root.agentMsgIDs[agentType] = [taskId];
            root.agentMsgByID[taskId] = taskMsg;
            root.activeAgentType = agentType;
            // Show brief indicator in main chat
            root.addMessage(`◆ ${def.displayName} (${def.emoji}) — ${task.substring(0, 100)}${task.length > 100 ? "…" : ""}`, root.interfaceRole);
            requester.makeRequest();
            return;
        } else if (name === "opencode_task") {
            const task = args.task || args.prompt || "";
            if (task.trim().length === 0) {
                addFunctionOutputMessage(name, "No task provided for OpenCode.");
                requester.makeRequest();
                return;
            }
            root.addMessage(`◆ OpenCode — ${task.substring(0, 100)}${task.length > 100 ? "…" : ""}`, root.interfaceRole);
            OpenCode.runTask(task, (result) => {
                addFunctionOutputMessage(name, result);
                requester.makeRequest();
            });
            return;
        } else if (name === "return_result") {
            root._pendingAgentResult = args.result || "Task completed.";
            // Don't call makeRequest — markDone will pick up _pendingAgentResult and finalize
            return;
        } else if (name === "switch_to_search_mode") {
            const modelId = root.currentModelId;
            root.currentTool = "search"
            root.postResponseHook = () => { root.currentTool = "functions" }
            addFunctionOutputMessage(name, Translation.tr("Switched to search mode. Continue with the user's request."))
            requester.makeRequest();
        } else if (name === "get_shell_config") {
            const configJson = CF.ObjectUtils.toPlainObject(Config.options)
            addFunctionOutputMessage(name, JSON.stringify(configJson));
            requester.makeRequest();
        } else if (name === "set_shell_config") {
            let changes = [];
            if (args.changes && Array.isArray(args.changes)) {
                changes = args.changes;
            } else if (args.key != null && args.value != null) {
                // Legacy OpenAI/Mistral schema (single key/value) — still accepted from old chats or manual calls
                changes = [{ key: args.key, value: String(args.value) }];
            } else {
                addFunctionOutputMessage(name, Translation.tr("Invalid arguments. Must provide `changes` array (or legacy `key` and `value`)."));
                requester.makeRequest();
                return;
            }
            let results = [];
            for (const change of changes) {
                if (!change.key || !change.value) {
                    results.push(`❌ Skipped invalid change: ${JSON.stringify(change)}`);
                    continue;
                }
                try {
                    Config.setNestedValue(change.key, change.value);
                    results.push(`✓ ${change.key} = ${change.value}`);
                } catch (e) {
                    results.push(`❌ Failed to set ${change.key}: ${e}`);
                }
            }
            addFunctionOutputMessage(name, results.join("\n"));
            requester.makeRequest();
        } else if (name === "run_shell_command") {
            if (!args.command || args.command.length === 0) {
                addFunctionOutputMessage(name, Translation.tr("Invalid arguments. Must provide `command`."));
                requester.makeRequest();
                return;
            }
            // Auto-approve safe read-only commands
            const safePattern = /^(ls(\s|$)|cat\s|pwd(\s|$)|df(\s|$)|ps(\s|$)|du\s|find\s|echo\s|date(\s|$)|whoami(\s|$)|uname(\s|$)|hostname(\s|$)|free(\s|$)|uptime(\s|$)|which\s|file\s|stat\s|wc\s|head\s|tail\s|lsblk(\s|$)|lscpu(\s|$)|ip\s|nmcli\s|env(\s|$)|printenv(\s|$)|systemctl status\s)/;
            if (safePattern.test(args.command.trim())) {
                const responseMessage = createFunctionOutputMessage(name, "", false);
                const id = idForMessage(responseMessage);
                root.messageIDs = [...root.messageIDs, id];
                root.messageByID[id] = responseMessage;
                commandExecutionProc.message = responseMessage;
                commandExecutionProc.baseMessageContent = responseMessage.content;
                commandExecutionProc.shellCommand = args.command;
                commandExecutionProc.running = true;
            } else {
                const contentToAppend = `\n\n**Command execution request**\n\n\`\`\`command\n${args.command}\n\`\`\``;
                message.rawContent += contentToAppend;
                message.content += contentToAppend;
                message.functionPending = true;
            }
        } else if (name === "get_news") {
            const topic = args.topic || "top news";
            const responseMessage = createFunctionOutputMessage(name, "", false);
            const id = idForMessage(responseMessage);
            root.messageIDs = [...root.messageIDs, id];
            root.messageByID[id] = responseMessage;
            commandExecutionProc.message = responseMessage;
            commandExecutionProc.baseMessageContent = responseMessage.content;
            const escapedTopic = topic.replace(/'/g, "'\\''");
            commandExecutionProc.shellCommand = `ii-news '${escapedTopic}'`;
            commandExecutionProc.running = true;
        } else if (name === "play_music") {
            const action = (args.action || "play").toLowerCase();
            const query = args.query || "";
            const service = (args.service || "spotify").toLowerCase();
            const responseMessage = createFunctionOutputMessage(name, "", false);
            const id = idForMessage(responseMessage);
            root.messageIDs = [...root.messageIDs, id];
            root.messageByID[id] = responseMessage;
            commandExecutionProc.message = responseMessage;
            commandExecutionProc.baseMessageContent = responseMessage.content;
            if (action === "shuffle") {
                commandExecutionProc.shellCommand = `playerctl --player=${service} shuffle toggle && echo "Shuffle toggled." && playerctl --player=${service} shuffle`;
            } else if (action === "like" || action === "unlike" || action === "save" || action === "unsave") {
                // Sidebar closes before this runs (requestHideSidebars above), so wtype can reach Spotify
                const verb = (action === "unlike" || action === "unsave") ? "Unliked" : "Liked";
                commandExecutionProc.shellCommand = `SONG=$(playerctl --player=spotify metadata --format "{{artist}} - {{title}}" 2>/dev/null); hyprctl dispatch focuswindow "class:spotify" && sleep 0.5 && wtype -M alt -M shift b -m shift -m alt && echo "${verb}: $SONG"`;
            } else {
                if (!query) { addFunctionOutputMessage(name, "Invalid: query is required for play"); requester.makeRequest(); return; }
                const encodedQuery = query.replace(/ /g, "+").replace(/'/g, "'\\''");
                const escapedQuery = query.replace(/'/g, "'\\''");
                commandExecutionProc.shellCommand = `oi-task 'Play music on ${service}. Run: playerctl --player=${service} open "${service}:search:${encodedQuery}" — if ${service} is not running, launch it first with: hyprctl dispatch exec ${service} && sleep 3. The search query is: ${escapedQuery}'`;
            }
            root._pendingDesktopAction = true;
            root.requestHideSidebars();
            commandExecutionProc.running = true;
        } else if (name === "open_app") {
            const appName = args.name || "";
            if (!appName) { addFunctionOutputMessage(name, "Invalid: name is required"); requester.makeRequest(); return; }
            const responseMessage = createFunctionOutputMessage(name, "", false);
            const id = idForMessage(responseMessage);
            root.messageIDs = [...root.messageIDs, id];
            root.messageByID[id] = responseMessage;
            commandExecutionProc.message = responseMessage;
            commandExecutionProc.baseMessageContent = responseMessage.content;
            const escapedName = appName.replace(/'/g, "'\\''");
            commandExecutionProc.shellCommand = `oi-task 'Launch the application: ${escapedName}'`;
            commandExecutionProc.currentToolName = name;
            root._pendingDesktopAction = true;
            root.requestHideSidebars();
            commandExecutionProc.running = true;
        } else if (name === "run_task") {
            const task = args.task || "";
            if (!task) {
                addFunctionOutputMessage(name, "Invalid: task is required");
                requester.makeRequest();
                return;
            }
            const responseMessage = createFunctionOutputMessage(name, "", false);
            const id = idForMessage(responseMessage);
            root.messageIDs = [...root.messageIDs, id];
            root.messageByID[id] = responseMessage;
            commandExecutionProc.message = responseMessage;
            commandExecutionProc.baseMessageContent = responseMessage.content;
            // Escape single quotes in task for shell argument
            const escapedTask = task.replace(/'/g, "'\\''");
            commandExecutionProc.shellCommand = `oi-task '${escapedTask}'`;
            commandExecutionProc.currentToolName = "run_task";
            root._pendingDesktopAction = true;
            root.requestHideSidebars();
            commandExecutionProc.running = true;
        } else if (name === "web_search") {
            if (!args.query || args.query.length === 0) {
                addFunctionOutputMessage(name, Translation.tr("Invalid arguments. Must provide `query`."));
                requester.makeRequest();
                return;
            }
            const responseMessage = createFunctionOutputMessage(name, "", false);
            const id = idForMessage(responseMessage);
            root.messageIDs = [...root.messageIDs, id];
            root.messageByID[id] = responseMessage;
            commandExecutionProc.message = responseMessage;
            commandExecutionProc.baseMessageContent = responseMessage.content;
            commandExecutionProc.currentToolName = "web_search";
            const escapedQuery = args.query.replace(/'/g, "'\\''");
            commandExecutionProc.shellCommand = `bash ~/.config/quickshell/scripts/ai-search.sh '${escapedQuery}'`;
            commandExecutionProc.running = true;
        } else if (name === "remember") {
            const content = args.content || "";
            if (!content) {
                addFunctionOutputMessage(name, "Invalid: content is required");
                requester.makeRequest();
                return;
            }
            // Also keep file-based memory for system prompt injection
            const existing = memoryFileView.text() || "";
            const timestamp = new Date().toISOString().split("T")[0];
            const newEntry = existing.trim().length > 0
                ? `${existing.trim()}\n- [${timestamp}] ${content}`
                : `- [${timestamp}] ${content}`;
            memoryFileView.setText(newEntry);
            // Store in SQLite with embedding
            const memMsg = createFunctionOutputMessage(name, "", false);
            const memId = idForMessage(memMsg);
            root.messageIDs = [...root.messageIDs, memId];
            root.messageByID[memId] = memMsg;
            commandExecutionProc.message = memMsg;
            commandExecutionProc.baseMessageContent = memMsg.content;
            commandExecutionProc.shellCommand = `python3 "${Directories.aiMemoryPath.replace('memory.md', 'memory.py')}" store user ${JSON.stringify(content)} 2>&1`;
            commandExecutionProc.running = true;
            return;
        } else if (name === "create_todo") {
            const title = args.title || "";
            if (!title) {
                addFunctionOutputMessage(name, "Invalid: title is required");
                requester.makeRequest();
                return;
            }
            Todo.addTask(title);
            addFunctionOutputMessage(name, `To-do added: "${title}"`);
            requester.makeRequest();
        } else if (name === "get_system_logs") {
            const lines = Math.min(parseInt(args.lines) || 50, 200);
            const filter = args.filter ? `--unit=${args.filter}` : "";
            logsProc.message = message;
            logsProc.command = ["bash", "-c", `journalctl -n ${lines} ${filter} --no-pager --output=short-monotonic 2>&1`];
            logsProc.running = true;
        } else if (name === "control_media") {
            const action = args.action || "status";
            let cmd;
            switch (action) {
                case "play":     cmd = "playerctl play 2>&1 && echo 'Playing'"; break;
                case "pause":    cmd = "playerctl pause 2>&1 && echo 'Paused'"; break;
                case "toggle":   cmd = "playerctl play-pause 2>&1 && playerctl status 2>&1"; break;
                case "next":     cmd = "playerctl next 2>&1 && echo 'Skipped to next'"; break;
                case "previous": cmd = "playerctl previous 2>&1 && echo 'Went to previous'"; break;
                default:         cmd = "playerctl metadata --format '{{artist}} - {{title}} [{{status}}]' 2>&1 || echo 'No media player found'";
            }
            const mediaMsg = createFunctionOutputMessage(name, "", false);
            const mediaId = idForMessage(mediaMsg);
            root.messageIDs = [...root.messageIDs, mediaId];
            root.messageByID[mediaId] = mediaMsg;
            commandExecutionProc.message = mediaMsg;
            commandExecutionProc.baseMessageContent = mediaMsg.content;
            commandExecutionProc.shellCommand = cmd;
            commandExecutionProc.running = true;
        } else if (name === "control_hyprland") {
            const dispatch = args.dispatch || "";
            if (!dispatch) {
                addFunctionOutputMessage(name, "Invalid: dispatch is required");
                requester.makeRequest();
                return;
            }
            const hyprMsg = createFunctionOutputMessage(name, "", false);
            const hyprId = idForMessage(hyprMsg);
            root.messageIDs = [...root.messageIDs, hyprId];
            root.messageByID[hyprId] = hyprMsg;
            commandExecutionProc.message = hyprMsg;
            commandExecutionProc.baseMessageContent = hyprMsg.content;
            commandExecutionProc.shellCommand = `hyprctl dispatch ${dispatch} 2>&1`;
            commandExecutionProc.running = true;
        } else if (name === "forget_memory") {
            const content = args.content || "";
            if (!content) {
                addFunctionOutputMessage(name, "Invalid: content is required");
                requester.makeRequest();
                return;
            }
            // Also remove from file-based memory
            const existing = memoryFileView.text() || "";
            const filtered = existing.split("\n").filter(line => !line.toLowerCase().includes(content.toLowerCase()));
            memoryFileView.setText(filtered.join("\n"));
            // Delete from SQLite by text match
            const fmMsg = createFunctionOutputMessage(name, "", false);
            const fmId = idForMessage(fmMsg);
            root.messageIDs = [...root.messageIDs, fmId];
            root.messageByID[fmId] = fmMsg;
            commandExecutionProc.message = fmMsg;
            commandExecutionProc.baseMessageContent = fmMsg.content;
            commandExecutionProc.shellCommand = `python3 -c "
import sqlite3, sys
db = '${Directories.aiMemoryPath.replace('memory.md', 'memory.db')}'
content = sys.argv[1].lower()
conn = sqlite3.connect(db)
rows = conn.execute('SELECT id, text FROM memories').fetchall()
deleted = 0
for row in rows:
    if content in row[1].lower():
        conn.execute('DELETE FROM memories WHERE id=?', (row[0],))
        deleted += 1
conn.commit()
conn.close()
print(f'Removed {deleted} matching memories for: {sys.argv[1]}')
" ${JSON.stringify(content)} 2>&1`;
            commandExecutionProc.running = true;
            return;
        } else if (name === "export_chat") {
            const ts = new Date().toISOString().replace(/[:.]/g, "-").substring(0, 19);
            const filename = (args.filename || ts).replace(/[^a-zA-Z0-9_\-]/g, "_");
            const lines = root.messageIDs.map(id => {
                const msg = root.messageByID[id];
                if (msg.role === root.interfaceRole) return "";
                const speaker = msg.role === "user" ? "You" : "AI";
                return `## ${speaker}\n\n${msg.rawContent}\n`;
            }).filter(l => l.length > 0);
            const markdown = `# AI Chat Export\n\n${lines.join("\n---\n\n")}`;
            chatExportFile.path = Qt.resolvedUrl(`${Directories.home}/Documents/${filename}.md`);
            chatExportFile.setText(markdown);
            addFunctionOutputMessage(name, `Chat exported to ~/Documents/${filename}.md`);
            requester.makeRequest();
        } else if (name === "control_system") {
            const action = args.action || "";
            const value = args.value || "10";
            let cmd;
            switch (action) {
                case "volume_up":         cmd = `wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ && wpctl get-volume @DEFAULT_AUDIO_SINK@`; break;
                case "volume_down":       cmd = `wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- && wpctl get-volume @DEFAULT_AUDIO_SINK@`; break;
                case "volume_set":        cmd = `wpctl set-volume @DEFAULT_AUDIO_SINK@ ${parseInt(value) / 100} && wpctl get-volume @DEFAULT_AUDIO_SINK@`; break;
                case "volume_get":        cmd = `wpctl get-volume @DEFAULT_AUDIO_SINK@`; break;
                case "brightness_up":     cmd = `brightnessctl set 10%+ && echo "Brightness: $(brightnessctl get)/$(brightnessctl max)"`; break;
                case "brightness_down":   cmd = `brightnessctl set 10%- && echo "Brightness: $(brightnessctl get)/$(brightnessctl max)"`; break;
                case "brightness_set":    cmd = `brightnessctl set ${value}% && echo "Brightness: $(brightnessctl get)/$(brightnessctl max)"`; break;
                case "brightness_get":    cmd = `echo "Brightness: $(brightnessctl get)/$(brightnessctl max)"`; break;
                case "power_profile_get": cmd = `powerprofilesctl get 2>/dev/null || echo 'powerprofilesctl not available'`; break;
                case "power_profile_set": cmd = `powerprofilesctl set ${value} 2>/dev/null && echo "Power profile: ${value}"` ; break;
                default: cmd = `echo 'Unknown action: ${action}'`;
            }
            const sysMsg = createFunctionOutputMessage(name, "", false);
            const sysId = idForMessage(sysMsg);
            root.messageIDs = [...root.messageIDs, sysId];
            root.messageByID[sysId] = sysMsg;
            commandExecutionProc.message = sysMsg;
            commandExecutionProc.baseMessageContent = sysMsg.content;
            commandExecutionProc.shellCommand = cmd;
            commandExecutionProc.running = true;
        } else if (name === "kill_process") {
            const target = args.process || "";
            if (!target) {
                addFunctionOutputMessage(name, "Invalid: process is required");
                requester.makeRequest();
                return;
            }
            const killCmd = `pkill -f "${target.replace(/"/g, '\\"')}" 2>&1 && echo "Killed: ${target}" || echo "No process found: ${target}"`;
            message.functionCall.args.command = killCmd;
            const contentToAppend = `\n\n**Kill process request**\n\n\`\`\`command\n${killCmd}\n\`\`\``;
            message.rawContent += contentToAppend;
            message.content += contentToAppend;
            message.functionPending = true;
        } else if (name === "take_screenshot") {
            const screenshotPath = `${Directories.aiSttTemp}/screenshot.png`;
            const dest = CF.FileUtils.trimFileProtocol(screenshotPath);
            screenshotProc.targetPath = dest;
            screenshotProc.message = message;
            // Capture all monitors, downscale to 1920px wide, output metadata
            const cmd = `
DEST="${dest}"
MONITORS=$(hyprctl monitors -j 2>/dev/null | tr -d '\n' || echo '[]')
CURSOR=$(hyprctl cursorpos 2>/dev/null || echo "0, 0")
CX=$(echo "\${CURSOR}" | awk '{gsub(/,/,"",$1); print $1}')
CY=$(echo "\${CURSOR}" | awk '{print $2}')
MON_NAME=$(MONITORS="$MONITORS" python3 -c '
import json,os,sys,subprocess
mons=json.loads(os.environ.get("MONITORS","[]"))
try:
    aw=json.loads(subprocess.run(["hyprctl","activewindow","-j"],capture_output=True,text=True).stdout or "{}")
    mid=aw.get("monitor",-1)
    if mid>=0:
        for m in mons:
            if m.get("id")==mid: print(m.get("name","")); sys.exit()
except: pass
for m in mons:
    if m.get("focused"): print(m.get("name","")); sys.exit()
if mons: print(mons[0].get("name",""))
' 2>/dev/null || echo "")
MON_NAME=$(echo "$MON_NAME" | head -n1 | tr -d '\r')
if [ -n "$MON_NAME" ]; then
    grim -o "$MON_NAME" "$DEST" 2>&1 || exit 1
else
    grim "$DEST" 2>&1 || exit 1
fi
META=$(DEST=$DEST CX=\${CX} CY=\${CY} MONITORS="$MONITORS" MON_NAME="$MON_NAME" python3 2>&1 << 'PYEOF'
from PIL import Image, ImageDraw, ImageFont
import os, json
dest = os.environ['DEST']
cx   = int(os.environ.get('CX', 0))
cy   = int(os.environ.get('CY', 0))
img  = Image.open(dest).convert('RGBA')
W, H = img.size
cols = 12
rows = max(5, round(cols * H / W))
cell_w = W // cols
cell_h = H // rows
overlay = Image.new('RGBA', (W, H), (0,0,0,0))
draw = ImageDraw.Draw(overlay)
font = None
for p in ['/usr/share/fonts/TTF/DejaVuSans-Bold.ttf',
          '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
          '/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf',
          '/usr/share/fonts/noto/NotoSans-Bold.ttf']:
    try: font = ImageFont.truetype(p, max(14, min(28, cell_h//8))); break
    except: pass
if font is None: font = ImageFont.load_default()
for row in range(rows):
    for col in range(cols):
        n  = row * cols + col + 1
        x1 = col * cell_w; y1 = row * cell_h
        x2 = x1 + cell_w - 1; y2 = y1 + cell_h - 1
        ccx = x1 + cell_w // 2; ccy = y1 + cell_h // 2
        draw.rectangle([x1,y1,x2,y2], outline=(255,255,255,60), width=1)
        t = str(n)
        bb = draw.textbbox((ccx,ccy), t, font=font, anchor='mm')
        draw.rectangle([bb[0]-3,bb[1]-3,bb[2]+3,bb[3]+3], fill=(0,0,0,150))
        draw.text((ccx,ccy), t, fill=(255,255,255,210), font=font, anchor='mm')
monitors = json.loads(os.environ.get('MONITORS','[]'))
mon_name = os.environ.get('MON_NAME','')
off_x, off_y = 0, 0
if mon_name:
    for m in monitors:
        if m.get('name') == mon_name:
            off_x = m.get('x', 0); off_y = m.get('y', 0); break
else:
    off_x = min((m.get('x',0) for m in monitors), default=0)
    off_y = min((m.get('y',0) for m in monitors), default=0)
cx_img = cx - off_x; cy_img = cy - off_y
r = 18
if 0 <= cx_img < W and 0 <= cy_img < H:
    draw.ellipse([cx_img-r,cy_img-r,cx_img+r,cy_img+r], outline=(255,60,60,230), width=3)
    draw.line([cx_img-26,cy_img,cx_img+26,cy_img], fill=(255,60,60,230), width=2)
    draw.line([cx_img,cy_img-26,cx_img,cy_img+26], fill=(255,60,60,230), width=2)
cx_in_bounds = 0 <= cx_img < W and 0 <= cy_img < H
composite = Image.alpha_composite(img, overlay).convert('RGB')
MAX_W = 1920
sf = 1.0
if W > MAX_W:
    sf = W / MAX_W
    new_h = round(H * MAX_W / W)
    composite = composite.resize((MAX_W, new_h), Image.LANCZOS)
    W_out, H_out = MAX_W, new_h
else:
    W_out, H_out = W, H
composite.save(dest)
cx_s = round(cx_img / sf) if cx_in_bounds else -1
cy_s = round(cy_img / sf) if cx_in_bounds else -1
print(f"GRID_META:{W_out}:{H_out}:{cols}:{rows}")
print(f"SCREENSHOT_OFFSET:{off_x}:{off_y}")
print(f"IMG_SCALE:{sf:.6f}")
print(f"CURSOR_S:{cx_s}:{cy_s}")
PYEOF
)
SS_OFFSET_X=$(echo "\${META}" | grep "^SCREENSHOT_OFFSET:" | cut -d: -f2)
SS_OFFSET_Y=$(echo "\${META}" | grep "^SCREENSHOT_OFFSET:" | cut -d: -f3)
SS_OFFSET_X=\${SS_OFFSET_X:-0}
SS_OFFSET_Y=\${SS_OFFSET_Y:-0}
GRID_LINE=$(echo "\${META}" | grep "^GRID_META:")
IMG_W=$(echo "\${GRID_LINE}" | cut -d: -f2)
IMG_H=$(echo "\${GRID_LINE}" | cut -d: -f3)
GRID_COLS=$(echo "\${GRID_LINE}" | cut -d: -f4)
GRID_ROWS=$(echo "\${GRID_LINE}" | cut -d: -f5)
SCALE=$(echo "\${META}" | grep "^IMG_SCALE:" | cut -d: -f2)
SCALE=\${SCALE:-1.0}
CURSOR_LINE=$(echo "\${META}" | grep "^CURSOR_S:")
CURSOR_SS_X=$(echo "\${CURSOR_LINE}" | cut -d: -f2)
CURSOR_SS_Y=$(echo "\${CURSOR_LINE}" | cut -d: -f3)
CURSOR_SS_X=\${CURSOR_SS_X:--1}
CURSOR_SS_Y=\${CURSOR_SS_Y:--1}
echo "CURSOR_POS:\${CURSOR_SS_X}:\${CURSOR_SS_Y}"
echo "GRID:\${GRID_COLS}:\${GRID_ROWS}"
echo "IMAGE_SIZE:\${IMG_W}:\${IMG_H}"
echo "IMAGE_SCALE:\${SCALE}"
echo "SCREENSHOT_OFFSET:\${SS_OFFSET_X}:\${SS_OFFSET_Y}"
`;
            root.requestHideSidebars();
            const _cmd = cmd;
            sidebarHideTimer.pendingAction = () => {
                root._pendingVisionFollowUpKind = "explicit";
                screenshotProc.command = ["bash", "-c", _cmd];
                screenshotProc.running = true;
            };
            sidebarHideTimer.restart();
        } else if (name === "launch_app") {
            const app = args.app || "";
            if (!app) { addFunctionOutputMessage(name, "Invalid: app is required"); requester.makeRequest(); return; }
            const launchMsg = createFunctionOutputMessage(name, "", false);
            const launchId = idForMessage(launchMsg);
            root.messageIDs = [...root.messageIDs, launchId];
            root.messageByID[launchId] = launchMsg;
            commandExecutionProc.message = launchMsg;
            commandExecutionProc.baseMessageContent = launchMsg.content;
            const escapedApp = app.replace(/'/g, "'\\''");
            commandExecutionProc.shellCommand = `oi-task 'Launch the application: ${escapedApp}'`;
            commandExecutionProc.currentToolName = name;
            commandExecutionProc.running = true;
        } else if (name === "open_file") {
            const path = args.path || args.url || args.uri || "";
            if (!path) { addFunctionOutputMessage(name, "Invalid: path is required"); requester.makeRequest(); return; }
            Quickshell.execDetached(["xdg-open", path]);
            const isUrl = /^https?:\/\//i.test(path);
            const hint = isUrl ? `\nNote: The page was only opened in the browser. To interact with it (click buttons, add to cart, fill forms), use execute_js or call_agent(desktop).` : "";
            addFunctionOutputMessage(name, `Opened: ${path}${hint}`);
            requester.makeRequest();
        } else if (name === "get_notifications") {
            const notifs = Notifications.list;
            if (!notifs || notifs.length === 0) {
                addFunctionOutputMessage(name, "No notifications.");
            } else {
                const lines = notifs.slice().reverse().map(n => {
                    const age = Math.round((Date.now() - n.time) / 60000);
                    const ageStr = age < 1 ? "just now" : `${age}m ago`;
                    const replyTag = n.hasReply ? " [can_reply]" : "";
                    return `[id:${n.notificationId}] ${n.appName} | ${n.summary}${n.body ? ": " + n.body : ""} (${ageStr})${replyTag}`;
                });
                addFunctionOutputMessage(name, lines.join("\n"));
            }
            requester.makeRequest();
        } else if (name === "reply_notification") {
            const notifId = parseInt(args.notification_id);
            const replyText = args.message || "";
            if (!notifId || !replyText) {
                addFunctionOutputMessage(name, "Error: notification_id and message are required.");
            } else {
                Notifications.sendReply(notifId, replyText);
                addFunctionOutputMessage(name, `Reply sent to notification ${notifId}.`);
            }
            requester.makeRequest();
        } else if (name === "send_message") {
            if (root._sendMessageIssuedThisTurn && !root.activeAgentType) {
                addFunctionOutputMessage(name,
                    "[Gate] send_message was already started this turn. Do NOT call send_message again. Tell the user the browser automation is running or finished and offer to help with something else.");
                requester.makeRequest();
                return;
            }
            const to = args.to || "";
            const msg = args.message || "";
            const platform = (args.platform || "").toLowerCase();
            if (!to || !msg || !platform) {
                addFunctionOutputMessage(name, `Error: missing required args. Got: to="${to}", message="${msg}", platform="${platform}". Retry with all three filled in.`);
                requester.makeRequest();
                return;
            }
            const platformUrls = {
                "facebook messenger": "https://www.messenger.com",
                "messenger": "https://www.messenger.com",
                "telegram": "https://web.telegram.org",
                "discord": "https://discord.com/app",
                "whatsapp": "https://web.whatsapp.com",
                "instagram": "https://www.instagram.com/direct/inbox/",
            };
            const platformEntry = Object.entries(platformUrls).find(([k]) => platform.includes(k));
            const platformUrl = platformEntry ? platformEntry[1] : null;
            if (platformUrl) { try {
                const automationJS =
                    `(function(){` +
                    `function S(ms){return new Promise(r=>setTimeout(r,ms));}` +
                    `function setVal(el,v){const p=Object.getPrototypeOf(el);const d=Object.getOwnPropertyDescriptor(p,"value");` +
                    `if(d&&d.set){d.set.call(el,v);}else{el.value=v;}` +
                    `el.dispatchEvent(new Event("input",{bubbles:true}));el.dispatchEvent(new Event("change",{bubbles:true}));}` +
                    `async function go(){` +
                    `document.title="[AI]start";` +
                    `const search=document.querySelector("input[aria-label*='Search' i],input[placeholder*='Search' i],input[type='search']");` +
                    `if(!search){document.title="[AI]no-search";return;}` +
                    `search.click();search.focus();setVal(search,${JSON.stringify(to)});` +
                    `document.title="[AI]searching";await S(3000);` +
                    `const allResults=[...document.querySelectorAll("[role='option'],[role='listitem'],[data-testid*='row']")];` +
                    `const resultEl=allResults.find(el=>el.querySelector("img"));` +
                    `if(!resultEl){document.title="[AI]no-result:"+allResults.length;return;}` +
                    `const link=resultEl.querySelector("a")||resultEl.closest("a");` +
                    `if(link){link.click();}else{resultEl.click();}` +
                    `await S(4000);` +
                    `const boxes=[...document.querySelectorAll("div[contenteditable='true']")];` +
                    `const msgBox=boxes.filter(e=>!(e.getAttribute("aria-label")||"").toLowerCase().includes("search")).pop();` +
                    `if(!msgBox){document.title="[AI]no-msgbox:"+boxes.length;return;}` +
                    `msgBox.focus();msgBox.click();await S(500);` +
                    `document.execCommand("selectAll",false,null);` +
                    `document.execCommand("insertText",false,${JSON.stringify(msg)});` +
                    `await S(600);` +
                    `const sendBtn=document.querySelector("[aria-label='Send']");` +
                    `if(sendBtn){sendBtn.click();document.title="[AI]sent-btn";}` +
                    `else{msgBox.dispatchEvent(new KeyboardEvent("keydown",{key:"Enter",code:"Enter",bubbles:true,cancelable:true}));document.title="[AI]sent-key";}` +
                    `}go();})()`;
                const shellSafeJS = automationJS.replace(/'/g, "'\\''");
                const urlLit = JSON.stringify(platformUrl);
                const clipboardOnly = Config.options.ai.sendMessageClipboardOnly === true;
                const script = clipboardOnly
                    ? `printf '%s' '${shellSafeJS}' | wl-copy\n` +
                      `(firefox ${urlLit} >/dev/null 2>&1 &)\n` +
                      `notify-send -a "Quickshell AI" "send_message" "Script copied. In Firefox: F12 → Console → Ctrl+V → Enter. Tab title shows [AI]… status."`
                    : `printf '%s' '${shellSafeJS}' | wl-copy\n` +
                      `(firefox ${urlLit} >/dev/null 2>&1 &)\n` +
                      `sleep 2\n` +
                      `qs -p ~/.config/quickshell/ii ipc call sidebarLeft close 2>/dev/null\n` +
                      `sleep 0.5\n` +
                      `for _try in 1 2 3; do\n` +
                      `  hyprctl dispatch focuswindow "class:firefox" 2>/dev/null && break\n` +
                      `  sleep 0.25\n` +
                      `done\n` +
                      `sleep 8\n` +
                      `hyprctl dispatch focuswindow "class:firefox" 2>/dev/null\n` +
                      `sleep 0.35\n` +
                      `wtype -k F12\n` +
                      `sleep 1.8\n` +
                      `wtype -M ctrl -k v -m ctrl\n` +
                      `sleep 0.3\n` +
                      `wtype -k Return\n` +
                      `sleep 6\n` +
                      `wtype -k F12` ;
                Quickshell.execDetached(["bash", "-c", script]);
                root._sendMessageIssuedThisTurn = true;
                addFunctionOutputMessage(name,
                    clipboardOnly
                        ? `Script on clipboard; ${platform} opened. User pastes in Firefox console (F12). Do NOT call send_message again.`
                        : `Browser automation started for ${to} on ${platform}. Do NOT call send_message again for this request. Reply briefly that the user should check the tab when automation finishes.`);
                requester.makeRequest();
            } catch(e) { addFunctionOutputMessage(name, "Error in send_message: " + e); requester.makeRequest(); }
            } else {
                addFunctionOutputMessage(name, `Unknown platform: '${platform}'. Supported: facebook messenger, telegram, discord, whatsapp, instagram.`);
                requester.makeRequest();
            }
        } else if (name === "notify") {
            const title = args.title || "AI Assistant";
            const body = args.body || "";
            Quickshell.execDetached(["notify-send", title, body]);
            addFunctionOutputMessage(name, `Notification sent: "${title}"`);
            requester.makeRequest();
        } else if (name === "set_timer") {
            const seconds = Math.max(1, parseInt(args.seconds) || 60);
            const label = args.label || "Timer";
            Quickshell.execDetached(["bash", "-c",
                `(sleep ${seconds} && notify-send "Timer: ${label.replace(/"/g, '\\"')}" "Time's up!" --urgency=normal) &`
            ]);
            addFunctionOutputMessage(name, `Timer set: ${label} in ${seconds}s`);
            requester.makeRequest();
        } else if (name === "calculate") {
            const expression = args.expression || "";
            if (!expression) { addFunctionOutputMessage(name, "Invalid: expression is required"); requester.makeRequest(); return; }
            const calcMsg = createFunctionOutputMessage(name, "", false);
            const calcId = idForMessage(calcMsg);
            root.messageIDs = [...root.messageIDs, calcId];
            root.messageByID[calcId] = calcMsg;
            commandExecutionProc.message = calcMsg;
            commandExecutionProc.baseMessageContent = calcMsg.content;
            commandExecutionProc.shellCommand = `python3 -c "import math; print(${expression.replace(/"/g, '\\"')})" 2>&1`;
            commandExecutionProc.running = true;
        } else if (name === "pick_color") {
            const colorMsg = createFunctionOutputMessage(name, "", false);
            const colorId = idForMessage(colorMsg);
            root.messageIDs = [...root.messageIDs, colorId];
            root.messageByID[colorId] = colorMsg;
            commandExecutionProc.message = colorMsg;
            commandExecutionProc.baseMessageContent = colorMsg.content;
            commandExecutionProc.shellCommand = `hyprpicker 2>/dev/null || echo 'hyprpicker not installed'`;
            commandExecutionProc.running = true;
        } else if (name === "manage_notes") {
            const action = args.action || "list";
            const content = args.content || "";
            const tags = args.tags || "";
            const mnMsg = createFunctionOutputMessage(name, "", false);
            const mnId = idForMessage(mnMsg);
            root.messageIDs = [...root.messageIDs, mnId];
            root.messageByID[mnId] = mnMsg;
            commandExecutionProc.message = mnMsg;
            commandExecutionProc.baseMessageContent = mnMsg.content;
            if (action === "list" || action === "read") {
                commandExecutionProc.shellCommand = `python3 "${Directories.aiMemoryPath.replace('memory.md', 'memory.py')}" list 50 2>&1`;
            } else if (action === "add") {
                if (!content) { addFunctionOutputMessage(name, "Invalid: content is required for add"); requester.makeRequest(); return; }
                commandExecutionProc.shellCommand = `python3 "${Directories.aiMemoryPath.replace('memory.md', 'memory.py')}" store notes ${JSON.stringify(content)} ${JSON.stringify(tags)} 2>&1`;
            } else if (action === "clear") {
                commandExecutionProc.shellCommand = `python3 "${Directories.aiMemoryPath.replace('memory.md', 'memory.py')}" clear 2>&1`;
            } else {
                addFunctionOutputMessage(name, `Unknown action: ${action}. Use 'list', 'add', or 'clear'.`);
                requester.makeRequest();
                return;
            }
            commandExecutionProc.running = true;
            return;
        } else if (name === "search_memory") {
            const query = args.query || "";
            if (!query) { addFunctionOutputMessage(name, "Invalid: query is required"); requester.makeRequest(); return; }
            const limit = Math.min(parseInt(args.limit) || 5, 20);
            const smMsg = createFunctionOutputMessage(name, "", false);
            const smId = idForMessage(smMsg);
            root.messageIDs = [...root.messageIDs, smId];
            root.messageByID[smId] = smMsg;
            commandExecutionProc.message = smMsg;
            commandExecutionProc.baseMessageContent = smMsg.content;
            commandExecutionProc.shellCommand = `python3 "${Directories.aiMemoryPath.replace('memory.md', 'memory.py')}" search ${JSON.stringify(query)} ${limit} 2>&1`;
            commandExecutionProc.running = true;
            return;
        } else if (name === "schedule_task") {
            const action = args.action || "list";
            const stMsg = createFunctionOutputMessage(name, "", false);
            const stId = idForMessage(stMsg);
            root.messageIDs = [...root.messageIDs, stId];
            root.messageByID[stId] = stMsg;
            commandExecutionProc.message = stMsg;
            commandExecutionProc.baseMessageContent = stMsg.content;
            if (action === "add") {
                const cron = args.cron || "";
                const prompt = args.prompt || "";
                if (!cron || !prompt) { addFunctionOutputMessage(name, "Invalid: cron and prompt required for add"); requester.makeRequest(); return; }
                commandExecutionProc.shellCommand = `python3 "${Directories.aiMemoryPath.replace('memory.md', 'memory.py')}" schedule_add ${JSON.stringify(cron)} ${JSON.stringify(prompt)} 2>&1`;
            } else if (action === "list") {
                commandExecutionProc.shellCommand = `python3 "${Directories.aiMemoryPath.replace('memory.md', 'memory.py')}" schedule_list 2>&1`;
            } else if (action === "delete") {
                const taskId = parseInt(args.id) || 0;
                if (!taskId) { addFunctionOutputMessage(name, "Invalid: id required for delete"); requester.makeRequest(); return; }
                commandExecutionProc.shellCommand = `python3 "${Directories.aiMemoryPath.replace('memory.md', 'memory.py')}" schedule_delete ${taskId} 2>&1`;
            } else {
                addFunctionOutputMessage(name, `Unknown action: ${action}. Use 'add', 'list', or 'delete'.`);
                requester.makeRequest();
                return;
            }
            commandExecutionProc.running = true;
            return;
        } else if (name === "capture_region") {
            const capPath = CF.FileUtils.trimFileProtocol(`${Directories.aiSttTemp}/region_capture.png`);
            regionCaptureProc.targetPath = capPath;
            regionCaptureProc.command = ["bash", "-c",
                `region=$(slurp 2>/dev/null) && [ -n "$region" ] && grim -g "$region" "${capPath}" && echo "ok" || echo "cancelled"`
            ];
            regionCaptureProc.running = true;
        } else if (name === "ocr_region") {
            const ocrImg = CF.FileUtils.trimFileProtocol(`${Directories.aiSttTemp}/ocr_capture.png`);
            const ocrOut = CF.FileUtils.trimFileProtocol(`${Directories.aiSttTemp}/ocr_out`);
            const ocrMsg = createFunctionOutputMessage(name, "", false);
            const ocrId = idForMessage(ocrMsg);
            root.messageIDs = [...root.messageIDs, ocrId];
            root.messageByID[ocrId] = ocrMsg;
            commandExecutionProc.message = ocrMsg;
            commandExecutionProc.baseMessageContent = ocrMsg.content;
            commandExecutionProc.shellCommand = `region=$(slurp 2>/dev/null) && [ -n "$region" ] && grim -g "$region" "${ocrImg}" && tesseract "${ocrImg}" "${ocrOut}" 2>/dev/null && cat "${ocrOut}.txt" || echo 'Cancelled or missing tools (need: slurp, grim, tesseract)'`;
            commandExecutionProc.running = true;
        } else if (name === "speak") {
            const raw = args.text || "";
            if (!raw) { addFunctionOutputMessage(name, "Invalid: text is required"); requester.makeRequest(); return; }
            const escaped = raw.replace(/'/g, "'\\''");
            Quickshell.execDetached(["bash", "-c",
                `espeak-ng '${escaped}' 2>/dev/null || espeak '${escaped}' 2>/dev/null`
            ]);
            addFunctionOutputMessage(name, `Speaking: "${raw.substring(0, 60)}${raw.length > 60 ? "..." : ""}"`);
            requester.makeRequest();
        } else if (name === "read_clipboard_image") {
            const clipPath = CF.FileUtils.trimFileProtocol(`${Directories.aiSttTemp}/clipboard_image.png`);
            clipboardImageProc.targetPath = clipPath;
            clipboardImageProc.command = ["bash", "-c", `wl-paste --type image/png > "${clipPath}" 2>&1 && echo "saved" || echo "no_image"`];
            clipboardImageProc.running = true;
        } else if (name === "click_at") {
            const imgW   = root.lastScreenshotWidth  > 0 ? root.lastScreenshotWidth  : 1920;
            const imgH   = root.lastScreenshotHeight > 0 ? root.lastScreenshotHeight : 1080;
            const scale  = root.lastScreenshotScale  > 0 ? root.lastScreenshotScale  : 1.0;
            const rawX   = parseFloat(args.x) || 0;
            const rawY   = parseFloat(args.y) || 0;
            const button = (args.button || "left").toLowerCase();
            const isDouble = args.double === true;
            const mods = (args.modifiers || "").toLowerCase().trim();
            // Scale coords from screenshot space back to real display space
            const nativeW = Math.round(imgW * scale);
            const nativeH = Math.round(imgH * scale);
            const sx = Math.max(0, Math.min(Math.round(rawX * scale), nativeW)) + root.lastScreenshotOffsetX;
            const sy = Math.max(0, Math.min(Math.round(rawY * scale), nativeH)) + root.lastScreenshotOffsetY;
            const ydoBtn = button === "right" ? "3" : button === "middle" ? "2" : "1";
            const modLabel = mods ? ` [${mods}]` : "";
            const dblLabel = isDouble ? " double" : "";
            root._lastClickInfo = `click_at${dblLabel}${modLabel} (${rawX}, ${rawY})`;
            addFunctionOutputMessage(name, `${isDouble ? "Double-clicking" : "Clicking"}${modLabel} (${rawX}, ${rawY}) → screen (${sx}, ${sy})`);
            // Build modifier key press/release commands
            const modMap = { "ctrl": "29", "shift": "42", "alt": "56", "super": "125" };
            const modParts = mods ? mods.split("+").filter(m => modMap[m]) : [];
            const modDown = modParts.map(m => `ydotool key ${modMap[m]}:1`).join(" && ");
            const modUp = modParts.reverse().map(m => `ydotool key ${modMap[m]}:0`).join(" && ");
            const clickPart = isDouble
                ? `ydotool click --button-up --button-down ${ydoBtn} && sleep 0.05 && ydotool click --button-up --button-down ${ydoBtn}`
                : `ydotool click --button-up --button-down ${ydoBtn}`;
            // Move mouse and click, with optional modifiers and double-click
            let clickCmd = `sleep 0.15 && ydotool mousemove --absolute -x ${sx} -y ${sy}`;
            if (modDown) clickCmd += ` && ${modDown}`;
            clickCmd += ` && ${clickPart}`;
            if (modUp) clickCmd += ` && ${modUp}`;
            root.requestHideSidebars();
            Quickshell.execDetached(["bash", "-c", clickCmd]);
            // After click, auto-take a fresh screenshot so the model can see the result
            Qt.callLater(() => {
                root._pendingVisionFollowUpKind = "followup";
                const screenshotPath = `${Directories.aiSttTemp}/screenshot.png`;
                const dest = CF.FileUtils.trimFileProtocol(screenshotPath);
                screenshotProc.targetPath = dest;
                const cmd = `
DEST="${dest}"
MONITORS=$(hyprctl monitors -j 2>/dev/null | tr -d '\n' || echo '[]')
CURSOR=$(hyprctl cursorpos 2>/dev/null || echo "0, 0")
CX=$(echo "\${CURSOR}" | awk '{gsub(/,/,"",$1); print $1}')
CY=$(echo "\${CURSOR}" | awk '{print $2}')
MON_NAME=$(MONITORS="$MONITORS" python3 -c '
import json,os,sys,subprocess
mons=json.loads(os.environ.get("MONITORS","[]"))
try:
    aw=json.loads(subprocess.run(["hyprctl","activewindow","-j"],capture_output=True,text=True).stdout or "{}")
    mid=aw.get("monitor",-1)
    if mid>=0:
        for m in mons:
            if m.get("id")==mid: print(m.get("name","")); sys.exit()
except: pass
for m in mons:
    if m.get("focused"): print(m.get("name","")); sys.exit()
if mons: print(mons[0].get("name",""))
' 2>/dev/null || echo "")
MON_NAME=$(echo "$MON_NAME" | head -n1 | tr -d '\r')
if [ -n "$MON_NAME" ]; then
    grim -o "$MON_NAME" "$DEST" 2>&1 || exit 1
else
    grim "$DEST" 2>&1 || exit 1
fi
META=$(DEST=$DEST CX=\${CX} CY=\${CY} MONITORS="$MONITORS" MON_NAME="$MON_NAME" python3 2>&1 << 'PYEOF'
from PIL import Image, ImageDraw, ImageFont
import os, json
dest = os.environ['DEST']
cx   = int(os.environ.get('CX', 0))
cy   = int(os.environ.get('CY', 0))
img  = Image.open(dest).convert('RGBA')
W, H = img.size
cols = 12
rows = max(5, round(cols * H / W))
cell_w = W // cols
cell_h = H // rows
overlay = Image.new('RGBA', (W, H), (0,0,0,0))
draw = ImageDraw.Draw(overlay)
font = None
for p in ['/usr/share/fonts/TTF/DejaVuSans-Bold.ttf',
          '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
          '/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf',
          '/usr/share/fonts/noto/NotoSans-Bold.ttf']:
    try: font = ImageFont.truetype(p, max(14, min(28, cell_h//8))); break
    except: pass
if font is None: font = ImageFont.load_default()
for row in range(rows):
    for col in range(cols):
        n  = row * cols + col + 1
        x1 = col * cell_w; y1 = row * cell_h
        x2 = x1 + cell_w - 1; y2 = y1 + cell_h - 1
        ccx = x1 + cell_w // 2; ccy = y1 + cell_h // 2
        draw.rectangle([x1,y1,x2,y2], outline=(255,255,255,60), width=1)
        t = str(n)
        bb = draw.textbbox((ccx,ccy), t, font=font, anchor='mm')
        draw.rectangle([bb[0]-3,bb[1]-3,bb[2]+3,bb[3]+3], fill=(0,0,0,150))
        draw.text((ccx,ccy), t, fill=(255,255,255,210), font=font, anchor='mm')
monitors = json.loads(os.environ.get('MONITORS','[]'))
mon_name = os.environ.get('MON_NAME','')
off_x, off_y = 0, 0
if mon_name:
    for m in monitors:
        if m.get('name') == mon_name:
            off_x = m.get('x', 0); off_y = m.get('y', 0); break
else:
    off_x = min((m.get('x',0) for m in monitors), default=0)
    off_y = min((m.get('y',0) for m in monitors), default=0)
cx_img = cx - off_x; cy_img = cy - off_y
r = 18
if 0 <= cx_img < W and 0 <= cy_img < H:
    draw.ellipse([cx_img-r,cy_img-r,cx_img+r,cy_img+r], outline=(255,60,60,230), width=3)
    draw.line([cx_img-26,cy_img,cx_img+26,cy_img], fill=(255,60,60,230), width=2)
    draw.line([cx_img,cy_img-26,cx_img,cy_img+26], fill=(255,60,60,230), width=2)
cx_in_bounds = 0 <= cx_img < W and 0 <= cy_img < H
composite = Image.alpha_composite(img, overlay).convert('RGB')
MAX_W = 1920
sf = 1.0
if W > MAX_W:
    sf = W / MAX_W
    new_h = round(H * MAX_W / W)
    composite = composite.resize((MAX_W, new_h), Image.LANCZOS)
    W_out, H_out = MAX_W, new_h
else:
    W_out, H_out = W, H
composite.save(dest)
cx_s = round(cx_img / sf) if cx_in_bounds else -1
cy_s = round(cy_img / sf) if cx_in_bounds else -1
print(f"GRID_META:{W_out}:{H_out}:{cols}:{rows}")
print(f"SCREENSHOT_OFFSET:{off_x}:{off_y}")
print(f"IMG_SCALE:{sf:.6f}")
print(f"CURSOR_S:{cx_s}:{cy_s}")
PYEOF
)
SS_OFFSET_X=$(echo "\${META}" | grep "^SCREENSHOT_OFFSET:" | cut -d: -f2)
SS_OFFSET_Y=$(echo "\${META}" | grep "^SCREENSHOT_OFFSET:" | cut -d: -f3)
SS_OFFSET_X=\${SS_OFFSET_X:-0}
SS_OFFSET_Y=\${SS_OFFSET_Y:-0}
GRID_LINE=$(echo "\${META}" | grep "^GRID_META:")
IMG_W=$(echo "\${GRID_LINE}" | cut -d: -f2)
IMG_H=$(echo "\${GRID_LINE}" | cut -d: -f3)
GRID_COLS=$(echo "\${GRID_LINE}" | cut -d: -f4)
GRID_ROWS=$(echo "\${GRID_LINE}" | cut -d: -f5)
SCALE=$(echo "\${META}" | grep "^IMG_SCALE:" | cut -d: -f2)
SCALE=\${SCALE:-1.0}
CURSOR_LINE=$(echo "\${META}" | grep "^CURSOR_S:")
CURSOR_SS_X=$(echo "\${CURSOR_LINE}" | cut -d: -f2)
CURSOR_SS_Y=$(echo "\${CURSOR_LINE}" | cut -d: -f3)
CURSOR_SS_X=\${CURSOR_SS_X:--1}
CURSOR_SS_Y=\${CURSOR_SS_Y:--1}
echo "CURSOR_POS:\${CURSOR_SS_X}:\${CURSOR_SS_Y}"
echo "GRID:\${GRID_COLS}:\${GRID_ROWS}"
echo "IMAGE_SIZE:\${IMG_W}:\${IMG_H}"
echo "IMAGE_SCALE:\${SCALE}"
echo "SCREENSHOT_OFFSET:\${SS_OFFSET_X}:\${SS_OFFSET_Y}"
`;
                screenshotProc.command = ["bash", "-c", cmd];
                screenshotProc.running = true;
            });
        } else if (name === "click_cell") {
            const cellNum = Math.max(1, parseInt(args.cell) || 1);
            const cols    = root.lastGridCols  > 0 ? root.lastGridCols  : 8;
            const rows    = root.lastGridRows  > 0 ? root.lastGridRows  : 5;
            const imgW    = root.lastScreenshotWidth  > 0 ? root.lastScreenshotWidth  : 3840;
            const imgH    = root.lastScreenshotHeight > 0 ? root.lastScreenshotHeight : 2160;
            const idx     = Math.min(cellNum - 1, cols * rows - 1);
            const col     = idx % cols;
            const row     = Math.floor(idx / cols);
            const rawX    = Math.round(col * (imgW / cols) + (imgW / cols) / 2);
            const rawY    = Math.round(row * (imgH / rows) + (imgH / rows) / 2);
            const button  = (args.button || "left").toLowerCase();
            const isDouble = args.double === true;
            const mods = (args.modifiers || "").toLowerCase().trim();
            const ydoBtn  = button === "right" ? "3" : button === "middle" ? "2" : "1";
            const scale   = root.lastScreenshotScale  > 0 ? root.lastScreenshotScale  : 1.0;
            const sx = Math.round(rawX * scale) + root.lastScreenshotOffsetX;
            const sy = Math.round(rawY * scale) + root.lastScreenshotOffsetY;
            const modLabel = mods ? ` [${mods}]` : "";
            const dblLabel = isDouble ? " double" : "";
            root._lastClickInfo = `click_cell${dblLabel}${modLabel} ${cellNum}`;
            addFunctionOutputMessage(name, `${isDouble ? "Double-clicking" : "Clicking"}${modLabel} cell ${cellNum} (row ${row+1}, col ${col+1}) → screen (${sx}, ${sy})`);
            // Build modifier key press/release commands
            const modMap = { "ctrl": "29", "shift": "42", "alt": "56", "super": "125" };
            const modParts = mods ? mods.split("+").filter(m => modMap[m]) : [];
            const modDown = modParts.map(m => `ydotool key ${modMap[m]}:1`).join(" && ");
            const modUp = modParts.reverse().map(m => `ydotool key ${modMap[m]}:0`).join(" && ");
            const clickPart = isDouble
                ? `ydotool click --button-up --button-down ${ydoBtn} && sleep 0.05 && ydotool click --button-up --button-down ${ydoBtn}`
                : `ydotool click --button-up --button-down ${ydoBtn}`;
            let clickCmd = `sleep 0.15 && ydotool mousemove --absolute -x ${sx} -y ${sy}`;
            if (modDown) clickCmd += ` && ${modDown}`;
            clickCmd += ` && ${clickPart}`;
            if (modUp) clickCmd += ` && ${modUp}`;
            root.requestHideSidebars();
            Quickshell.execDetached(["bash", "-c", clickCmd]);
            Qt.callLater(() => {
                root._pendingVisionFollowUpKind = "followup";
                const screenshotPath = `${Directories.aiSttTemp}/screenshot.png`;
                const dest = CF.FileUtils.trimFileProtocol(screenshotPath);
                screenshotProc.targetPath = dest;
                const cmd = `
DEST="${dest}"
MONITORS=$(hyprctl monitors -j 2>/dev/null | tr -d '\n' || echo '[]')
CURSOR=$(hyprctl cursorpos 2>/dev/null || echo "0, 0")
CX=$(echo "\${CURSOR}" | awk '{gsub(/,/,"",$1); print $1}')
CY=$(echo "\${CURSOR}" | awk '{print $2}')
MON_NAME=$(MONITORS="$MONITORS" python3 -c '
import json,os,sys,subprocess
mons=json.loads(os.environ.get("MONITORS","[]"))
try:
    aw=json.loads(subprocess.run(["hyprctl","activewindow","-j"],capture_output=True,text=True).stdout or "{}")
    mid=aw.get("monitor",-1)
    if mid>=0:
        for m in mons:
            if m.get("id")==mid: print(m.get("name","")); sys.exit()
except: pass
for m in mons:
    if m.get("focused"): print(m.get("name","")); sys.exit()
if mons: print(mons[0].get("name",""))
' 2>/dev/null || echo "")
MON_NAME=$(echo "$MON_NAME" | head -n1 | tr -d '\r')
if [ -n "$MON_NAME" ]; then
    grim -o "$MON_NAME" "$DEST" 2>&1 || exit 1
else
    grim "$DEST" 2>&1 || exit 1
fi
META=$(DEST=$DEST CX=\${CX} CY=\${CY} MONITORS="$MONITORS" MON_NAME="$MON_NAME" python3 2>&1 << 'PYEOF'
from PIL import Image, ImageDraw, ImageFont
import os, json
dest = os.environ['DEST']
cx   = int(os.environ.get('CX', 0))
cy   = int(os.environ.get('CY', 0))
img  = Image.open(dest).convert('RGBA')
W, H = img.size
cols = 12
rows = max(5, round(cols * H / W))
cell_w = W // cols
cell_h = H // rows
overlay = Image.new('RGBA', (W, H), (0,0,0,0))
draw = ImageDraw.Draw(overlay)
font = None
for p in ['/usr/share/fonts/TTF/DejaVuSans-Bold.ttf',
          '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
          '/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf',
          '/usr/share/fonts/noto/NotoSans-Bold.ttf']:
    try: font = ImageFont.truetype(p, max(14, min(28, cell_h//8))); break
    except: pass
if font is None: font = ImageFont.load_default()
for row in range(rows):
    for col in range(cols):
        n  = row * cols + col + 1
        x1 = col * cell_w; y1 = row * cell_h
        x2 = x1 + cell_w - 1; y2 = y1 + cell_h - 1
        ccx = x1 + cell_w // 2; ccy = y1 + cell_h // 2
        draw.rectangle([x1,y1,x2,y2], outline=(255,255,255,60), width=1)
        t = str(n)
        bb = draw.textbbox((ccx,ccy), t, font=font, anchor='mm')
        draw.rectangle([bb[0]-3,bb[1]-3,bb[2]+3,bb[3]+3], fill=(0,0,0,150))
        draw.text((ccx,ccy), t, fill=(255,255,255,210), font=font, anchor='mm')
monitors = json.loads(os.environ.get('MONITORS','[]'))
mon_name = os.environ.get('MON_NAME','')
off_x, off_y = 0, 0
if mon_name:
    for m in monitors:
        if m.get('name') == mon_name:
            off_x = m.get('x', 0); off_y = m.get('y', 0); break
else:
    off_x = min((m.get('x',0) for m in monitors), default=0)
    off_y = min((m.get('y',0) for m in monitors), default=0)
cx_img = cx - off_x; cy_img = cy - off_y
r = 18
if 0 <= cx_img < W and 0 <= cy_img < H:
    draw.ellipse([cx_img-r,cy_img-r,cx_img+r,cy_img+r], outline=(255,60,60,230), width=3)
    draw.line([cx_img-26,cy_img,cx_img+26,cy_img], fill=(255,60,60,230), width=2)
    draw.line([cx_img,cy_img-26,cx_img,cy_img+26], fill=(255,60,60,230), width=2)
cx_in_bounds = 0 <= cx_img < W and 0 <= cy_img < H
composite = Image.alpha_composite(img, overlay).convert('RGB')
MAX_W = 1920
sf = 1.0
if W > MAX_W:
    sf = W / MAX_W
    new_h = round(H * MAX_W / W)
    composite = composite.resize((MAX_W, new_h), Image.LANCZOS)
    W_out, H_out = MAX_W, new_h
else:
    W_out, H_out = W, H
composite.save(dest)
cx_s = round(cx_img / sf) if cx_in_bounds else -1
cy_s = round(cy_img / sf) if cx_in_bounds else -1
print(f"GRID_META:{W_out}:{H_out}:{cols}:{rows}")
print(f"SCREENSHOT_OFFSET:{off_x}:{off_y}")
print(f"IMG_SCALE:{sf:.6f}")
print(f"CURSOR_S:{cx_s}:{cy_s}")
PYEOF
)
SS_OFFSET_X=$(echo "\${META}" | grep "^SCREENSHOT_OFFSET:" | cut -d: -f2)
SS_OFFSET_Y=$(echo "\${META}" | grep "^SCREENSHOT_OFFSET:" | cut -d: -f3)
SS_OFFSET_X=\${SS_OFFSET_X:-0}
SS_OFFSET_Y=\${SS_OFFSET_Y:-0}
GRID_LINE=$(echo "\${META}" | grep "^GRID_META:")
IMG_W=$(echo "\${GRID_LINE}" | cut -d: -f2)
IMG_H=$(echo "\${GRID_LINE}" | cut -d: -f3)
GRID_COLS=$(echo "\${GRID_LINE}" | cut -d: -f4)
GRID_ROWS=$(echo "\${GRID_LINE}" | cut -d: -f5)
SCALE=$(echo "\${META}" | grep "^IMG_SCALE:" | cut -d: -f2)
SCALE=\${SCALE:-1.0}
CURSOR_LINE=$(echo "\${META}" | grep "^CURSOR_S:")
CURSOR_SS_X=$(echo "\${CURSOR_LINE}" | cut -d: -f2)
CURSOR_SS_Y=$(echo "\${CURSOR_LINE}" | cut -d: -f3)
CURSOR_SS_X=\${CURSOR_SS_X:--1}
CURSOR_SS_Y=\${CURSOR_SS_Y:--1}
echo "CURSOR_POS:\${CURSOR_SS_X}:\${CURSOR_SS_Y}"
echo "GRID:\${GRID_COLS}:\${GRID_ROWS}"
echo "IMAGE_SIZE:\${IMG_W}:\${IMG_H}"
echo "IMAGE_SCALE:\${SCALE}"
echo "SCREENSHOT_OFFSET:\${SS_OFFSET_X}:\${SS_OFFSET_Y}"
`;
                screenshotProc.command = ["bash", "-c", cmd];
                screenshotProc.running = true;
            });
        } else if (name === "type_text") {
            const text = args.text || "";
            if (!text) { addFunctionOutputMessage(name, "Invalid: text is required"); requester.makeRequest(); return; }
            const escaped = text.replace(/'/g, "'\\''");
            Quickshell.execDetached(["bash", "-c", `ydotool type --key-delay 20 -- '${escaped}'`]);
            addFunctionOutputMessage(name, `Typed: "${text.substring(0, 60)}${text.length > 60 ? "..." : ""}"`);
            requester.makeRequest();
        } else if (name === "press_key") {
            const key = (args.key || "Return").trim();
            // Convert common key names to ydotool key codes
            const keyMap = {
                "Return": "28", "Enter": "28", "Escape": "1", "Tab": "15",
                "space": "57", "BackSpace": "14", "Delete": "111",
                "Up": "103", "Down": "108", "Left": "105", "Right": "106",
                "Home": "102", "End": "107", "Page_Up": "104", "Page_Down": "109",
                "F1":"59","F2":"60","F3":"61","F4":"62","F5":"63","F6":"64",
                "F7":"65","F8":"66","F9":"67","F10":"68","F11":"87","F12":"88",
            };
            // Handle combos like ctrl+a, ctrl+l, ctrl+w
            const parts = key.toLowerCase().split("+");
            const mods = { "ctrl": "29", "shift": "42", "alt": "56", "super": "125", "meta": "125" };
            let keyCodes = [];
            let pressDown = [], pressUp = [];
            for (const part of parts) {
                if (mods[part]) {
                    keyCodes.push(mods[part]);
                } else {
                    const mapped = keyMap[args.key] || keyMap[part];
                    if (mapped) keyCodes.push(mapped);
                    else keyCodes.push("28"); // fallback to Enter
                }
            }
            // Press all down then all up in reverse
            const downArgs = keyCodes.map(c => `--key-codes ${c}`).join(" ");
            Quickshell.execDetached(["bash", "-c", `ydotool key ${keyCodes.map(c => c + ":1").join(" ")} ${keyCodes.reverse().map(c => c + ":0").join(" ")}`]);
            addFunctionOutputMessage(name, `Pressed: ${key}`);
            requester.makeRequest();
        } else if (name === "memory_file") {
            const command = (args.command || "view").trim();
            const rawPath = (args.path || "/memories/").trim();
            if (!rawPath.startsWith("/memories")) {
                addFunctionOutputMessage(name, "Error: path must start with /memories/");
                requester.makeRequest();
                return;
            }
            const memBase = Directories.aiMemoryPath.replace("memory.md", "memories");
            const rel = rawPath.replace(/^\/memories\/?/, "");
            const safePath = rel.length > 0 ? `${memBase}/${rel}` : memBase;
            const memMsg = createFunctionOutputMessage(name, "", false);
            const memId = idForMessage(memMsg);
            root.messageIDs = [...root.messageIDs, memId];
            root.messageByID[memId] = memMsg;
            commandExecutionProc.message = memMsg;
            commandExecutionProc.baseMessageContent = memMsg.content;
            let shellCmd = "";
            if (command === "view") {
                shellCmd = `mkdir -p "${memBase}"; [ -d "${safePath}" ] && (echo "Directory ${rawPath}:"; ls "${safePath}" 2>/dev/null || echo "  (empty)") || ([ -f "${safePath}" ] && cat "${safePath}" || echo "Not found: ${rawPath}")`;
            } else if (command === "create") {
                const b64 = btoa(unescape(encodeURIComponent(args.file_text || "")));
                shellCmd = `mkdir -p "$(dirname "${safePath}")" 2>/dev/null; python3 -c "import base64; open('${safePath}','w').write(base64.b64decode('${b64}').decode('utf-8'))" && echo "Created: ${rawPath}"`;
            } else if (command === "str_replace") {
                const b64Old = btoa(unescape(encodeURIComponent(args.old_str || "")));
                const b64New = btoa(unescape(encodeURIComponent(args.new_str || "")));
                shellCmd = `python3 -c "
import base64
old=base64.b64decode('${b64Old}').decode()
new=base64.b64decode('${b64New}').decode()
with open('${safePath}') as f: c=f.read()
if old not in c: print('Error: text not found in file'); exit(1)
with open('${safePath}','w') as f: f.write(c.replace(old,new,1))
print('Updated: ${rawPath}')
" 2>&1`;
            } else if (command === "insert") {
                const insertLine = parseInt(args.insert_line) || 0;
                const b64Text = btoa(unescape(encodeURIComponent(args.insert_text || "")));
                shellCmd = `python3 -c "
import base64
text=base64.b64decode('${b64Text}').decode()
with open('${safePath}') as f: lines=f.readlines()
lines.insert(${insertLine}, text if text.endswith('\\\\n') else text+'\\\\n')
with open('${safePath}','w') as f: f.writelines(lines)
print('Inserted at line ${insertLine}: ${rawPath}')
" 2>&1`;
            } else if (command === "delete") {
                shellCmd = `rm -rf "${safePath}" && echo "Deleted: ${rawPath}" || echo "Not found: ${rawPath}"`;
            } else {
                addFunctionOutputMessage(name, `Unknown command: ${command}. Use: view, create, str_replace, insert, delete`);
                requester.makeRequest();
                return;
            }
            commandExecutionProc.shellCommand = shellCmd;
            commandExecutionProc.running = true;
        } else if (name === "dream") {
            const dreamAction = (args.action || "gather").trim();
            const dreamScript = `"${Directories.aiMemoryPath.replace('memory.md', 'dream.py')}"`;
            const dreamMsg = createFunctionOutputMessage(name, "", false);
            const dreamId = idForMessage(dreamMsg);
            root.messageIDs = [...root.messageIDs, dreamId];
            root.messageByID[dreamId] = dreamMsg;
            commandExecutionProc.message = dreamMsg;
            commandExecutionProc.baseMessageContent = dreamMsg.content;
            if (dreamAction === "auto") {
                commandExecutionProc.shellCommand = `python3 ${dreamScript} auto 2>&1`;
            } else if (dreamAction === "gather") {
                commandExecutionProc.shellCommand = `python3 ${dreamScript} gather 2>&1`;
            } else if (dreamAction === "apply") {
                const actionsJson = JSON.stringify(args.actions || []);
                const b64Actions = btoa(unescape(encodeURIComponent(actionsJson)));
                commandExecutionProc.shellCommand = `python3 ${dreamScript} apply "$(python3 -c "import base64; print(base64.b64decode('${b64Actions}').decode())")" 2>&1`;
            } else {
                addFunctionOutputMessage(name, `Unknown action: ${dreamAction}. Use 'gather' or 'apply'.`);
                requester.makeRequest();
                return;
            }
            commandExecutionProc.running = true;
        } else if (name === "kg_store") {
            const action = (args.action || "").trim();
            const kgScript = `"${Directories.aiMemoryPath.replace('memory.md', 'kg.py')}"`;
            const kgMsg = createFunctionOutputMessage(name, "", false);
            const kgId = idForMessage(kgMsg);
            root.messageIDs = [...root.messageIDs, kgId];
            root.messageByID[kgId] = kgMsg;
            commandExecutionProc.message = kgMsg;
            commandExecutionProc.baseMessageContent = kgMsg.content;
            let kgCmd = "";
            if (action === "entity") {
                const eName = args.name || "";
                const eType = args.entity_type || "thing";
                const obs = JSON.stringify(args.observations || []);
                if (!eName) { addFunctionOutputMessage(name, "Error: name is required"); requester.makeRequest(); return; }
                kgCmd = `python3 ${kgScript} store ${JSON.stringify(eName)} ${JSON.stringify(eType)} ${JSON.stringify(obs)} 2>&1`;
            } else if (action === "relation") {
                const from = args.from_entity || "";
                const rel = args.relation || "";
                const to = args.to_entity || "";
                if (!from || !rel || !to) { addFunctionOutputMessage(name, "Error: from_entity, relation, and to_entity are required"); requester.makeRequest(); return; }
                kgCmd = `python3 ${kgScript} relate ${JSON.stringify(from)} ${JSON.stringify(rel)} ${JSON.stringify(to)} 2>&1`;
            } else if (action === "observe") {
                const eName = args.name || "";
                const obs = JSON.stringify(args.observations || []);
                if (!eName) { addFunctionOutputMessage(name, "Error: name is required"); requester.makeRequest(); return; }
                kgCmd = `python3 ${kgScript} observe ${JSON.stringify(eName)} ${JSON.stringify(obs)} 2>&1`;
            } else {
                addFunctionOutputMessage(name, "Error: action must be 'entity', 'relation', or 'observe'");
                requester.makeRequest();
                return;
            }
            commandExecutionProc.shellCommand = kgCmd;
            commandExecutionProc.running = true;
        } else if (name === "kg_query") {
            const action = (args.action || "").trim();
            const kgScript = `"${Directories.aiMemoryPath.replace('memory.md', 'kg.py')}"`;
            const kgMsg = createFunctionOutputMessage(name, "", false);
            const kgId = idForMessage(kgMsg);
            root.messageIDs = [...root.messageIDs, kgId];
            root.messageByID[kgId] = kgMsg;
            commandExecutionProc.message = kgMsg;
            commandExecutionProc.baseMessageContent = kgMsg.content;
            let kgCmd = "";
            if (action === "search") {
                const query = args.query || "";
                if (!query) { addFunctionOutputMessage(name, "Error: query is required"); requester.makeRequest(); return; }
                kgCmd = `python3 ${kgScript} search ${JSON.stringify(query)} 2>&1`;
            } else if (action === "read") {
                const eName = args.name || "";
                kgCmd = eName ? `python3 ${kgScript} read ${JSON.stringify(eName)} 2>&1` : `python3 ${kgScript} read 2>&1`;
            } else if (action === "delete_entity") {
                const eName = args.name || "";
                if (!eName) { addFunctionOutputMessage(name, "Error: name is required"); requester.makeRequest(); return; }
                kgCmd = `python3 ${kgScript} delete_entity ${JSON.stringify(eName)} 2>&1`;
            } else if (action === "delete_relation") {
                const from = args.from_entity || "";
                const rel = args.relation || "";
                const to = args.to_entity || "";
                if (!from || !rel || !to) { addFunctionOutputMessage(name, "Error: from_entity, relation, and to_entity required"); requester.makeRequest(); return; }
                kgCmd = `python3 ${kgScript} delete_relation ${JSON.stringify(from)} ${JSON.stringify(rel)} ${JSON.stringify(to)} 2>&1`;
            } else if (action === "delete_observation") {
                const eName = args.name || "";
                const obs = args.observation || "";
                if (!eName || !obs) { addFunctionOutputMessage(name, "Error: name and observation required"); requester.makeRequest(); return; }
                kgCmd = `python3 ${kgScript} delete_observation ${JSON.stringify(eName)} ${JSON.stringify(obs)} 2>&1`;
            } else {
                addFunctionOutputMessage(name, "Error: action must be 'search', 'read', 'delete_entity', 'delete_relation', or 'delete_observation'");
                requester.makeRequest();
                return;
            }
            commandExecutionProc.shellCommand = kgCmd;
            commandExecutionProc.running = true;
        } else if (name === "rag_search") {
            const query = args.query || "";
            if (!query) { addFunctionOutputMessage(name, "Error: query is required"); requester.makeRequest(); return; }
            const limit = Math.min(parseInt(args.limit) || 5, 20);
            const ragScript = `"${Directories.aiMemoryPath.replace('memory.md', 'rag.py')}"`;
            const ragMsg = createFunctionOutputMessage(name, "", false);
            const ragId = idForMessage(ragMsg);
            root.messageIDs = [...root.messageIDs, ragId];
            root.messageByID[ragId] = ragMsg;
            commandExecutionProc.message = ragMsg;
            commandExecutionProc.baseMessageContent = ragMsg.content;
            commandExecutionProc.shellCommand = `python3 ${ragScript} search ${JSON.stringify(query)} ${limit} 2>&1`;
            commandExecutionProc.running = true;
        } else if (name === "rag_index") {
            const path = args.path || "";
            if (!path) { addFunctionOutputMessage(name, "Error: path is required"); requester.makeRequest(); return; }
            const ragScript = `"${Directories.aiMemoryPath.replace('memory.md', 'rag.py')}"`;
            const ragMsg = createFunctionOutputMessage(name, "", false);
            const ragId = idForMessage(ragMsg);
            root.messageIDs = [...root.messageIDs, ragId];
            root.messageByID[ragId] = ragMsg;
            commandExecutionProc.message = ragMsg;
            commandExecutionProc.baseMessageContent = ragMsg.content;
            let ragCmd = `python3 ${ragScript} index ${JSON.stringify(path)}`;
            if (args.extensions) ragCmd += ` --ext=${args.extensions}`;
            ragCmd += " 2>&1";
            commandExecutionProc.shellCommand = ragCmd;
            commandExecutionProc.running = true;
        } else if (name === "calendar") {
            const action = (args.action || "today").trim();
            const calScript = Quickshell.env("HOME") + "/.config/quickshell/ii/scripts/ai/calendar.sh";
            const calMsg = createFunctionOutputMessage(name, "", false);
            const calId = idForMessage(calMsg);
            root.messageIDs = [...root.messageIDs, calId];
            root.messageByID[calId] = calMsg;
            commandExecutionProc.message = calMsg;
            commandExecutionProc.baseMessageContent = calMsg.content;
            let calCmd = "";
            if (action === "today") {
                calCmd = `bash "${calScript}" today 2>&1`;
            } else if (action === "list") {
                const days = Math.min(parseInt(args.days) || 3, 30);
                calCmd = `bash "${calScript}" list ${days} 2>&1`;
            } else if (action === "now") {
                calCmd = `bash "${calScript}" now 2>&1`;
            } else if (action === "add") {
                const eventArgs = args.event_args || "";
                if (!eventArgs) { addFunctionOutputMessage(name, "Error: event_args required for add"); requester.makeRequest(); return; }
                calCmd = `bash "${calScript}" add ${eventArgs} 2>&1`;
            } else if (action === "search") {
                const query = args.query || "";
                if (!query) { addFunctionOutputMessage(name, "Error: query required for search"); requester.makeRequest(); return; }
                calCmd = `bash "${calScript}" search ${JSON.stringify(query)} 2>&1`;
            } else if (action === "sync") {
                calCmd = `bash "${calScript}" sync 2>&1`;
            } else {
                addFunctionOutputMessage(name, "Error: action must be 'today', 'list', 'now', 'add', 'search', or 'sync'");
                requester.makeRequest();
                return;
            }
            commandExecutionProc.shellCommand = calCmd;
            commandExecutionProc.running = true;
        } else if (name === "workspace_layout") {
            const action = (args.action || "current").trim();
            const layoutScript = Quickshell.env("HOME") + "/.config/quickshell/ii/scripts/ai/workspace-layout.sh";
            const wlMsg = createFunctionOutputMessage(name, "", false);
            const wlId = idForMessage(wlMsg);
            root.messageIDs = [...root.messageIDs, wlId];
            root.messageByID[wlId] = wlMsg;
            commandExecutionProc.message = wlMsg;
            commandExecutionProc.baseMessageContent = wlMsg.content;
            let wlCmd = "";
            if (action === "current") {
                wlCmd = `bash "${layoutScript}" current 2>&1`;
            } else if (action === "save") {
                const lname = args.name || "";
                if (!lname) { addFunctionOutputMessage(name, "Error: name required for save"); requester.makeRequest(); return; }
                wlCmd = `bash "${layoutScript}" save ${JSON.stringify(lname)} 2>&1`;
            } else if (action === "restore") {
                const lname = args.name || "";
                if (!lname) { addFunctionOutputMessage(name, "Error: name required for restore"); requester.makeRequest(); return; }
                wlCmd = `bash "${layoutScript}" restore ${JSON.stringify(lname)} 2>&1`;
            } else if (action === "list") {
                wlCmd = `bash "${layoutScript}" list 2>&1`;
            } else if (action === "delete") {
                const lname = args.name || "";
                if (!lname) { addFunctionOutputMessage(name, "Error: name required for delete"); requester.makeRequest(); return; }
                wlCmd = `bash "${layoutScript}" delete ${JSON.stringify(lname)} 2>&1`;
            } else {
                addFunctionOutputMessage(name, "Error: action must be 'save', 'restore', 'list', 'delete', or 'current'");
                requester.makeRequest();
                return;
            }
            commandExecutionProc.shellCommand = wlCmd;
            commandExecutionProc.running = true;
        } else if (name === "scroll") {
            const dir = (args.direction || "down").toLowerCase();
            const amount = Math.min(Math.max(parseInt(args.amount) || 3, 1), 20);
            let ax = 0, ay = 0;
            if (dir === "up") ay = -amount;
            else if (dir === "down") ay = amount;
            else if (dir === "left") ax = -amount;
            else if (dir === "right") ax = amount;
            Quickshell.execDetached(["bash", "-c", `ydotool mousescroll --axis-x ${ax} --axis-y ${ay}`]);
            addFunctionOutputMessage(name, `Scrolled ${dir} ${amount} step(s)`);
            requester.makeRequest();
        } else if (name === "drag_to") {
            const imgW  = root.lastScreenshotWidth  > 0 ? root.lastScreenshotWidth  : 1920;
            const imgH  = root.lastScreenshotHeight > 0 ? root.lastScreenshotHeight : 1080;
            const scale = root.lastScreenshotScale  > 0 ? root.lastScreenshotScale  : 1.0;
            const rawX1 = parseFloat(args.x1) || 0;
            const rawY1 = parseFloat(args.y1) || 0;
            const rawX2 = parseFloat(args.x2) || 0;
            const rawY2 = parseFloat(args.y2) || 0;
            const button = (args.button || "left").toLowerCase();
            const nativeW = Math.round(imgW * scale);
            const nativeH = Math.round(imgH * scale);
            const sx1 = Math.max(0, Math.min(Math.round(rawX1 * scale), nativeW)) + root.lastScreenshotOffsetX;
            const sy1 = Math.max(0, Math.min(Math.round(rawY1 * scale), nativeH)) + root.lastScreenshotOffsetY;
            const sx2 = Math.max(0, Math.min(Math.round(rawX2 * scale), nativeW)) + root.lastScreenshotOffsetX;
            const sy2 = Math.max(0, Math.min(Math.round(rawY2 * scale), nativeH)) + root.lastScreenshotOffsetY;
            const ydoBtn = button === "right" ? "3" : "1";
            root._lastClickInfo = `drag_to (${rawX1},${rawY1}) → (${rawX2},${rawY2})`;
            addFunctionOutputMessage(name, `Dragging (${rawX1},${rawY1}) → (${rawX2},${rawY2}) screen (${sx1},${sy1}) → (${sx2},${sy2})`);
            const dragCmd = `sleep 0.15 && ydotool mousemove --absolute -x ${sx1} -y ${sy1} && sleep 0.1 && ydotool click --button-down ${ydoBtn} && sleep 0.1 && ydotool mousemove --absolute -x ${sx2} -y ${sy2} && sleep 0.1 && ydotool click --button-up ${ydoBtn}`;
            root.requestHideSidebars();
            Quickshell.execDetached(["bash", "-c", dragCmd]);
            triggerAutoScreenshot(1000);
        } else if (name === "hover") {
            const imgW  = root.lastScreenshotWidth  > 0 ? root.lastScreenshotWidth  : 1920;
            const imgH  = root.lastScreenshotHeight > 0 ? root.lastScreenshotHeight : 1080;
            const scale = root.lastScreenshotScale  > 0 ? root.lastScreenshotScale  : 1.0;
            const rawX  = parseFloat(args.x) || 0;
            const rawY  = parseFloat(args.y) || 0;
            const nativeW = Math.round(imgW * scale);
            const nativeH = Math.round(imgH * scale);
            const sx = Math.max(0, Math.min(Math.round(rawX * scale), nativeW)) + root.lastScreenshotOffsetX;
            const sy = Math.max(0, Math.min(Math.round(rawY * scale), nativeH)) + root.lastScreenshotOffsetY;
            root._lastClickInfo = `hover (${rawX}, ${rawY})`;
            addFunctionOutputMessage(name, `Hovering at (${rawX}, ${rawY}) → screen (${sx}, ${sy})`);
            const hoverCmd = `sleep 0.15 && ydotool mousemove --absolute -x ${sx} -y ${sy}`;
            root.requestHideSidebars();
            Quickshell.execDetached(["bash", "-c", hoverCmd]);
            triggerAutoScreenshot(800);
        } else if (name === "read_screen_text") {
            const hasRegion = args.x !== undefined && args.y !== undefined && args.width !== undefined && args.height !== undefined;
            const scale = root.lastScreenshotScale > 0 ? root.lastScreenshotScale : 1.0;
            let grimArgs = "";
            if (hasRegion) {
                const rx = Math.round((parseFloat(args.x) || 0) * scale) + root.lastScreenshotOffsetX;
                const ry = Math.round((parseFloat(args.y) || 0) * scale) + root.lastScreenshotOffsetY;
                const rw = Math.round((parseFloat(args.width) || 200) * scale);
                const rh = Math.round((parseFloat(args.height) || 100) * scale);
                grimArgs = `-g "${rx},${ry} ${rw}x${rh}"`;
            } else {
                // Full active monitor
                grimArgs = "";
            }
            const ocrMsg = createFunctionOutputMessage(name, "", false);
            const ocrId = idForMessage(ocrMsg);
            root.messageIDs = [...root.messageIDs, ocrId];
            root.messageByID[ocrId] = ocrMsg;
            commandExecutionProc.message = ocrMsg;
            commandExecutionProc.baseMessageContent = ocrMsg.content;
            const tmpImg = "/tmp/quickshell/ai/ocr_region.png";
            let ocrCmd = "";
            if (hasRegion) {
                ocrCmd = `grim ${grimArgs} "${tmpImg}" 2>&1 && tesseract "${tmpImg}" - 2>/dev/null || echo "(OCR failed)"`;
            } else {
                // Get active monitor name first
                ocrCmd = `MON=$(hyprctl monitors -j 2>/dev/null | python3 -c "
import json,sys,subprocess
mons=json.loads(sys.stdin.read())
try:
    aw=json.loads(subprocess.run(['hyprctl','activewindow','-j'],capture_output=True,text=True).stdout or '{}')
    mid=aw.get('monitor',-1)
    if mid>=0:
        for m in mons:
            if m.get('id')==mid: print(m.get('name','')); sys.exit()
except: pass
for m in mons:
    if m.get('focused'): print(m.get('name','')); sys.exit()
if mons: print(mons[0].get('name',''))
" 2>/dev/null) && grim -o "$MON" "${tmpImg}" 2>&1 && tesseract "${tmpImg}" - 2>/dev/null || echo "(OCR failed)"`;
            }
            commandExecutionProc.shellCommand = ocrCmd;
            commandExecutionProc.running = true;
        } else if (name === "manage_tabs") {
            const action = (args.action || "").toLowerCase().trim();
            const index = Math.min(Math.max(parseInt(args.index) || 1, 1), 9);
            const keyMap = {
                "next": "29:1 15:1 15:0 29:0",      // ctrl+tab
                "prev": "29:1 42:1 15:1 15:0 42:0 29:0", // ctrl+shift+tab
                "close": "29:1 17:1 17:0 29:0",     // ctrl+w
                "new": "29:1 20:1 20:0 29:0",       // ctrl+t
                "reopen": "29:1 42:1 20:1 20:0 42:0 29:0" // ctrl+shift+t
            };
            if (action === "goto") {
                // ctrl+1 through ctrl+9 — key codes: 1=2, 2=3, ..., 9=10
                const keyCode = index + 1;
                Quickshell.execDetached(["bash", "-c", `ydotool key 29:1 ${keyCode}:1 ${keyCode}:0 29:0`]);
                addFunctionOutputMessage(name, `Switched to tab ${index}`);
            } else if (keyMap[action]) {
                Quickshell.execDetached(["bash", "-c", `ydotool key ${keyMap[action]}`]);
                addFunctionOutputMessage(name, `Tab action: ${action}`);
            } else {
                addFunctionOutputMessage(name, `Unknown action: '${action}'. Use: next, prev, close, goto, new, reopen`);
            }
            requester.makeRequest();
        } else if (name === "wait_and_screenshot") {
            const seconds = Math.min(Math.max(parseFloat(args.seconds) || 3, 1), 15);
            const reason = args.reason || "waiting for UI update";
            addFunctionOutputMessage(name, `Waiting ${seconds}s: ${reason}`);
            root.requestHideSidebars();
            triggerAutoScreenshot(seconds * 1000);
        } else if (name === "read_clipboard_text") {
            const clipMsg = createFunctionOutputMessage(name, "", false);
            const clipId = idForMessage(clipMsg);
            root.messageIDs = [...root.messageIDs, clipId];
            root.messageByID[clipId] = clipMsg;
            commandExecutionProc.message = clipMsg;
            commandExecutionProc.baseMessageContent = clipMsg.content;
            commandExecutionProc.shellCommand = `wl-paste 2>/dev/null || echo "(clipboard is empty)"`;
            commandExecutionProc.running = true;
        } else if (name === "write_clipboard") {
            const text = args.text || "";
            if (!text) { addFunctionOutputMessage(name, "Invalid: text is required"); requester.makeRequest(); return; }
            const clipMsg = createFunctionOutputMessage(name, "", false);
            const clipId = idForMessage(clipMsg);
            root.messageIDs = [...root.messageIDs, clipId];
            root.messageByID[clipId] = clipMsg;
            commandExecutionProc.message = clipMsg;
            commandExecutionProc.baseMessageContent = clipMsg.content;
            commandExecutionProc.shellCommand = `printf '%s' ${JSON.stringify(text)} | wl-copy 2>&1 && echo "Copied to clipboard"`;
            commandExecutionProc.running = true;
        } else if (name === "search_app") {
            const app = (args.app || "").toLowerCase().replace(/[_\s]/g, "");
            const query = args.query || "";
            if (!query) { addFunctionOutputMessage(name, "Invalid: query is required"); requester.makeRequest(); return; }
            // Route native music apps through oi-task for reliable code-based playback
            const nativeApps = ["spotify", "youtubemusic", "soundcloud"];
            if (nativeApps.includes(app)) {
                const responseMessage = createFunctionOutputMessage(name, "", false);
                const id = idForMessage(responseMessage);
                root.messageIDs = [...root.messageIDs, id];
                root.messageByID[id] = responseMessage;
                commandExecutionProc.message = responseMessage;
                commandExecutionProc.baseMessageContent = responseMessage.content;
                const escapedQuery = query.replace(/'/g, "'\\''");
                const escapedApp = args.app || app;
                commandExecutionProc.shellCommand = `oi-task 'Search for "${escapedQuery}" on ${escapedApp} and play it. Use playerctl or dbus to control the app.'`;
                commandExecutionProc.running = true;
                return;
            }
            const encoded = encodeURIComponent(query);
            let uri;
            switch (app) {
                case "youtube":       uri = `https://youtube.com/search?q=${encoded}`; break;
                case "twitch":        uri = `https://twitch.tv/search?term=${encoded}`; break;
                case "bandcamp":      uri = `https://bandcamp.com/search?q=${encoded}`; break;
                case "reddit":        uri = `https://reddit.com/search?q=${encoded}`; break;
                case "github":        uri = `https://github.com/search?q=${encoded}`; break;
                case "files": {
                    const filesMsg = createFunctionOutputMessage(name, "", false);
                    const filesId = idForMessage(filesMsg);
                    root.messageIDs = [...root.messageIDs, filesId];
                    root.messageByID[filesId] = filesMsg;
                    commandExecutionProc.message = filesMsg;
                    commandExecutionProc.baseMessageContent = filesMsg.content;
                    commandExecutionProc.shellCommand = `find "$HOME" -iname "*${query.replace(/"/g, '\\"')}*" -not -path '*/.git/*' 2>/dev/null | head -20`;
                    commandExecutionProc.running = true;
                    return;
                }
                default: uri = `https://google.com/search?q=${encoded}+site:${app}`; break;
            }
            Quickshell.execDetached(["xdg-open", uri]);
            addFunctionOutputMessage(name, `Searching ${args.app} for: "${query}"`);
            requester.makeRequest();
        } else if (name === "read_url") {
            const url = (args.url || "").trim();
            if (!url) { addFunctionOutputMessage(name, "Error: no URL provided"); requester.makeRequest(); return; }
            const readMsg = createFunctionOutputMessage(name, "", false);
            const readId = idForMessage(readMsg);
            root.messageIDs = [...root.messageIDs, readId];
            root.messageByID[readId] = readMsg;
            commandExecutionProc.message = readMsg;
            commandExecutionProc.baseMessageContent = readMsg.content;
            commandExecutionProc.shellCommand = `
curl -sL --max-time 15 -A "Mozilla/5.0" '${url.replace(/'/g, "'\\''")}' | python3 << 'PYEOF'
import sys, re
from html.parser import HTMLParser

class ElemParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.results = []
        self.title = ""
        self.text_parts = []
        self._in_title = False
        self._skip_tags = {"script","style","noscript","svg","head","nav","footer","header"}
        self._skip_depth = 0
        self._interactive = {"input","button","select","textarea","a","form","label"}
        self._content_tags = {"p","h1","h2","h3","h4","h5","h6","li","td","th","span","div","article","section","blockquote","figcaption","strong","em","b","i"}
        self._in_content = 0
        self._cur_tag = ""

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag in self._skip_tags:
            self._skip_depth += 1
            return
        if self._skip_depth: return
        if tag == "title":
            self._in_title = True
        if tag in self._content_tags:
            self._in_content += 1
            self._cur_tag = tag
        if tag in self._interactive:
            parts = [tag]
            for k in ("id","name","type","placeholder","href","value","aria-label","for"):
                if k in a: parts.append(f'{k}="{a[k]}"')
            txt = " ".join(parts)
            self.results.append(txt)

    def handle_endtag(self, tag):
        if tag in self._skip_tags and self._skip_depth:
            self._skip_depth -= 1
        if tag == "title":
            self._in_title = False
        if tag in self._content_tags and self._in_content:
            self._in_content -= 1
            if tag in ("p","h1","h2","h3","h4","h5","h6","li","blockquote"):
                self.text_parts.append("")  # paragraph break

    def handle_data(self, data):
        if self._in_title:
            self.title += data
        if self._in_content and not self._skip_depth:
            text = data.strip()
            if text and len(text) > 1:
                self.text_parts.append(text)

html = sys.stdin.read()
p = ElemParser()
p.feed(html)
print(f"Page: {p.title.strip()}")
print(f"URL: ${url.replace(/'/g, "'\\''")}")

# Page text content (truncated to ~3000 chars for context window)
text = " ".join(t for t in p.text_parts if t).strip()
# Collapse whitespace
text = re.sub(r'\s+', ' ', text)
if text:
    print("")
    print(f"Content ({len(text)} chars):")
    print(text[:3000])
    if len(text) > 3000:
        print(f"... truncated ({len(text)} total chars)")

print("")
print(f"Elements ({len(p.results)}):")
for e in p.results[:80]:
    print(" ", e)
if len(p.results) > 80:
    print(f"  ... and {len(p.results)-80} more")
PYEOF
`;
            commandExecutionProc.running = true;
            return;
        } else if (name === "execute_js") {
            const js = (args.code || "").trim();
            if (!js) { addFunctionOutputMessage(name, "Error: no JS code provided"); requester.makeRequest(); return; }
            const shellSafeJS = js.replace(/'/g, "'\\''");
            addFunctionOutputMessage(name, `Executing JS in browser...`);
            // Copy JS to clipboard, open DevTools console, paste and run, then close console
            const execCmd = `printf '%s' '${shellSafeJS}' | wl-copy
qs -p ~/.config/quickshell/ii ipc call sidebarLeft close 2>/dev/null
sleep 0.5
hyprctl dispatch focuswindow "class:firefox" 2>/dev/null
sleep 0.5
wtype -k F12
sleep 1.5
wtype -M ctrl -k v -m ctrl
sleep 0.3
wtype -k Return
sleep 3
wtype -k F12
`;
            Quickshell.execDetached(["bash", "-c", execCmd]);
            // Auto-screenshot after JS and console automation have time to complete (~7s total)
            Qt.callLater(() => {
                root._pendingVisionFollowUpKind = "execute_js";
                const dest = "/tmp/quickshell/ai/screenshot.png";
                const cmd = `
mkdir -p /tmp/quickshell/ai
sleep 7
DEST="${dest}"
MONITORS=$(hyprctl monitors -j 2>/dev/null | tr -d '\n' || echo '[]')
CURSOR=$(hyprctl cursorpos 2>/dev/null || echo "0, 0")
CX=$(echo "\${CURSOR}" | awk '{gsub(/,/,"",$1); print $1}')
CY=$(echo "\${CURSOR}" | awk '{print $2}')
MON_NAME=$(MONITORS="$MONITORS" python3 -c '
import json,os,sys,subprocess
mons=json.loads(os.environ.get("MONITORS","[]"))
try:
    aw=json.loads(subprocess.run(["hyprctl","activewindow","-j"],capture_output=True,text=True).stdout or "{}")
    mid=aw.get("monitor",-1)
    if mid>=0:
        for m in mons:
            if m.get("id")==mid: print(m.get("name","")); sys.exit()
except: pass
for m in mons:
    if m.get("focused"): print(m.get("name","")); sys.exit()
if mons: print(mons[0].get("name",""))
' 2>/dev/null || echo "")
MON_NAME=$(echo "$MON_NAME" | head -n1 | tr -d '\r')
if [ -n "$MON_NAME" ]; then
    grim -o "$MON_NAME" "$DEST" 2>&1 || exit 1
else
    grim "$DEST" 2>&1 || exit 1
fi
META=$(DEST=$DEST CX=\${CX} CY=\${CY} MONITORS="$MONITORS" MON_NAME="$MON_NAME" python3 2>&1 << 'PYEOF'
from PIL import Image, ImageDraw, ImageFont
import os, json
dest = os.environ['DEST']
cx   = int(os.environ.get('CX', 0))
cy   = int(os.environ.get('CY', 0))
img  = Image.open(dest).convert('RGBA')
W, H = img.size
cols = 12
rows = max(5, round(cols * H / W))
cell_w = W // cols
cell_h = H // rows
overlay = Image.new('RGBA', (W, H), (0,0,0,0))
draw = ImageDraw.Draw(overlay)
font = None
for p in ['/usr/share/fonts/TTF/DejaVuSans-Bold.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', '/usr/share/fonts/TTF/LiberationSans-Bold.ttf']:
    try: font = ImageFont.truetype(p, max(14, min(28, cell_h//8))); break
    except: pass
if font is None: font = ImageFont.load_default()
for row in range(rows):
    for col in range(cols):
        n  = row * cols + col + 1
        x1 = col * cell_w; y1 = row * cell_h
        x2 = x1 + cell_w - 1; y2 = y1 + cell_h - 1
        ccx = x1 + cell_w // 2; ccy = y1 + cell_h // 2
        draw.rectangle([x1,y1,x2,y2], outline=(255,255,255,60), width=1)
        t = str(n)
        bb = draw.textbbox((ccx,ccy), t, font=font, anchor='mm')
        draw.rectangle([bb[0]-3,bb[1]-3,bb[2]+3,bb[3]+3], fill=(0,0,0,150))
        draw.text((ccx,ccy), t, fill=(255,255,255,210), font=font, anchor='mm')
monitors = json.loads(os.environ.get('MONITORS','[]'))
mon_name = os.environ.get('MON_NAME','')
off_x, off_y = 0, 0
if mon_name:
    for m in monitors:
        if m.get('name') == mon_name:
            off_x = m.get('x', 0); off_y = m.get('y', 0); break
else:
    off_x = min((m.get('x',0) for m in monitors), default=0)
    off_y = min((m.get('y',0) for m in monitors), default=0)
cx_img = cx - off_x; cy_img = cy - off_y
r = 18
if 0 <= cx_img < W and 0 <= cy_img < H:
    draw.ellipse([cx_img-r,cy_img-r,cx_img+r,cy_img+r], outline=(255,60,60,230), width=3)
    draw.line([cx_img-26,cy_img,cx_img+26,cy_img], fill=(255,60,60,230), width=2)
    draw.line([cx_img,cy_img-26,cx_img,cy_img+26], fill=(255,60,60,230), width=2)
cx_in_bounds = 0 <= cx_img < W and 0 <= cy_img < H
composite = Image.alpha_composite(img, overlay).convert('RGB')
MAX_W = 1920
sf = 1.0
if W > MAX_W:
    sf = W / MAX_W
    new_h = round(H * MAX_W / W)
    composite = composite.resize((MAX_W, new_h), Image.LANCZOS)
    W_out, H_out = MAX_W, new_h
else:
    W_out, H_out = W, H
composite.save(dest)
cx_s = round(cx_img / sf) if cx_in_bounds else -1
cy_s = round(cy_img / sf) if cx_in_bounds else -1
print(f"GRID_META:{W_out}:{H_out}:{cols}:{rows}")
print(f"SCREENSHOT_OFFSET:{off_x}:{off_y}")
print(f"IMG_SCALE:{sf:.6f}")
print(f"CURSOR_S:{cx_s}:{cy_s}")
PYEOF
)
SS_OFFSET_X=$(echo "\${META}" | grep "^SCREENSHOT_OFFSET:" | cut -d: -f2)
SS_OFFSET_Y=$(echo "\${META}" | grep "^SCREENSHOT_OFFSET:" | cut -d: -f3)
SS_OFFSET_X=\${SS_OFFSET_X:-0}
SS_OFFSET_Y=\${SS_OFFSET_Y:-0}
GRID_LINE=$(echo "\${META}" | grep "^GRID_META:")
IMG_W=$(echo "\${GRID_LINE}" | cut -d: -f2)
IMG_H=$(echo "\${GRID_LINE}" | cut -d: -f3)
GRID_COLS=$(echo "\${GRID_LINE}" | cut -d: -f4)
GRID_ROWS=$(echo "\${GRID_LINE}" | cut -d: -f5)
SCALE=$(echo "\${META}" | grep "^IMG_SCALE:" | cut -d: -f2)
SCALE=\${SCALE:-1.0}
CURSOR_LINE=$(echo "\${META}" | grep "^CURSOR_S:")
CURSOR_SS_X=$(echo "\${CURSOR_LINE}" | cut -d: -f2)
CURSOR_SS_Y=$(echo "\${CURSOR_LINE}" | cut -d: -f3)
CURSOR_SS_X=\${CURSOR_SS_X:--1}
CURSOR_SS_Y=\${CURSOR_SS_Y:--1}
echo "CURSOR_POS:\${CURSOR_SS_X}:\${CURSOR_SS_Y}"
echo "GRID:\${GRID_COLS}:\${GRID_ROWS}"
echo "IMAGE_SIZE:\${IMG_W}:\${IMG_H}"
echo "IMAGE_SCALE:\${SCALE}"
echo "SCREENSHOT_OFFSET:\${SS_OFFSET_X}:\${SS_OFFSET_Y}"
`;
                screenshotProc.targetPath = dest;
                screenshotProc.running = false;
                screenshotProc.command = ["bash", "-c", cmd];
                root.pendingFilePath = dest;
                screenshotProc.running = true;
            });
            return;
        } else if (name === "show_plan") {
            root._turnHadPlan = true;
            const title = args.title || args.plan || args.task || "Task Plan";
            // Normalize steps: handle array, string, or missing
            let steps = args.steps || args.plan_steps || [];
            if (typeof steps === "string") {
                // Model sent steps as a string — split on newlines or numbered lines
                steps = steps.split(/\n|(?=\d+\.\s)/).filter(s => s.trim()).map(s => ({ description: s.replace(/^\d+\.\s*/, "").trim() }));
            }
            if (!Array.isArray(steps)) steps = [];
            // Normalize step objects — model might send strings instead of objects
            steps = steps.map(s => typeof s === "string" ? { description: s } : s);
            const stepsText = steps.length > 0
                ? steps.map((s, i) => `${i + 1}. **${s.description || s.step || JSON.stringify(s)}**${s.tool ? ` *(${s.tool})*` : ""}`).join("\n")
                : `*${title}*`;
            const approveCmd = `echo "Plan approved — proceed with the task"`;
            const contentToAppend = `\n\n### 📋 ${title}\n\n${stepsText}\n\n\`\`\`command\n${approveCmd}\n\`\`\``;
            message.rawContent += contentToAppend;
            message.content += contentToAppend;
            message.functionCall.args.command = approveCmd;
            message.functionPending = true;
        } else if (name === "wait_for_app") {
            const app = (args.app || "").replace(/"/g, '\\"');
            const timeout = Math.min(parseInt(args.timeout) || 15, 30);
            const waitMsg = createFunctionOutputMessage(name, "", false);
            const waitId = idForMessage(waitMsg);
            root.messageIDs = [...root.messageIDs, waitId];
            root.messageByID[waitId] = waitMsg;
            commandExecutionProc.message = waitMsg;
            commandExecutionProc.baseMessageContent = waitMsg.content;
            commandExecutionProc.shellCommand = `timeout ${timeout} bash -c 'until pgrep -xi "${app}" > /dev/null 2>&1; do sleep 0.5; done && echo "${app} is ready"' 2>/dev/null || echo "${app} did not start within ${timeout}s"`;
            commandExecutionProc.running = true;
        } else if (name === "exit" || name === "done" || name === "finish") {
            // Model sometimes calls these to signal it's done — silently ignore
        } else root.addMessage(Translation.tr("Unknown function call: %1").arg(name), "assistant");
    }

    Process {
        id: logsProc
        property AiMessageData message
        stdout: StdioCollector {
            onStreamFinished: {
                logsProc.message.functionResponse = this.text;
                logsProc.message.functionName = "get_system_logs";
                requester.makeRequest();
            }
        }
    }

    Process {
        id: screenshotProc
        property string targetPath: ""
        property AiMessageData message
        stdout: StdioCollector {
            onStreamFinished: {
                // Parse CURSOR_POS, GRID, IMAGE_SIZE, IMAGE_SCALE from bash output
                const lines = this.text.split("\n");
                let imgW = 0, imgH = 0, scale = 1.0, curX = -1, curY = -1, gridCols = 8, gridRows = 5, offX = 0, offY = 0;
                for (const line of lines) {
                    if (line.startsWith("CURSOR_POS:")) {
                        const parts = line.split(":");
                        curX = parseInt(parts[1]) || 0;
                        curY = parseInt(parts[2]) || 0;
                    } else if (line.startsWith("GRID:")) {
                        const parts = line.split(":");
                        gridCols = parseInt(parts[1]) || 8;
                        gridRows = parseInt(parts[2]) || 5;
                    } else if (line.startsWith("IMAGE_SIZE:")) {
                        const parts = line.split(":");
                        imgW = parseInt(parts[1]) || 0;
                        imgH = parseInt(parts[2]) || 0;
                    } else if (line.startsWith("IMAGE_SCALE:")) {
                        scale = parseFloat(line.split(":")[1]) || 1.0;
                    } else if (line.startsWith("SCREENSHOT_OFFSET:")) {
                        const parts = line.split(":");
                        offX = parseInt(parts[1]) || 0;
                        offY = parseInt(parts[2]) || 0;
                    }
                }
                root.lastScreenshotWidth  = imgW;
                root.lastScreenshotHeight = imgH;
                root.lastScreenshotScale  = scale;
                root.lastScreenshotOffsetX = offX;
                root.lastScreenshotOffsetY = offY;
                root.lastGridCols = gridCols;
                root.lastGridRows = gridRows;

                if (imgW <= 0 || imgH <= 0) {
                    const rawPreview = this.text.length > 1200 ? this.text.substring(0, 1200) + "…" : this.text;
                    root._lastClickInfo = "";
                    root.pendingFilePath = "";
                    addFunctionOutputMessage("take_screenshot",
                        `Screenshot failed (invalid size ${imgW}×${imgH}). Usually grim wrote an empty/invalid file, Python could not read it, or GRID_META was missing from script output. Verify \`grim\`, Pillow, and Hyprland monitor names.\n\n--- Script output (debug) ---\n${rawPreview}`);
                    requester.makeRequest();
                    return;
                }

                const cursorInfo = curX >= 0 ? ` Cursor at (${curX}, ${curY}).` : "";
                const gridInfo = ` Grid: ${gridCols}×${gridRows} (cell size ${(imgW/gridCols)|0}×${(imgH/gridRows)|0}px).`;
                const isAutoFollowUp = (root._pendingVisionFollowUpKind === "execute_js" || root._pendingVisionFollowUpKind === "followup");
                const evalHint = isAutoFollowUp
                    ? " This is an automatic follow-up screenshot. Your action is complete — STOP and respond to the user in text. Do NOT call any more tools unless something clearly went wrong."
                    : root._lastClickInfo.length > 0
                        ? ` Previous action: ${root._lastClickInfo}. CHECK: did the UI change as expected? If not, try a different approach.`
                        : " Analyze the screenshot now.";
                root._lastClickInfo = "";
                root.pendingFilePath = screenshotProc.targetPath;
                addFunctionOutputMessage("take_screenshot", `Screenshot taken (${imgW}×${imgH}).${cursorInfo}${gridInfo}${evalHint}`);
                requester.makeRequest();
            }
        }
    }

    FileView {
        id: notesFileView
        path: Qt.resolvedUrl(Directories.aiMemoryPath.replace("memory.md", "notes.json"))
        blockLoading: true
        watchChanges: false
    }

    function chatToJson() {
        return root.messageIDs.map(id => {
            const message = root.messageByID[id]
            return ({
                "role": message.role,
                "rawContent": message.rawContent,
                "fileMimeType": message.fileMimeType,
                "fileUri": message.fileUri,
                "localFilePath": message.localFilePath,
                "model": message.model,
                "thinking": false,
                "done": true,
                "annotations": message.annotations,
                "annotationSources": message.annotationSources,
                "functionName": message.functionName,
                "functionCall": message.functionCall,
                "functionResponse": message.functionResponse,
                "toolCallId": message.toolCallId,
                "visibleToUser": message.visibleToUser,
            })
        })
    }

    FileView {
        id: chatSaveFile
        property string chatName: ""
        path: chatName.length > 0 ? `${Directories.aiChats}/${chatName}.json` : ""
        blockLoading: true // Prevent race conditions
    }

    FileView {
        id: chatExportFile
        blockLoading: true
    }

    // ── Training data logger ─────────────────────────────────────────────────
    // Appends completed agent traces and sessions to a JSONL file for fine-tuning.
    // Each line is a self-contained conversation with tool calls and results.
    readonly property string _trainingLogPath: Directories.aiChats + "/training_log.jsonl"

    function _appendTrainingLog(jsonStr) {
        Quickshell.execDetached(["bash", "-c", `printf '%s\n' '${jsonStr.replace(/'/g, "'\\''")}' >> '${_trainingLogPath}'`]);
    }

    function _isCleanTrace(messages) {
        // Count consecutive calls to the same tool
        let lastTool = "";
        let repeatCount = 0;
        let maxRepeat = 0;
        const toolCalls = {};
        for (const m of messages) {
            const fn = m.functionName || "";
            if (!fn) continue;
            toolCalls[fn] = (toolCalls[fn] || 0) + 1;
            if (fn === lastTool) {
                repeatCount++;
                maxRepeat = Math.max(maxRepeat, repeatCount);
            } else {
                repeatCount = 1;
                lastTool = fn;
            }
        }
        // Reject: same tool called 4+ times in a row (stuck in a loop)
        if (maxRepeat >= 4) {
            console.log(`[AI] Training skip: tool repeated ${maxRepeat}x in a row`);
            return false;
        }
        // Reject: any single tool called more than 8 times total
        for (const fn in toolCalls) {
            if (toolCalls[fn] > 8) {
                console.log(`[AI] Training skip: ${fn} called ${toolCalls[fn]}x total`);
                return false;
            }
        }
        // Reject: error/failure patterns in tool responses
        let errorCount = 0;
        for (const m of messages) {
            const resp = (m.functionResponse || "").toLowerCase();
            if (resp.includes("error:") || resp.includes("failed") || resp.includes("command not found") || resp.includes("no such file")) {
                errorCount++;
            }
        }
        if (errorCount > 2) {
            console.log(`[AI] Training skip: ${errorCount} error responses`);
            return false;
        }
        return true;
    }

    function _logAgentTrace(agentType, result) {
        const ids = root.agentMsgIDs[agentType] || [];
        if (ids.length < 2) return; // Skip trivial traces
        const messages = ids.map(id => root.agentMsgByID[id]).filter(Boolean);
        if (!_isCleanTrace(messages)) return;
        const trace = {
            timestamp: Date.now(),
            agent: agentType,
            model: root.agentCloudModel,
            systemPrompt: root.agentDefs[agentType]?.systemPrompt || "",
            result: result,
            messages: messages.map(m => ({
                role: m.role,
                content: m.rawContent || m.content || "",
                functionName: m.functionName || "",
                functionCall: m.functionCall || null,
                functionResponse: m.functionResponse || "",
                toolCallId: m.toolCallId || "",
                localFilePath: m.localFilePath || "",
                fileMimeType: m.fileMimeType || "",
            }))
        };
        root._appendTrainingLog(JSON.stringify(trace));
        console.log(`[AI] Training trace logged: ${agentType} (${ids.length} messages)`);
    }

    function _logCompletedSession() {
        const messages = root.messageIDs.map(id => root.messageByID[id]).filter(Boolean);
        if (messages.length < 2) return;
        // Only log sessions that had tool calls (interesting for training)
        const hasToolCalls = messages.some(m => m.functionName && m.functionName.length > 0);
        if (!hasToolCalls) return;
        if (root._sessionLogged) return;
        if (!_isCleanTrace(messages)) return;
        root._sessionLogged = true;
        const trace = {
            timestamp: Date.now(),
            agent: "coordinator",
            model: root.currentModel || "",
            systemPrompt: root.systemPrompt,
            result: "",
            messages: messages.map(m => ({
                role: m.role,
                content: m.rawContent || m.content || "",
                functionName: m.functionName || "",
                functionCall: m.functionCall || null,
                functionResponse: m.functionResponse || "",
                toolCallId: m.toolCallId || "",
                localFilePath: m.localFilePath || "",
                fileMimeType: m.fileMimeType || "",
            }))
        };
        root._appendTrainingLog(JSON.stringify(trace));
        console.log(`[AI] Training session logged: coordinator (${messages.length} messages)`);
    }

    Process {
        id: regionCaptureProc
        property string targetPath: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const out = this.text.trim();
                if (!out || out === "cancelled") {
                    addFunctionOutputMessage("capture_region", "Region selection cancelled.");
                    requester.makeRequest();
                    return;
                }
                root.pendingFilePath = regionCaptureProc.targetPath;
                addFunctionOutputMessage("capture_region", "Region captured. Now analyzing...");
                requester.makeRequest();
            }
        }
    }

    Process {
        id: clipboardImageProc
        property string targetPath: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const out = this.text.trim();
                if (!out || out === "no_image") {
                    addFunctionOutputMessage("read_clipboard_image", "No image found in clipboard.");
                    requester.makeRequest();
                    return;
                }
                root.pendingFilePath = clipboardImageProc.targetPath;
                addFunctionOutputMessage("read_clipboard_image", "Clipboard image attached. Now analyzing...");
                requester.makeRequest();
            }
        }
    }

    Process {
        id: windowListProc
        running: true
        command: ["bash", "-c", "hyprctl clients -j 2>/dev/null | jq -r '.[].title + \" (\" + .class + \")\"' 2>/dev/null | head -15 | tr '\\n' ',' | sed 's/,$//'" ]
        stdout: StdioCollector {
            onStreamFinished: root.openWindowsList = this.text.trim()
        }
    }

    Process {
        id: mediaContextProc
        running: true
        command: ["bash", "-c", "playerctl metadata --format '{{artist}} - {{title}}' 2>/dev/null || echo ''"]
        stdout: StdioCollector {
            onStreamFinished: root.currentMediaTitle = this.text.trim()
        }
    }

    Process {
        id: activityContextProc
        running: true
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/ii/scripts/ai/activity-context.sh"]
        stdout: StdioCollector {
            onStreamFinished: root.activityContext = this.text.trim()
        }
    }

    Timer {
        id: contextRefreshTimer
        running: true
        repeat: true
        interval: 10000
        onTriggered: {
            windowListProc.running = true;
            mediaContextProc.running = true;
            activityContextProc.running = true;
        }
    }

    // Auto-screenshot after native app search (e.g. Spotify) so AI can click results
    Timer {
        id: nativeAppSearchTimer
        interval: 2500
        repeat: false
        onTriggered: {
            root._pendingVisionFollowUpKind = "followup";
            const dest = CF.FileUtils.trimFileProtocol(`${Directories.aiSttTemp}/screenshot.png`);
            const cmd = `
DEST="${dest}"
MONITORS=$(hyprctl monitors -j 2>/dev/null | tr -d '\n' || echo '[]')
CURSOR=$(hyprctl cursorpos 2>/dev/null || echo "0, 0")
CX=$(echo "\${CURSOR}" | awk '{gsub(/,/,"",$1); print $1}')
CY=$(echo "\${CURSOR}" | awk '{print $2}')
MON_NAME=$(MONITORS="$MONITORS" python3 -c '
import json,os,sys,subprocess
mons=json.loads(os.environ.get("MONITORS","[]"))
try:
    aw=json.loads(subprocess.run(["hyprctl","activewindow","-j"],capture_output=True,text=True).stdout or "{}")
    mid=aw.get("monitor",-1)
    if mid>=0:
        for m in mons:
            if m.get("id")==mid: print(m.get("name","")); sys.exit()
except: pass
for m in mons:
    if m.get("focused"): print(m.get("name","")); sys.exit()
if mons: print(mons[0].get("name",""))
' 2>/dev/null || echo "")
MON_NAME=$(echo "$MON_NAME" | head -n1 | tr -d '\r')
if [ -n "$MON_NAME" ]; then
    grim -o "$MON_NAME" "$DEST" 2>&1 || exit 1
else
    grim "$DEST" 2>&1 || exit 1
fi
META=$(DEST=$DEST CX=\${CX} CY=\${CY} MONITORS="$MONITORS" MON_NAME="$MON_NAME" python3 2>&1 << 'PYEOF'
from PIL import Image, ImageDraw, ImageFont
import os, json
dest = os.environ['DEST']
cx   = int(os.environ.get('CX', 0))
cy   = int(os.environ.get('CY', 0))
img  = Image.open(dest).convert('RGBA')
W, H = img.size
cols = 12
rows = max(5, round(cols * H / W))
cell_w = W // cols
cell_h = H // rows
overlay = Image.new('RGBA', (W, H), (0,0,0,0))
draw = ImageDraw.Draw(overlay)
font = None
for p in ['/usr/share/fonts/TTF/DejaVuSans-Bold.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', '/usr/share/fonts/TTF/LiberationSans-Bold.ttf']:
    try: font = ImageFont.truetype(p, max(14, min(28, cell_h//8))); break
    except: pass
if font is None: font = ImageFont.load_default()
for row in range(rows):
    for col in range(cols):
        n  = row * cols + col + 1
        x1 = col * cell_w; y1 = row * cell_h
        x2 = x1 + cell_w - 1; y2 = y1 + cell_h - 1
        ccx = x1 + cell_w // 2; ccy = y1 + cell_h // 2
        draw.rectangle([x1,y1,x2,y2], outline=(255,255,255,60), width=1)
        t = str(n)
        bb = draw.textbbox((ccx,ccy), t, font=font, anchor='mm')
        draw.rectangle([bb[0]-3,bb[1]-3,bb[2]+3,bb[3]+3], fill=(0,0,0,150))
        draw.text((ccx,ccy), t, fill=(255,255,255,210), font=font, anchor='mm')
monitors = json.loads(os.environ.get('MONITORS','[]'))
mon_name = os.environ.get('MON_NAME','')
off_x, off_y = 0, 0
if mon_name:
    for m in monitors:
        if m.get('name') == mon_name:
            off_x = m.get('x', 0); off_y = m.get('y', 0); break
else:
    off_x = min((m.get('x',0) for m in monitors), default=0)
    off_y = min((m.get('y',0) for m in monitors), default=0)
cx_img = cx - off_x; cy_img = cy - off_y
r = 18
if 0 <= cx_img < W and 0 <= cy_img < H:
    draw.ellipse([cx_img-r,cy_img-r,cx_img+r,cy_img+r], outline=(255,60,60,230), width=3)
    draw.line([cx_img-26,cy_img,cx_img+26,cy_img], fill=(255,60,60,230), width=2)
    draw.line([cx_img,cy_img-26,cx_img,cy_img+26], fill=(255,60,60,230), width=2)
cx_in_bounds = 0 <= cx_img < W and 0 <= cy_img < H
composite = Image.alpha_composite(img, overlay).convert('RGB')
MAX_W = 1920
sf = 1.0
if W > MAX_W:
    sf = W / MAX_W
    new_h = round(H * MAX_W / W)
    composite = composite.resize((MAX_W, new_h), Image.LANCZOS)
    W_out, H_out = MAX_W, new_h
else:
    W_out, H_out = W, H
composite.save(dest)
cx_s = round(cx_img / sf) if cx_in_bounds else -1
cy_s = round(cy_img / sf) if cx_in_bounds else -1
print(f"GRID_META:{W_out}:{H_out}:{cols}:{rows}")
print(f"SCREENSHOT_OFFSET:{off_x}:{off_y}")
print(f"IMG_SCALE:{sf:.6f}")
print(f"CURSOR_S:{cx_s}:{cy_s}")
PYEOF
)
SS_OFFSET_X=$(echo "\${META}" | grep "^SCREENSHOT_OFFSET:" | cut -d: -f2)
SS_OFFSET_Y=$(echo "\${META}" | grep "^SCREENSHOT_OFFSET:" | cut -d: -f3)
SS_OFFSET_X=\${SS_OFFSET_X:-0}
SS_OFFSET_Y=\${SS_OFFSET_Y:-0}
GRID_LINE=$(echo "\${META}" | grep "^GRID_META:")
IMG_W=$(echo "\${GRID_LINE}" | cut -d: -f2)
IMG_H=$(echo "\${GRID_LINE}" | cut -d: -f3)
GRID_COLS=$(echo "\${GRID_LINE}" | cut -d: -f4)
GRID_ROWS=$(echo "\${GRID_LINE}" | cut -d: -f5)
SCALE=$(echo "\${META}" | grep "^IMG_SCALE:" | cut -d: -f2)
SCALE=\${SCALE:-1.0}
CURSOR_LINE=$(echo "\${META}" | grep "^CURSOR_S:")
CURSOR_SS_X=$(echo "\${CURSOR_LINE}" | cut -d: -f2)
CURSOR_SS_Y=$(echo "\${CURSOR_LINE}" | cut -d: -f3)
CURSOR_SS_X=\${CURSOR_SS_X:--1}
CURSOR_SS_Y=\${CURSOR_SS_Y:--1}
echo "CURSOR_POS:\${CURSOR_SS_X}:\${CURSOR_SS_Y}"
echo "GRID:\${GRID_COLS}:\${GRID_ROWS}"
echo "IMAGE_SIZE:\${IMG_W}:\${IMG_H}"
echo "IMAGE_SCALE:\${SCALE}"
echo "SCREENSHOT_OFFSET:\${SS_OFFSET_X}:\${SS_OFFSET_Y}"
`;
            root.requestHideSidebars();
            screenshotProc.targetPath = dest;
            screenshotProc.running = false;
            screenshotProc.command = ["bash", "-c", cmd];
            root.pendingFilePath = dest;
            screenshotProc.running = true;
        }
    }

    // Background job scheduler — checks for due cron tasks every 60s
    Process {
        id: schedulerCheckProc
        property string dueLine: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n");
                for (const line of lines) {
                    if (line.startsWith("DUE:")) {
                        const parts = line.split(":");
                        const taskId = parts[1];
                        const prompt = parts.slice(2).join(":");
                        // Mark as ran then fire the prompt as a user message
                        schedulerMarkProc.command = ["bash", "-c",
                            `python3 "${Directories.aiMemoryPath.replace('memory.md', 'memory.py')}" schedule_ran ${taskId}`];
                        schedulerMarkProc.running = true;
                        root.addMessage(prompt, "user");
                    }
                }
            }
        }
    }

    Process { id: schedulerMarkProc }

    Timer {
        id: schedulerTimer
        running: true
        repeat: true
        interval: 60000
        onTriggered: {
            schedulerCheckProc.command = ["bash", "-c",
                `python3 "${Directories.aiMemoryPath.replace('memory.md', 'memory.py')}" schedule_due 2>/dev/null`];
            schedulerCheckProc.running = true;
        }
    }

    /**
     * Saves chat to a JSON list of message objects.
     * @param chatName name of the chat
     */
    function saveChat(chatName) {
        chatSaveFile.chatName = chatName.trim()
        const saveContent = JSON.stringify(root.chatToJson())
        chatSaveFile.setText(saveContent)
        getSavedChats.running = true;
    }

    /**
     * Loads chat from a JSON list of message objects.
     * @param chatName name of the chat
     */
    function loadChat(chatName) {
        try {
            chatSaveFile.chatName = chatName.trim()
            chatSaveFile.reload()
            const saveContent = chatSaveFile.text()
            // console.log(saveContent)
            const saveData = JSON.parse(saveContent)
            root.clearMessages()
            root.messageIDs = saveData.map((_, i) => {
                return i
            })
            // console.log(JSON.stringify(messageIDs))
            for (let i = 0; i < saveData.length; i++) {
                const message = saveData[i];
                root.messageByID[i] = root.aiMessageComponent.createObject(root, {
                    "role": message.role,
                    "rawContent": message.rawContent,
                    "content": message.rawContent,
                    "fileMimeType": message.fileMimeType,
                    "fileUri": message.fileUri,
                    "localFilePath": message.localFilePath,
                    "model": message.model,
                    "thinking": message.thinking,
                    "done": message.done,
                    "annotations": message.annotations,
                    "annotationSources": message.annotationSources,
                    "functionName": message.functionName,
                    "functionCall": message.functionCall,
                    "functionResponse": message.functionResponse,
                    "toolCallId": message.toolCallId,
                    "visibleToUser": message.visibleToUser,
                });
            }
        } catch (e) {
            console.log("[AI] Could not load chat: ", e);
        } finally {
            getSavedChats.running = true;
        }
    }
}

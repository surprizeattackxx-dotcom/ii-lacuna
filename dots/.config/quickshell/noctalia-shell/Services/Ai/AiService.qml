pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Native AI chat service (Stage 1 port of illogical-impulse's Ai.qml — the clean
// multi-provider streaming chat, without the tool/agent/MCP layer yet).
// API keys live in ~/.config/noctalia/ai-keys.json: { "gemini": "...", "openai": "...", "mistral": "..." }
Singleton {
    id: root

    readonly property string interfaceRole: "interface"
    readonly property string apiKeyEnvVarName: "API_KEY"

    property real temperature: 0.7
    property bool busy: requester.running || _inToolLoop

    property bool toolsEnabled: true
    property int consecutiveToolCalls: 0
    property int maxConsecutiveToolCalls: 8
    property bool _inToolLoop: false

    property string systemPrompt: "You are Aria, the coordinator of a Linux desktop sidebar assistant " +
        "(Hyprland/Wayland). Answer directly in GitHub-flavored markdown; use fenced code blocks for code.\n\n" +
        "You can call tools yourself: run_shell_command, control_hyprland, control_media, list_windows, " +
        "get_system_logs, calculate, web_search, read_url. For coding & deep technical work (writing/refactoring/" +
        "debugging code, editing project files, build/test/git) use opencode_task — it delegates to OpenCode, an " +
        "autonomous coding agent; give it one complete self-contained task. You also coordinate specialist agents " +
        "via call_agent (scout=web research, forge=system/shell, vector=desktop windows, sage=general). Do simple, " +
        "single-step things yourself; delegate multi-step specialist work to ONE agent at a time and use its returned result. " +
        "After a tool/agent returns, use the result to answer. Don't repeat a failing call — change approach. " +
        "Be careful with destructive shell commands and confirm first unless clearly authorized."

    // ─── Specialist agents (Stage 3) ───
    property string activeAgentType: ""   // "" = Aria (coordinator)
    property var agentStack: []           // [{type, parentType, toolCallId, savedCalls, messages:[]}]
    property int maxAgentDepth: 3
    readonly property var agentDefs: ({
        "scout": {
            displayName: "Scout",
            systemPrompt: "You are Scout, a web research specialist. Use web_search and read_url to gather accurate, current information. Be thorough and cite URLs/sources when useful. ALWAYS finish by calling return_result with your findings — never answer in plain text without calling return_result.",
            toolNames: ["web_search", "read_url", "calculate"]
        },
        "forge": {
            displayName: "Forge",
            systemPrompt: "You are Forge, a Linux system specialist. Use run_shell_command, control_hyprland, control_media, get_system_logs, and list_windows to inspect and control the system. Be careful with destructive commands. When your task is complete, call return_result with the outcome.",
            toolNames: ["run_shell_command", "control_hyprland", "control_media", "get_system_logs", "list_windows", "calculate"]
        },
        "vector": {
            displayName: "Vector",
            systemPrompt: "You are Vector, a desktop/compositor specialist on Hyprland. Use list_windows and control_hyprland (e.g. 'dispatch workspace 2', 'dispatch movetoworkspace 3') to inspect and control windows and workspaces. When your task is complete, call return_result with a summary.",
            toolNames: ["list_windows", "control_hyprland", "run_shell_command"]
        },
        "sage": {
            displayName: "Sage",
            systemPrompt: "You are Sage, a general-purpose assistant. Use run_shell_command and calculate as needed to complete the task. When done, call return_result with your answer.",
            toolNames: ["run_shell_command", "calculate"]
        }
    })

    // Cloud models. key_id maps into the ai-keys.json file.
    property var baseModels: [
        ({
            name: "Gemini 2.5 Flash", icon: "google-symbolic",
            endpoint: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:streamGenerateContent",
            model: "gemini-2.5-flash", requires_key: true, key_id: "gemini", api_format: "gemini",
            key_get_link: "https://aistudio.google.com/apikey"
        }),
        ({
            name: "GPT-4o mini", icon: "openai-symbolic",
            endpoint: "https://api.openai.com/v1/chat/completions",
            model: "gpt-4o-mini", requires_key: true, key_id: "openai", api_format: "openai",
            key_get_link: "https://platform.openai.com/api-keys"
        }),
        ({
            name: "Mistral Medium", icon: "mistral-symbolic",
            endpoint: "https://api.mistral.ai/v1/chat/completions",
            model: "mistral-medium-2505", requires_key: true, key_id: "mistral", api_format: "mistral",
            key_get_link: "https://console.mistral.ai/api-keys"
        })
    ]
    // Locally-running Ollama models (discovered via its API; OpenAI-compatible).
    property var ollamaModels: []
    readonly property string ollamaEndpoint: "http://localhost:11434/v1/chat/completions"

    readonly property var models: baseModels.concat(ollamaModels)
    property int currentModelId: 0
    readonly property var currentModel: models[currentModelId] || baseModels[0]

    // ─── Ollama discovery ───
    Process {
        id: ollamaProbe
        running: true
        command: ["bash", "-c", "curl -s --max-time 2 http://localhost:11434/api/tags || echo '{}'"]
        stdout: StdioCollector {
            id: ollamaCollector
            onStreamFinished: {
                try {
                    const j = JSON.parse(ollamaCollector.text || "{}");
                    const list = (j.models || []).map(function (m) {
                        return ({
                            name: "Ollama: " + m.name, icon: "ollama-symbolic",
                            endpoint: root.ollamaEndpoint, model: m.name,
                            requires_key: false, key_id: "", api_format: "openai",
                            extraParams: ({ "num_ctx": 32768 })
                        });
                    });
                    root.ollamaModels = list;
                } catch (e) {
                    root.ollamaModels = [];
                }
            }
        }
    }
    function refreshOllama() { ollamaProbe.running = true; }

    property var apiKeys: ({})

    // Conversation — array of AiMessageData. Reassigned on append so views refresh.
    property var messages: []
    // What the UI renders (raw tool-result messages stay in context but are hidden).
    readonly property var visibleMessages: messages.filter(function (m) { return m.role !== "tool"; })
    signal messageAdded(var message)
    signal responseStarted()
    signal responseFinished()

    property var apiStrategies: ({
        "openai": openaiStrategy,
        "gemini": geminiStrategy,
        "mistral": mistralStrategy
    })

    OpenAiApiStrategy { id: openaiStrategy }
    GeminiApiStrategy { id: geminiStrategy }
    MistralApiStrategy { id: mistralStrategy }

    Component { id: aiMessageComponent; AiMessageData {} }

    // ─── API keys (read from the gnome keyring, exactly like ii's KeyringStorage) ───
    // ii stores a JSON blob under attribute application=illogical-impulse; keys live in .apiKeys.
    Process {
        id: keyLoader
        running: true
        command: ["secret-tool", "lookup", "application", "illogical-impulse"]
        stdout: StdioCollector {
            id: keyOut
            onStreamFinished: {
                try {
                    const data = keyOut.text || "";
                    if (data.length === 0 || data[0] !== "{") { return; }
                    const blob = JSON.parse(data);
                    root.apiKeys = blob.apiKeys || ({});
                } catch (e) {
                    root.apiKeys = ({});
                }
            }
        }
    }
    function reloadKeys() { keyLoader.running = true; }
    function hasKeyFor(model) {
        if (!model || !model.requires_key) return true;
        return !!(root.apiKeys && root.apiKeys[model.key_id] && root.apiKeys[model.key_id].length > 0);
    }

    function setModel(index) {
        if (index >= 0 && index < models.length) root.currentModelId = index;
    }

    function addMessage(content, role) {
        const msg = aiMessageComponent.createObject(root, {
            "role": role,
            "content": content,
            "rawContent": content,
            "thinking": false,
            "done": true,
        });
        root.messages = [...root.messages, msg];
        root.messageAdded(msg);
        return msg;
    }

    function clearChat() {
        root.messages = [];
        root.activeAgentType = "";
        root.agentStack = [];
        root.consecutiveToolCalls = 0;
        root._inToolLoop = false;
    }

    function sendMessage(text) {
        if (!text || text.trim().length === 0) return;
        const model = root.currentModel;
        if (model.requires_key && !root.hasKeyFor(model)) {
            addMessage(`No API key set for **${model.name}**. Add it to \`~/.config/noctalia/ai-keys.json\` as \`"${model.key_id}": "<key>"\` — get one at ${model.key_get_link}`, root.interfaceRole);
            return;
        }
        addMessage(text, "user");
        // A new user turn always starts in coordinator context.
        root.activeAgentType = "";
        root.agentStack = [];
        root.consecutiveToolCalls = 0;
        makeRequest();
    }

    // ─── Context helpers (main conversation vs. an agent's sub-conversation) ───
    function _mkMsg(props) { return aiMessageComponent.createObject(root, props); }
    function _ctxMessages() {
        if (root.activeAgentType && root.agentStack.length > 0) return root.agentStack[root.agentStack.length - 1].messages;
        return root.messages;
    }
    function _ctxAppend(msg) {
        if (root.activeAgentType && root.agentStack.length > 0) {
            const i = root.agentStack.length - 1;
            const frame = root.agentStack[i];
            frame.messages = [...frame.messages, msg];
            root.agentStack[i] = frame;
        } else {
            root.messages = [...root.messages, msg];
            root.messageAdded(msg);
        }
    }
    function _ctxSystemPrompt() {
        if (root.activeAgentType && root.agentDefs[root.activeAgentType]) return root.agentDefs[root.activeAgentType].systemPrompt;
        return root.systemPrompt;
    }
    function _ctxToolDefs() {
        if (root.activeAgentType && root.agentDefs[root.activeAgentType]) {
            const names = root.agentDefs[root.activeAgentType].toolNames;
            const subset = AiTools.defs.filter(function (d) { return names.indexOf(d.name) >= 0; });
            return subset.concat([AiTools.returnResultDef]);
        }
        return AiTools.defs.concat([AiTools.callAgentDef]);
    }

    // ─── Streaming request ───
    function makeRequest() {
        const model = root.currentModel;
        const strategy = root.apiStrategies[model.api_format || "openai"];
        strategy.reset();
        requester.currentStrategy = strategy;
        requester._finished = false;
        requester.pendingCall = null;

        // API key into the environment
        if (model.requires_key) {
            const env = {};
            env[root.apiKeyEnvVarName] = (root.apiKeys && root.apiKeys[model.key_id]) ? root.apiKeys[model.key_id] : "";
            requester.environment = env;
        } else {
            requester.environment = ({});
        }

        const endpoint = strategy.buildEndpoint(model);
        const contextArr = root._ctxMessages().filter(m => m.role !== root.interfaceRole);
        const tools = root.toolsEnabled ? AiTools.formatDefs(model.api_format || "openai", root._ctxToolDefs()) : [];
        const data = strategy.buildRequestData(model, contextArr, root._ctxSystemPrompt(), root.temperature, tools, "");

        // Assistant message placeholder (observable — UI binds to .content)
        requester.message = aiMessageComponent.createObject(root, {
            "role": "assistant", "model": model.name, "content": "", "rawContent": "",
            "thinking": true, "done": false,
        });
        root._ctxAppend(requester.message);
        root.responseStarted();

        const authHeader = strategy.buildAuthorizationHeader(root.apiKeyEnvVarName);
        const escapedData = JSON.stringify(data).replace(/'/g, "'\\''");
        const curlCmd = `curl --no-buffer --max-time 120 --connect-timeout 15 "${endpoint}"`
            + ` -H 'Content-Type: application/json'`
            + (authHeader ? ` ${authHeader}` : "")
            + ` --data '${escapedData}'`;
        // No script file needed for text chat — run curl directly (env carries API_KEY).
        const scriptBody = strategy.finalizeScriptContent(curlCmd);
        requester.command = ["bash", "-c", scriptBody];
        requester.running = true;
    }

    function _handleStreamResult(result) {
        if (!result) return;
        if (result.functionCall) {
            // Mark the assistant message as having made this call (strategies that
            // need functionName set it themselves; OpenAI relies on functionCall only).
            requester.message.functionCall = result.functionCall;
            requester.message.toolCallId = result.functionCall.id || requester.message.toolCallId || "";
            requester.pendingCall = result.functionCall;
        }
        if (result.finished) _finishRequest();
    }

    function _appendToolResult(call, result) {
        root._ctxAppend(_mkMsg({
            "role": "tool", "functionName": call.name, "functionResponse": result,
            "toolCallId": call.id || "", "content": "", "rawContent": "",
            "done": true, "visibleToUser": false
        }));
    }

    function _finishRequest() {
        if (requester._finished) return;
        requester._finished = true;
        if (requester.message) requester.message.done = true;

        const call = requester.pendingCall;
        requester.pendingCall = null;

        if (call) {
            // Control tools (flow, not shell execution)
            if (call.name === "call_agent") { root._startAgent(call); return; }
            if (call.name === "return_result") {
                root._finishAgent((call.args && call.args.result) || (requester.message ? requester.message.content : "") || "(no result)");
                return;
            }

            // Regular tool — guard against runaway loops
            root.consecutiveToolCalls++;
            if (root.consecutiveToolCalls > root.maxConsecutiveToolCalls) {
                if (root.activeAgentType) { root._finishAgent("[stopped: too many tool calls]"); return; }
                addMessage("[Stopped: too many consecutive tool calls without a final answer.]", root.interfaceRole);
                root._inToolLoop = false;
                root.responseFinished();
                return;
            }
            root._inToolLoop = true;
            AiTools.execute(call.name, call.args || {}, function (toolResult) {
                root._appendToolResult(call, toolResult);
                makeRequest();
            });
            return;
        }

        // No tool call this turn.
        if (root.activeAgentType) {
            // An agent produced a plain-text answer → use it as its result.
            root._finishAgent(requester.message ? (requester.message.content || "(no result)") : "(no result)");
            return;
        }
        root.consecutiveToolCalls = 0;
        root._inToolLoop = false;
        root.responseFinished();
    }

    // Start a specialist agent sub-conversation seeded with the task.
    function _startAgent(call) {
        const agentType = (((call.args && call.args.agent) || "") + "").toLowerCase().trim();
        const task = (call.args && call.args.task) || "";
        if (!root.agentDefs[agentType] || root.agentStack.length >= root.maxAgentDepth) {
            root._appendToolResult(call, "Error: unknown or unavailable agent '" + agentType + "' (use scout|forge|vector|sage).");
            makeRequest();
            return;
        }
        const frame = {
            type: agentType,
            parentType: root.activeAgentType,
            toolCallId: call.id || "",
            savedCalls: root.consecutiveToolCalls,
            messages: [ _mkMsg({ "role": "user", "content": task, "rawContent": task, "done": true }) ]
        };
        root.agentStack = [...root.agentStack, frame];
        root.activeAgentType = agentType;
        root.consecutiveToolCalls = 0;
        root._inToolLoop = true;
        makeRequest();
    }

    // Finish the current agent: pop its frame, inject result into the parent context.
    function _finishAgent(result) {
        if (root.agentStack.length === 0) {
            root.consecutiveToolCalls = 0;
            root._inToolLoop = false;
            root.responseFinished();
            return;
        }
        const frame = root.agentStack[root.agentStack.length - 1];
        root.agentStack = root.agentStack.slice(0, -1);
        root.activeAgentType = frame.parentType;
        root.consecutiveToolCalls = frame.savedCalls;
        const label = (root.agentDefs[frame.type] && root.agentDefs[frame.type].displayName) || frame.type;
        // Inject as the call_agent tool result in the (now active) parent context.
        root._ctxAppend(_mkMsg({
            "role": "tool", "functionName": "call_agent", "functionResponse": "[" + label + "]: " + result,
            "toolCallId": frame.toolCallId, "content": "", "rawContent": "", "done": true, "visibleToUser": false
        }));
        makeRequest();
    }

    Process {
        id: requester
        property var message
        property var currentStrategy
        property var pendingCall: null
        property bool _finished: false

        stdout: SplitParser {
            onRead: data => {
                if (data.length === 0) return;
                if (requester.message && requester.message.thinking) requester.message.thinking = false;
                try {
                    root._handleStreamResult(requester.currentStrategy.parseResponseLine(data, requester.message));
                } catch (e) {
                    console.log("[AI] parse error:", e);
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                root._handleStreamResult(requester.currentStrategy.onRequestFinished(requester.message) || {});
            } catch (e) {}
            if (!requester._finished) _finishRequest();
        }
    }

    Component.onCompleted: reloadKeys()
}

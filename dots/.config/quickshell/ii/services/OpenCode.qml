pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property int port: Config.options.opencode?.port ?? 47821
    readonly property string baseUrl: `http://127.0.0.1:${port}`

    property bool serverReady: false
    property bool busy: false
    property string sessionId: ""
    property string providerID: ""
    property string modelID: ""
    property string agent: Config.options.opencode?.agent ?? ""
    property var models: []
    property var agents: []
    property var messages: []
    property var pendingPermissions: []

    property var _msgMap: ({})
    property var _msgOrder: []

    function start() {
        if (serverReady || serveProc.running)
            return _afterReady();
        serveProc.running = true;
        healthTimer.start();
    }

    function _afterReady() {
        if (eventProc.running === false) eventProc.running = true;
        if (root.models.length === 0) loadModels();
        if (root.agents.length === 0) loadAgents();
        if (root.sessionId === "") createSession();
    }

    function loadAgents() {
        _xhr("GET", "/agent", null, data => {
            if (!data) return;
            const list = Array.isArray(data) ? data : (data.agents ?? []);
            root.agents = list.map(a => (typeof a === "string" ? a : (a.name ?? ""))).filter(Boolean);
        });
    }

    function _xhr(method, path, body, onOk, onErr) {
        const xhr = new XMLHttpRequest();
        xhr.open(method, root.baseUrl + path);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status >= 200 && xhr.status < 300) {
                let parsed = null;
                try { parsed = xhr.responseText ? JSON.parse(xhr.responseText) : null; } catch (e) {}
                if (onOk) onOk(parsed);
            } else {
                console.log("[OpenCode] request failed", method, path, xhr.status);
                if (onErr) onErr(xhr.status);
            }
        };
        xhr.send(body ? JSON.stringify(body) : "");
    }

    // One-shot delegation: run a task in an isolated session, return final text via onDone.
    property var _pendingTasks: []
    function runTask(prompt, onDone) {
        if (!prompt || prompt.length === 0) { onDone("No task provided."); return; }
        root._pendingTasks = [...root._pendingTasks, { prompt: prompt, onDone: onDone }];
        root.start();
        taskPump.start();
    }

    function _execTask(t) {
        _xhr("POST", "/session", {}, (data) => {
            if (!data?.id) { t.onDone("OpenCode: failed to create session."); return; }
            const body = { parts: [{ type: "text", text: t.prompt }] };
            if (root.providerID !== "" && root.modelID !== "")
                body.model = { providerID: root.providerID, modelID: root.modelID };
            if (root.agent !== "") body.agent = root.agent;
            _xhr("POST", `/session/${data.id}/message`, body, (resp) => {
                let txt = "";
                for (const p of (resp?.parts ?? []))
                    if (p.type === "text" && p.text) txt += p.text;
                t.onDone(txt.trim().length > 0 ? txt.trim() : "OpenCode finished with no text output.");
            }, (status) => t.onDone(`OpenCode request failed (HTTP ${status}).`));
        }, (status) => t.onDone(`OpenCode could not start a session (HTTP ${status}).`));
    }

    Timer {
        id: taskPump
        interval: 300
        repeat: true
        property int tries: 0
        onTriggered: {
            if (!root.serverReady) { tries++; if (tries > 80) { stop(); tries = 0; for (const t of root._pendingTasks) t.onDone("OpenCode server did not start."); root._pendingTasks = []; } return; }
            tries = 0;
            if (root._pendingTasks.length === 0) { stop(); return; }
            const t = root._pendingTasks[0];
            root._pendingTasks = root._pendingTasks.slice(1);
            root._execTask(t);
        }
    }

    function loadModels() {
        _xhr("GET", "/config/providers", null, data => {
            if (!data) return;
            const out = [];
            const providers = data.providers ?? data ?? [];
            for (const p of providers) {
                const pid = p.id ?? p.providerID;
                const mdls = p.models ? Object.keys(p.models) : [];
                for (const m of mdls)
                    out.push({ providerID: pid, modelID: m, label: `${pid}/${m}` });
            }
            root.models = out;
            if (root.providerID === "" && out.length > 0) {
                const want = Config.options.opencode?.model ?? "";
                const match = out.find(x => x.label === want);
                const chosen = match ?? out[0];
                root.providerID = chosen.providerID;
                root.modelID = chosen.modelID;
            }
        });
    }

    function createSession() {
        _xhr("POST", "/session", {}, data => {
            if (data?.id) root.sessionId = data.id;
        });
    }

    function newSession() {
        root._msgMap = ({});
        root._msgOrder = [];
        root.messages = [];
        root.pendingPermissions = [];
        root.sessionId = "";
        createSession();
    }

    function setModel(providerID, modelID) {
        root.providerID = providerID;
        root.modelID = modelID;
    }

    function sendPrompt(text) {
        if (text.length === 0) return;
        root.start();
        if (root.sessionId === "") {
            retrySendTimer.pendingText = text;
            retrySendTimer.start();
            return;
        }
        const part = { type: "text", text: text };
        const body = { parts: [part] };
        if (root.providerID !== "" && root.modelID !== "")
            body.model = { providerID: root.providerID, modelID: root.modelID };
        if (root.agent !== "") body.agent = root.agent;
        root.busy = true;
        _xhr("POST", `/session/${root.sessionId}/message`, body, () => {});
    }

    function abort() {
        if (root.sessionId === "") return;
        _xhr("POST", `/session/${root.sessionId}/abort`, {}, () => {});
    }

    function respondPermission(permissionID, response) {
        const perm = root.pendingPermissions.find(p => p.id === permissionID);
        const sid = perm?.sessionID ?? root.sessionId;
        _xhr("POST", `/session/${sid}/permissions/${permissionID}`, { response: response }, () => {});
        root.pendingPermissions = root.pendingPermissions.filter(p => p.id !== permissionID);
    }

    function _touch() {
        root.messages = root._msgOrder.map(id => root._msgMap[id]).filter(Boolean);
    }

    function _upsertMessage(info) {
        if (!info?.id) return;
        const existing = root._msgMap[info.id];
        if (existing) {
            existing.role = info.role ?? existing.role;
        } else {
            root._msgMap[info.id] = { id: info.id, role: info.role ?? "assistant", parts: {}, order: [] };
            root._msgOrder = [...root._msgOrder, info.id];
        }
        _touch();
    }

    function _upsertPart(part) {
        if (!part?.messageID || !part?.id) return;
        let msg = root._msgMap[part.messageID];
        if (!msg) {
            _upsertMessage({ id: part.messageID, role: "assistant" });
            msg = root._msgMap[part.messageID];
        }
        if (!msg.parts[part.id]) msg.order = [...msg.order, part.id];
        msg.parts[part.id] = part;
        _touch();
    }

    function _applyDelta(p) {
        const msg = root._msgMap[p.messageID];
        if (!msg) return;
        let part = msg.parts[p.partID];
        if (!part) {
            part = { id: p.partID, messageID: p.messageID, type: p.field === "reasoning" ? "reasoning" : "text", text: "" };
            msg.parts[p.partID] = part;
            msg.order = [...msg.order, p.partID];
        }
        if (p.field === "text" || p.field === "reasoning")
            part.text = (part.text ?? "") + (p.delta ?? "");
        _touch();
    }

    function _handleEvent(evt) {
        const t = evt.type;
        const props = evt.properties ?? {};
        if (t === "message.updated") {
            _upsertMessage(props.info);
        } else if (t === "message.part.updated") {
            _upsertPart(props.part);
        } else if (t === "message.part.delta") {
            _applyDelta(props);
        } else if (t === "message.removed") {
            if (props.messageID && root._msgMap[props.messageID]) {
                delete root._msgMap[props.messageID];
                root._msgOrder = root._msgOrder.filter(id => id !== props.messageID);
                _touch();
            }
        } else if (t === "session.idle" || t === "session.error") {
            root.busy = false;
        } else if (t === "permission.asked") {
            const perm = props;
            if (perm?.id) root.pendingPermissions = [...root.pendingPermissions.filter(p => p.id !== perm.id), perm];
        } else if (t === "permission.replied") {
            if (props?.id) root.pendingPermissions = root.pendingPermissions.filter(p => p.id !== props.id);
        }
    }

    Process {
        id: serveProc
        command: ["opencode", "serve", "--port", String(root.port), "--hostname", "127.0.0.1"]
        running: Config.options.opencode?.autostart ?? false
    }

    Process {
        id: eventProc
        running: false
        command: ["curl", "--no-buffer", "-sN", `${root.baseUrl}/event`]
        stdout: SplitParser {
            onRead: line => {
                if (!line.startsWith("data:")) return;
                const payload = line.slice(5).trim();
                if (payload.length === 0) return;
                try {
                    const evt = JSON.parse(payload);
                    if (evt.type === "server.connected") return;
                    root._handleEvent(evt);
                } catch (e) {}
            }
        }
        onExited: {
            if (root.serverReady) running = true; // reconnect while server lives
        }
    }

    Timer {
        id: healthTimer
        interval: 400
        repeat: true
        property int tries: 0
        onTriggered: {
            tries++;
            const xhr = new XMLHttpRequest();
            xhr.open("GET", root.baseUrl + "/global/health");
            xhr.onreadystatechange = () => {
                if (xhr.readyState !== XMLHttpRequest.DONE) return;
                if (xhr.status >= 200 && xhr.status < 300) {
                    healthTimer.stop();
                    healthTimer.tries = 0;
                    root.serverReady = true;
                    root._afterReady();
                }
            };
            xhr.send();
            if (tries > 50) { healthTimer.stop(); tries = 0; }
        }
    }

    Timer {
        id: retrySendTimer
        interval: 200
        repeat: true
        property string pendingText: ""
        property int tries: 0
        onTriggered: {
            tries++;
            if (root.sessionId !== "") {
                stop(); tries = 0;
                const t = pendingText; pendingText = "";
                root.sendPrompt(t);
            } else if (tries > 40) { stop(); tries = 0; }
        }
    }
}

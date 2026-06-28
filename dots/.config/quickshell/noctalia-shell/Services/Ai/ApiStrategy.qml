import QtQuick

// Provider strategy interface (ported from illogical-impulse).
QtObject {
    function buildEndpoint(model): string { throw new Error("Not implemented") }
    function buildRequestData(model, messages, systemPrompt: string, temperature: real, tools: list<var>, filePath: string) { throw new Error("Not implemented") }
    function buildAuthorizationHeader(apiKeyEnvVarName: string): string { throw new Error("Not implemented") }
    function parseResponseLine(line: string, message) { throw new Error("Not implemented") }
    function onRequestFinished(message): var { return {} }
    function reset() { }
    function buildScriptFileSetup(filePath) { return "" }
    function finalizeScriptContent(scriptContent: string): string { return scriptContent }
}

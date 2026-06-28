import QtQuick

ApiStrategy {
    property bool isReasoning: false
    property var pendingToolCall: null

    function buildEndpoint(model): string {
        return model.endpoint;
    }

    function buildRequestData(model, messages, systemPrompt: string, temperature: real, tools: list<var>, filePath: string) {
        const mappedMessages = messages.map(message => {
            if (message.functionName && message.functionName.length > 0) {
                return {
                    "role": "tool",
                    "tool_call_id": message.toolCallId || `call_${message.functionName}`,
                    "content": message.functionResponse || "",
                };
            }
            if (message.role === "assistant" && message.functionCall && message.functionCall.name) {
                const callId = message.toolCallId || `call_${message.functionCall.name}`;
                return {
                    "role": "assistant",
                    "content": "",
                    "tool_calls": [{
                        "id": callId,
                        "type": "function",
                        "function": {
                            "name": message.functionCall.name,
                            "arguments": JSON.stringify(message.functionCall.args || {}),
                        }
                    }]
                };
            }
            return {
                "role": message.role,
                "content": message.rawContent,
            };
        });
        const dedupedMessages = [];
        for (let i = 0; i < mappedMessages.length; i++) {
            const m = mappedMessages[i];
            const last = dedupedMessages.length > 0 ? dedupedMessages[dedupedMessages.length - 1] : null;
            if (m.role === "tool" && last && last.role === "tool" && m.tool_call_id === last.tool_call_id) {
                const a = last.content || "";
                const b = m.content || "";
                dedupedMessages[dedupedMessages.length - 1] = b.length >= a.length ? m : last;
                continue;
            }
            dedupedMessages.push(m);
        }
        const hasTools = tools && tools.length > 0;
        let baseData = {
            "model": model.model,
            "messages": [
                {role: "system", content: systemPrompt},
                ...dedupedMessages
            ],
            "stream": true,
            "temperature": temperature,
            "max_tokens": 8192,
        };
        if (hasTools) {
            baseData.tools = tools;
            baseData.tool_choice = "auto";
            baseData.parallel_tool_calls = false;
        }
        return model.extraParams ? Object.assign({}, baseData, model.extraParams) : baseData;
    }

    function buildAuthorizationHeader(apiKeyEnvVarName: string): string {
        return `-H "Authorization: Bearer \$\{${apiKeyEnvVarName}\}"`;
    }

    function parseResponseLine(line, message) {
        let cleanData = line.trim();
        if (cleanData.startsWith("data:")) {
            cleanData = cleanData.slice(5).trim();
        }
        if (!cleanData || cleanData.startsWith(":")) return {};
        if (cleanData === "[DONE]") {
            return { finished: true };
        }
        try {
            const dataJson = JSON.parse(cleanData);
            if (dataJson.error) {
                const errorMsg = `**Error**: ${dataJson.error.message || JSON.stringify(dataJson.error)}`;
                message.rawContent += errorMsg;
                message.content += errorMsg;
                return { finished: true };
            }
            let newContent = "";
            const responseContent = dataJson.choices[0]?.delta?.content || dataJson.message?.content;
            const responseReasoning = dataJson.choices[0]?.delta?.reasoning || dataJson.choices[0]?.delta?.reasoning_content;
            if (responseContent && responseContent.length > 0) {
                if (isReasoning) {
                    isReasoning = false;
                    const endBlock = "\n\n</think>\n\n";
                    message.content += endBlock;
                    message.rawContent += endBlock;
                }
                newContent = responseContent;
            } else if (responseReasoning && responseReasoning.length > 0) {
                if (!isReasoning) {
                    isReasoning = true;
                    const startBlock = "\n\n<think>\n\n";
                    message.rawContent += startBlock;
                    message.content += startBlock;
                }
                newContent = responseReasoning;
            }
            message.content += newContent;
            message.rawContent += newContent;

            const toolCallDelta = dataJson.choices?.[0]?.delta?.tool_calls?.[0];
            if (toolCallDelta) {
                const cur = pendingToolCall || { id: "", name: "", arguments: "" };
                pendingToolCall = {
                    id: cur.id || toolCallDelta.id || "",
                    name: (cur.name || toolCallDelta.function?.name || ""),
                    arguments: cur.arguments + (toolCallDelta.function?.arguments || ""),
                };
            }
            const finishReason = dataJson.choices?.[0]?.finish_reason;
            if (finishReason === "tool_calls") {
                if (!pendingToolCall?.name) {
                    const msgToolCall = dataJson.choices?.[0]?.message?.tool_calls?.[0];
                    if (msgToolCall?.function?.name) {
                        pendingToolCall = {
                            id: msgToolCall.id || "",
                            name: msgToolCall.function.name,
                            arguments: msgToolCall.function.arguments || "",
                        };
                    }
                }
                if (pendingToolCall?.name) {
                    let parsedArgs = {};
                    try { parsedArgs = JSON.parse(pendingToolCall.arguments); } catch(e) {}
                    const callId = pendingToolCall.id || `call_${pendingToolCall.name}`;
                    const call = { id: callId, name: pendingToolCall.name, args: parsedArgs };
                    pendingToolCall = null;
                    return { functionCall: call };
                }
            }
            if (dataJson.usage) {
                return {
                    tokenUsage: {
                        input: dataJson.usage.prompt_tokens ?? -1,
                        output: dataJson.usage.completion_tokens ?? -1,
                        total: dataJson.usage.total_tokens ?? -1
                    }
                };
            }
            if (dataJson.done) {
                return { finished: true };
            }
        } catch (e) {
            console.log("[AI] OpenAI: Could not parse line: ", e);
        }
        return {};
    }

    function onRequestFinished(message) { return {}; }

    function reset() {
        isReasoning = false;
        pendingToolCall = null;
    }
}

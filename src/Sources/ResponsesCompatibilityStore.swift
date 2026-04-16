import Foundation

struct ResponsesRequestPreparation {
    let path: String
    let body: String
    let pendingResponse: PendingStoredResponse?
}

struct PendingStoredResponse {
    let requestTranscript: String
    let previousResponseID: String?
    let requestedStore: Bool
}

final class ResponsesCompatibilityStore {
    private struct StoredResponse {
        let transcript: String
    }

    private let queue = DispatchQueue(label: "io.automaze.vibeproxy.responses-compat-store")
    private var storedResponses: [String: StoredResponse] = [:]

    func normalizePath(_ path: String) -> String {
        let components = path.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let basePath = components.first.map(String.init) ?? path
        let querySuffix = components.count > 1 ? "?\(components[1])" : ""

        if basePath == "/api/v1" {
            return "/v1" + querySuffix
        }
        if basePath.hasPrefix("/api/v1/") {
            return String(basePath.dropFirst("/api".count)) + querySuffix
        }

        return path
    }

    func prepareRequest(path: String, body: String) -> ResponsesRequestPreparation {
        let normalizedPath = normalizePath(path)
        guard isResponsesPath(normalizedPath),
              let jsonData = body.data(using: .utf8),
              var json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return ResponsesRequestPreparation(path: normalizedPath, body: body, pendingResponse: nil)
        }

        let requestedStore = (json["store"] as? Bool) == true
        let previousResponseID = json["previous_response_id"] as? String
        var requestTranscript: String?

        if let previousResponseID,
           let previousTranscript = transcript(for: previousResponseID),
           let currentInput = extractInputText(from: json["input"]) {
            requestTranscript = appendTurn(previousTranscript, role: "User", text: currentInput)
            json["input"] = requestTranscript
            json.removeValue(forKey: "previous_response_id")
        } else if let currentInput = extractInputText(from: json["input"]) {
            requestTranscript = appendTurn(nil, role: "User", text: currentInput)
        }

        if json["store"] != nil {
            json.removeValue(forKey: "store")
        }

        guard let modifiedBody = serialize(json) else {
            return ResponsesRequestPreparation(path: normalizedPath, body: body, pendingResponse: nil)
        }

        let pendingResponse = requestTranscript.map {
            PendingStoredResponse(
                requestTranscript: $0,
                previousResponseID: previousResponseID,
                requestedStore: requestedStore
            )
        }

        return ResponsesRequestPreparation(path: normalizedPath, body: modifiedBody, pendingResponse: pendingResponse)
    }

    func jsonResponseTransformer(for pendingResponse: PendingStoredResponse?) -> ((String) -> String)? {
        guard let pendingResponse else { return nil }

        return { [weak self] body in
            guard let self else { return body }
            return self.storeAndRewriteResponse(body, pendingResponse: pendingResponse)
        }
    }

    func transcript(for responseID: String) -> String? {
        queue.sync {
            storedResponses[responseID]?.transcript
        }
    }

    private func isResponsesPath(_ path: String) -> Bool {
        let basePath = path.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? path
        return basePath == "/v1/responses"
    }

    private func storeAndRewriteResponse(_ body: String, pendingResponse: PendingStoredResponse) -> String {
        guard let jsonData = body.data(using: .utf8),
              var json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return body
        }

        if let responseID = json["id"] as? String {
            let assistantText = extractAssistantOutputText(from: json["output"])
            let transcript = appendTurn(
                pendingResponse.requestTranscript,
                role: "Assistant",
                text: assistantText
            )

            queue.async {
                self.storedResponses[responseID] = StoredResponse(transcript: transcript)
            }
        }

        if pendingResponse.requestedStore {
            json["store"] = true
        }
        if let previousResponseID = pendingResponse.previousResponseID {
            json["previous_response_id"] = previousResponseID
        }

        return serialize(json) ?? body
    }

    private func extractInputText(from input: Any?) -> String? {
        if let text = input as? String {
            return cleaned(text)
        }

        if let dict = input as? [String: Any] {
            if let text = dict["text"] as? String {
                return cleaned(text)
            }
            if let content = dict["content"] {
                return extractInputText(from: content)
            }
        }

        if let array = input as? [Any] {
            let fragments = array.compactMap { item -> String? in
                if let text = item as? String {
                    return cleaned(text)
                }
                if let dict = item as? [String: Any] {
                    if let text = dict["text"] as? String {
                        return cleaned(text)
                    }
                    if let content = dict["content"] {
                        return extractInputText(from: content)
                    }
                }
                return nil
            }

            guard !fragments.isEmpty else { return nil }
            return fragments.joined(separator: "\n")
        }

        return nil
    }

    private func extractAssistantOutputText(from output: Any?) -> String {
        guard let output = output as? [Any] else { return "" }

        var fragments: [String] = []
        for item in output {
            guard let itemDict = item as? [String: Any],
                  itemDict["type"] as? String == "message",
                  let content = itemDict["content"] as? [Any] else {
                continue
            }

            for entry in content {
                guard let contentDict = entry as? [String: Any],
                      contentDict["type"] as? String == "output_text",
                      let text = contentDict["text"] as? String else {
                    continue
                }
                fragments.append(text)
            }
        }

        return fragments.joined(separator: "\n")
    }

    private func appendTurn(_ transcript: String?, role: String, text: String) -> String {
        let cleanedText = cleaned(text)
        guard !cleanedText.isEmpty else { return transcript ?? "" }

        let newTurn = "\(role): \(cleanedText)"
        guard let transcript, !transcript.isEmpty else {
            return newTurn
        }
        return transcript + "\n" + newTurn
    }

    private func cleaned(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func serialize(_ json: [String: Any]) -> String? {
        guard let modifiedData = try? JSONSerialization.data(withJSONObject: json),
              let modifiedString = String(data: modifiedData, encoding: .utf8) else {
            return nil
        }
        return modifiedString
    }
}

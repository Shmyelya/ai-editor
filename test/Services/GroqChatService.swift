import Foundation

struct GroqChatService: ChatService, Sendable {
    private static let model = "openai/gpt-oss-120b"
    private static let systemPrompt = "Отвечай обычным текстом. Не используй заголовки, таблицы, цитаты и горизонтальные линии. Допустимы жирный, курсив, код в строке и простые списки."

    func streamReply(to messages: [ChatServiceMessage]) -> AsyncThrowingStream<String, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                await Self.deliver(messages: messages, continuation: continuation)
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    private static func deliver(
        messages: [ChatServiceMessage],
        continuation: AsyncThrowingStream<String, any Error>.Continuation
    ) async {
        let session = makeSession()
        defer { session.finishTasksAndInvalidate() }
        do {
            try await streamBody(messages: messages, session: session, continuation: continuation)
            continuation.finish()
        } catch is CancellationError {
            continuation.finish()
        } catch let error as URLError {
            if error.code == .cancelled {
                continuation.finish()
            } else if Self.isNoNetwork(error) {
                continuation.finish(throwing: ChatServiceError.noNetwork)
            } else {
                continuation.finish(throwing: ChatServiceError.failed)
            }
        } catch let error as ChatServiceError {
            continuation.finish(throwing: error)
        } catch {
            continuation.finish(throwing: ChatServiceError.failed)
        }
    }

    private static func streamBody(
        messages: [ChatServiceMessage],
        session: URLSession,
        continuation: AsyncThrowingStream<String, any Error>.Continuation
    ) async throws {
        let key = Secrets.decodedKey()
        guard !key.isEmpty else { throw ChatServiceError.failed }

        guard let url = URL(string: "https://api.groq.com/openai/v1/chat/completions") else {
            throw ChatServiceError.failed
        }

        let payload = CompletionRequest(
            model: Self.model,
            stream: true,
            reasoningEffort: "low",
            messages: [CompletionMessage(role: "system", content: Self.systemPrompt)]
                + messages.map { CompletionMessage(role: $0.role, content: $0.content) }
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)

        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ChatServiceError.failed
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = try await responseBody(from: bytes)
            throw groqChatFailure(statusCode: http.statusCode, body: body)
        }

        let decoder = JSONDecoder()
        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard let event = try ServerSentEvent.parse(line: line, statusCode: http.statusCode, decoder: decoder) else { continue }
            switch event {
            case .done:
                return
            case .text(let text):
                continuation.yield(text)
            }
        }
    }

    private static func responseBody(from bytes: URLSession.AsyncBytes) async throws -> String {
        var data = Data()
        for try await byte in bytes {
            try Task.checkCancellation()
            data.append(byte)
        }
        return String(decoding: data, as: UTF8.self)
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        return URLSession(configuration: configuration)
    }

    private static func isNoNetwork(_ error: URLError) -> Bool {
        switch error.code {
        case .notConnectedToInternet,
             .networkConnectionLost,
             .dataNotAllowed,
             .cannotFindHost,
             .cannotConnectToHost,
             .dnsLookupFailed,
             .timedOut:
            return true
        default:
            return false
        }
    }
}

func groqChatFailure(statusCode: Int, body: String) -> ChatServiceError {
    if statusCode == 429 || bodyDescribesQuotaOrLimitExhaustion(body) {
        return .apiLimit
    }
    return .failed
}

private func bodyDescribesQuotaOrLimitExhaustion(_ body: String) -> Bool {
    let text = body.lowercased()
    if text.contains("quota") {
        return true
    }
    if text.contains("rate_limit") || text.contains("rate limit") || text.contains("rate-limit") {
        return true
    }
    if text.contains("too many requests") {
        return true
    }
    return text.contains("limit exceeded") || text.contains("limit reached")
}

private struct CompletionRequest: Encodable {
    var model: String
    var stream: Bool
    var reasoningEffort: String
    var messages: [CompletionMessage]

    private enum CodingKeys: String, CodingKey {
        case model
        case stream
        case reasoningEffort = "reasoning_effort"
        case messages
    }
}

private struct CompletionMessage: Encodable {
    var role: String
    var content: String
}

private enum ServerSentEvent {
    case done
    case text(String)

    static func parse(line: String, statusCode: Int, decoder: JSONDecoder) throws -> ServerSentEvent? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("data:") else { return nil }

        var payload = trimmed.dropFirst(5)
        if payload.first == " " {
            payload = payload.dropFirst()
        }
        let jsonText = payload.trimmingCharacters(in: .whitespaces)
        if jsonText == "[DONE]" {
            return .done
        }
        guard let data = jsonText.data(using: .utf8) else { return nil }

        let chunk: Chunk
        do {
            chunk = try decoder.decode(Chunk.self, from: data)
        } catch {
            return nil
        }
        if chunk.error != nil {
            throw groqChatFailure(statusCode: statusCode, body: jsonText)
        }
        let text = chunk.choices?.compactMap { $0.delta?.content }.joined() ?? ""
        guard !text.isEmpty else { return nil }
        return .text(text)
    }

    private struct Chunk: Decodable {
        struct Choice: Decodable {
            struct Delta: Decodable {
                var content: String?
            }

            var delta: Delta?
        }

        struct Failure: Decodable {}

        var choices: [Choice]?
        var error: Failure?
    }
}

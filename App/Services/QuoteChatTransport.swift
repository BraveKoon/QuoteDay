import Foundation

/// 대화 한 줄.
public struct QuoteChatMessage: Identifiable, Hashable, Sendable {
    public enum Role: String, Sendable {
        case user
        case assistant
    }

    public let id: UUID
    public let role: Role
    public var text: String
    /// 지금 글자가 흘러 들어오는 중인지. 화면이 커서를 깜빡인다.
    public var isStreaming: Bool

    public init(id: UUID = UUID(), role: Role, text: String, isStreaming: Bool = false) {
        self.id = id
        self.role = role
        self.text = text
        self.isStreaming = isStreaming
    }
}

/// 대화가 실패한 이유. 화면에 그대로 쓸 수 있는 문장을 들고 다닌다.
public enum QuoteChatError: LocalizedError, Equatable {
    /// 키가 없거나 비어 있다.
    case missingKey
    /// 이 기기에서 온디바이스 모델을 쓸 수 없다.
    case onDeviceUnavailable(QuoteExplainerAvailability)
    /// 401/403 — 키가 틀렸거나 권한이 없다.
    case unauthorized
    /// 429 — 요청이 몰렸다.
    case rateLimited
    /// 400 — 모델 이름 등 요청이 잘못됐다.
    case badRequest(String)
    /// 그 밖의 서버 오류.
    case server(Int)
    /// 네트워크가 없다.
    case offline
    /// 기기 내 모델을 아직 받지 않았다.
    case localModelMissing(LocalQwenModel)
    /// 시뮬레이터에서는 MLX(Metal)를 쓸 수 없다.
    case localNotOnSimulator
    /// 내려받기·적재가 실패했다.
    case localModelFailed(String)

    public var errorDescription: String? {
        switch self {
        case .missingKey:
            L("Qwen API 키가 없어요. 설정에서 넣어 주세요.")
        case .onDeviceUnavailable(let reason):
            reason.explanation ?? L("이 기기에서는 온디바이스 AI 를 쓸 수 없어요.")
        case .unauthorized:
            L("API 키가 거부됐어요. 키를 다시 확인해 주세요.")
        case .rateLimited:
            L("요청이 너무 많아요. 잠시 뒤 다시 물어봐 주세요.")
        case .badRequest:
            L("요청을 처리하지 못했어요. 모델 이름을 확인해 주세요.")
        case .server:
            L("Qwen 서버가 응답하지 않아요. 잠시 뒤 다시 시도해 주세요.")
        case .offline:
            L("인터넷에 연결되어 있지 않아요.")
        case .localModelMissing(let model):
            L("기기 내 %@ 모델을 아직 받지 않았어요. 설정에서 내려받아 주세요.", model.title)
        case .localNotOnSimulator:
            L("시뮬레이터에서는 기기 내 AI 를 돌릴 수 없어요. 실제 기기에서 확인해 주세요.")
        case .localModelFailed(let reason):
            L("모델을 준비하지 못했어요: %@", reason)
        }
    }
}

/// 모델에게 말을 거는 통로.
///
/// 온디바이스와 클라우드가 하는 일은 같다: 지금까지의 대화를 주고 다음 말을
/// **조각조각** 받는다. 그래서 화면은 어느 쪽을 쓰는지 몰라도 된다.
@MainActor
public protocol QuoteChatTransport {
    /// 조각의 흐름. 오류도 이 흐름을 통해 온다.
    func stream(
        system: String,
        messages: [QuoteChatMessage],
        language: AppLanguage
    ) -> AsyncThrowingStream<String, Error>
}

// MARK: - Qwen (DashScope, OpenAI 호환)

/// 알리바바 클라우드 DashScope 의 **OpenAI 호환** 엔드포인트로 대화한다.
///
/// 규격이 OpenAI 와 같아서(SSE `data: {...}`, `choices[0].delta.content`)
/// 별도 SDK 없이 `URLSession` 만으로 붙는다. 앱에 SDK 를 넣으면 앱 크기와
/// 관리 부담만 늘어난다.
@MainActor
public struct QwenChatTransport: QuoteChatTransport {
    let key: String
    let region: QwenRegion
    let model: String
    let session: URLSession

    public init(
        key: String,
        region: QwenRegion = .international,
        model: String = "qwen-plus",
        session: URLSession = .shared
    ) {
        self.key = key
        self.region = region
        self.model = model
        self.session = session
    }

    public func stream(
        system: String,
        messages: [QuoteChatMessage],
        language: AppLanguage
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let url = region.chatURL else {
                        throw QuoteChatError.server(-1)
                    }
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.timeoutInterval = 90
                    request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    request.httpBody = try Self.body(system: system, messages: messages, model: model)

                    let (bytes, response) = try await session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw QuoteChatError.server(-1)
                    }
                    guard http.statusCode == 200 else {
                        // 오류 본문은 짧다. 읽어서 이유를 고른다.
                        var body = ""
                        for try await line in bytes.lines {
                            body += line
                            if body.count > 600 { break }
                        }
                        throw Self.error(status: http.statusCode, body: body)
                    }

                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        switch QwenSSE.parse(line: line) {
                        case .delta(let text):
                            continuation.yield(text)
                        case .error(let message):
                            throw QuoteChatError.badRequest(message)
                        case .done:
                            continuation.finish()
                            return
                        case .ignore:
                            continue
                        }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: 요청 본문

    /// OpenAI 호환 요청 본문. 테스트에서 그대로 확인한다.
    ///
    /// `nonisolated` 인 이유: 순수 함수라 메인 스레드가 필요 없고, 테스트가
    /// 메인 배우 없이 그대로 부를 수 있어야 한다.
    nonisolated static func body(
        system: String,
        messages: [QuoteChatMessage],
        model: String,
        maxTurns: Int = 16
    ) throws -> Data {
        // 오래된 대화는 잘라 낸다. 문맥 한도를 넘으면 요청 자체가 거부된다.
        let recent = messages.suffix(maxTurns)
        var payload: [[String: String]] = [["role": "system", "content": system]]
        for message in recent where !message.text.trimmed.isEmpty {
            payload.append(["role": message.role.rawValue, "content": message.text])
        }

        let body: [String: Any] = [
            "model": model,
            "stream": true,
            // 창작보다 설명이 목적이라 낮게 잡는다.
            "temperature": 0.5,
            "messages": payload
        ]
        return try JSONSerialization.data(withJSONObject: body)
    }

    nonisolated static func error(status: Int, body: String) -> QuoteChatError {
        switch status {
        case 401, 403: return .unauthorized
        case 429: return .rateLimited
        case 400, 404, 422: return .badRequest(body.trimmed)
        default: return .server(status)
        }
    }
}

/// SSE 한 줄을 해석한다. 순수 함수라 테스트로 그대로 확인할 수 있다.
public enum QwenSSE {
    public enum Event: Equatable {
        /// 이어 붙일 글자.
        case delta(String)
        /// 스트림 끝.
        case done
        /// 서버가 보낸 오류.
        case error(String)
        /// 주석·빈 줄·모르는 형식.
        case ignore
    }

    public static func parse(line raw: String) -> Event {
        let line = raw.trimmingCharacters(in: .whitespaces)
        guard line.hasPrefix("data:") else { return .ignore }
        let payload = line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
        if payload.isEmpty { return .ignore }
        if payload == "[DONE]" { return .done }

        guard let data = payload.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .ignore
        }

        if let error = object["error"] as? [String: Any] {
            let message = (error["message"] as? String) ?? (error["code"] as? String) ?? "error"
            return .error(message)
        }

        guard let choices = object["choices"] as? [[String: Any]],
              let first = choices.first else { return .ignore }

        // OpenAI 호환: choices[0].delta.content
        if let delta = first["delta"] as? [String: Any],
           let content = delta["content"] as? String,
           !content.isEmpty {
            return .delta(content)
        }
        // 드물게 message.content 로 오는 구현도 있다.
        if let message = first["message"] as? [String: Any],
           let content = message["content"] as? String,
           !content.isEmpty {
            return .delta(content)
        }
        return .ignore
    }
}

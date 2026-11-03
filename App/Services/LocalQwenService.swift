import Foundation
import Observation
import Hub
import MLXLLM
import MLXLMCommon

/// 기기 안에서 Qwen3 를 **직접** 돌린다. 내려받기·적재·생성까지 이 한 곳에서 맡는다.
///
/// 왜 한 덩어리인가: MLX 에서 "내려받기"와 "모델 적재"는 사실상 한 번에 일어난다
/// (`loadContainer` 가 없으면 받고, 있으면 바로 올린다). 둘을 나눠 두면 받은 척만
/// 하고 실제로는 못 여는 상태가 생긴다. 그래서 받은 직후 그대로 적재해 두고,
/// 그 컨테이너로 대화한다.
///
/// 무거운 일은 전부 `await` 뒤에서 일어난다. 메인 스레드에서 돌리지 않는다.
@MainActor
@Observable
public final class LocalQwenService {

    public static let shared = LocalQwenService()

    /// 화면이 그대로 읽는 상태.
    public private(set) var downloaded: Set<LocalQwenModel> = []
    /// 지금 내려받거나 올리는 중인 모델. 없으면 nil.
    public private(set) var preparing: LocalQwenModel?
    /// 0…1. 내려받기 진행률.
    public private(set) var progress: Double = 0
    /// 마지막 실패 문구.
    public private(set) var errorMessage: String?

    /// 지금 메모리에 올라와 있는 컨테이너와 대화 세션.
    @ObservationIgnored private var container: ModelContainer?
    @ObservationIgnored private var session: ChatSession?
    @ObservationIgnored private var loadedModel: LocalQwenModel?
    @ObservationIgnored private var sessionSystem: String?
    /// 진행 중인 적재 작업. 같은 모델을 두 번 올리지 않는다.
    @ObservationIgnored private var loading: Task<Void, Error>?

    /// 내려받은 파일을 두는 곳.
    ///
    /// **Caches 가 아니라 Application Support** 를 쓴다. Caches 는 저장 공간이
    /// 부족하면 시스템이 지워 버리고, 그러면 사용자는 "받아 둔 모델"이 어느 날
    /// 사라지는 경험을 한다. 받은 것은 사용자의 것이므로 지워지지 않는 곳에 둔다.
    @ObservationIgnored private let downloadBase: URL
    /// 이 환경에서 MLX 를 돌릴 수 있는지. 시뮬레이터는 안 된다.
    /// 주입 가능한 이유: 테스트가 시뮬레이터에서 "돌릴 수 있는 기기"를 흉내 내야 한다.
    public let canRun: Bool

    public init(downloadBase: URL? = nil, canRun: Bool? = nil) {
        self.downloadBase = downloadBase ?? Self.defaultDownloadBase
        self.canRun = canRun ?? Self.canRunOnThisDevice
        refresh()
    }

    static var defaultDownloadBase: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return support.appendingPathComponent("QwenModels", isDirectory: true)
    }

    private var hub: HubApi { HubApi(downloadBase: downloadBase) }

    /// 모델 파일이 놓이는 폴더. 화면에 경로를 보여 주지는 않지만, 용량을 재는 데 쓴다.
    public func directory(for model: LocalQwenModel) -> URL {
        ModelConfiguration(id: model.repository).modelDirectory(hub: hub)
    }

    // MARK: - 상태

    /// 디스크를 훑어 "받아 둔 모델"을 다시 센다.
    ///
    /// 폴더가 있다고 다 받은 것이 아니다. 내려받다 만 폴더에는 `config.json` 만
    /// 있고 가중치가 없다. **가중치 파일이 있어야** 쓸 수 있다.
    public func refresh() {
        var found: Set<LocalQwenModel> = []
        for model in LocalQwenModel.allCases where Self.hasWeights(in: directory(for: model)) {
            found.insert(model)
        }
        downloaded = found
    }

    static func hasWeights(in directory: URL) -> Bool {
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return false
        }
        let weights = items.filter { $0.pathExtension == "safetensors" }
        guard !weights.isEmpty else { return false }
        // config.json 이 없으면 MLX 가 구조를 알 수 없다.
        return items.contains { $0.lastPathComponent == "config.json" }
    }

    /// 실제로 차지하는 용량.
    public func bytesOnDisk(for model: LocalQwenModel) -> Int64 {
        let directory = directory(for: model)
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else {
            return 0
        }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            total += Int64(size)
        }
        return total
    }

    public func isDownloaded(_ model: LocalQwenModel) -> Bool { downloaded.contains(model) }

    /// 지금 이 기기에서 돌릴 수 있는지. 시뮬레이터는 MLX(Metal)를 쓸 수 없다.
    public static var canRunOnThisDevice: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return true
        #endif
    }

    // MARK: - 내려받기 · 적재

    /// 모델을 준비한다. 이미 받아 두었으면 디스크에서 올리기만 한다.
    public func prepare(_ model: LocalQwenModel) async {
        guard preparing == nil else { return }
        guard canRun else {
            errorMessage = QuoteChatError.localNotOnSimulator.errorDescription
            return
        }

        errorMessage = nil
        preparing = model
        progress = 0

        do {
            try await load(model)
            downloaded.insert(model)
        } catch {
            errorMessage = QuoteChatError.localModelFailed(
                (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            ).errorDescription
            AppLog.aiChat.error("기기 내 Qwen 준비 실패: \(String(describing: error), privacy: .public)")
        }
        preparing = nil
    }

    private func load(_ model: LocalQwenModel) async throws {
        if loadedModel == model, container != nil { return }

        // 다른 모델을 쓰고 있었다면 먼저 내린다. 두 모델을 동시에 들고 있으면
        // 1.7B 기준으로 1GB 가까이 더 쓰게 되고, iOS 는 그걸 용납하지 않는다.
        unload()

        let configuration = ModelConfiguration(id: model.repository)
        let api = hub
        let container = try await LLMModelFactory.shared.loadContainer(
            hub: api,
            configuration: configuration
        ) { [weak self] update in
            let fraction = update.fractionCompleted
            Task { @MainActor in
                // 내려받기 단계에서만 0…1 이 의미가 있다. 적재 중에는 그대로 둔다.
                if fraction.isFinite, fraction > 0, fraction <= 1 {
                    self?.progress = fraction
                }
            }
        }

        self.container = container
        self.loadedModel = model
        self.session = nil
        self.sessionSystem = nil
    }

    /// 메모리에서 내린다. 디스크의 파일은 그대로 둔다.
    public func unload() {
        session = nil
        sessionSystem = nil
        container = nil
        loadedModel = nil
    }

    /// 받아 둔 파일까지 지운다.
    public func delete(_ model: LocalQwenModel) {
        if loadedModel == model { unload() }
        try? FileManager.default.removeItem(at: directory(for: model))
        downloaded.remove(model)
        if preparing == model { preparing = nil }
    }

    /// 대화를 새로 시작한다(문맥 캐시를 버린다).
    public func resetSession() {
        session = nil
        sessionSystem = nil
    }

    public var isReady: Bool { container != nil }

    /// 지금 올라와 있는 모델.
    public var currentModel: LocalQwenModel? { loadedModel }

    // MARK: - 생성

    /// 한 번의 질문에 대한 답을 조각조각 돌려준다.
    ///
    /// 문맥(지금 보고 있는 명언·작가)은 **세션 지침**으로 넣는다. 지침이 바뀌면
    /// (다른 명언으로 넘어가면) 세션을 새로 만든다 — KV 캐시에는 이전 명언이
    /// 남아 있어서, 그대로 두면 새 명언 이야기에 옛 명언이 섞인다.
    public func stream(
        model: LocalQwenModel,
        system: String,
        prompt: String
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                do {
                    guard canRun else {
                        throw QuoteChatError.localNotOnSimulator
                    }
                    if loadedModel != model || container == nil {
                        preparing = model
                        progress = 0
                        defer { preparing = nil }
                        try await load(model)
                        downloaded.insert(model)
                    }
                    guard let container else {
                        throw QuoteChatError.localModelMissing(model)
                    }

                    if session == nil || sessionSystem != system {
                        var parameters = GenerateParameters()
                        // 창작보다 설명이 목적이라 낮게 잡는다. 높이면 없는 일화를 만든다.
                        parameters.temperature = 0.5
                        parameters.topP = 0.9
                        // 짧은 모델이 길게 늘어놓으면 앞의 내용이 흐려진다.
                        parameters.maxTokens = 700
                        session = ChatSession(container, instructions: system, generateParameters: parameters)
                        sessionSystem = system
                    }

                    guard let session else { throw QuoteChatError.localModelMissing(model) }

                    for try await chunk in session.streamResponse(to: prompt) {
                        if Task.isCancelled { break }
                        if !chunk.isEmpty { continuation.yield(chunk) }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    // 중간에 끊으면 세션의 문맥이 어중간해진다. 다음 질문은 새로 시작한다.
                    self.resetSession()
                    continuation.finish()
                } catch {
                    self.resetSession()
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

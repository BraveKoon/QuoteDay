import XCTest
@testable import QuoteDay

/// 기기 내 Qwen3(오픈소스 가중치)의 **순수한 부분**만 검사한다.
///
/// MLX 는 시뮬레이터에서 돌지 않으므로 여기서 모델을 실제로 올리지 않는다.
/// 대신 "무엇을 받아야 하는지, 받은 것을 찾아내는지, 지금 대화할 수 있는지"를
/// 검사한다 — 화면이 잘못된 안내를 하지 않게 하는 부분이다.
final class LocalQwenTests: XCTestCase {

    // MARK: - 모델 고르기

    func testRecommendedModelFollowsMemory() {
        let gb = UInt64(1024 * 1024 * 1024)
        XCTAssertEqual(LocalQwenModel.recommended(physicalMemory: 3 * gb), .small)
        XCTAssertEqual(LocalQwenModel.recommended(physicalMemory: 4 * gb), .small)
        XCTAssertEqual(LocalQwenModel.recommended(physicalMemory: 6 * gb), .large)
        XCTAssertEqual(LocalQwenModel.recommended(physicalMemory: 12 * gb), .large)
    }

    func testChoiceResolves() {
        let gb = UInt64(1024 * 1024 * 1024)
        XCTAssertEqual(LocalQwenChoice.automatic.resolve(physicalMemory: 4 * gb), .small)
        XCTAssertEqual(LocalQwenChoice.automatic.resolve(physicalMemory: 8 * gb), .large)
        // 직접 고른 것은 기기 메모리와 상관없이 그대로 존중한다.
        XCTAssertEqual(LocalQwenChoice.large.resolve(physicalMemory: 3 * gb), .large)
        XCTAssertEqual(LocalQwenChoice.small.resolve(physicalMemory: 16 * gb), .small)
    }

    func testModelIdentifiersAreMLXBuilds() {
        // 원본 bf16 은 너무 크다. 앱은 4bit 변환본만 받는다.
        for model in LocalQwenModel.allCases {
            XCTAssertTrue(model.repository.hasSuffix("-4bit"), model.repository)
            XCTAssertEqual(model.repository.split(separator: "/").count, 2)
            XCTAssertGreaterThan(model.approximateBytes, 0)
        }
    }

    func testSizeFormatting() {
        XCTAssertEqual(LocalQwenModel.format(350 * 1024 * 1024), "350 MB")
        XCTAssertEqual(LocalQwenModel.format(1024 * 1024 * 1024), "1.0 GB")
        XCTAssertEqual(LocalQwenModel.format(0), "0 MB")
    }

    // MARK: - 받아 둔 것 찾기

    @MainActor
    func testDownloadedRequiresWeightsAndConfig() throws {
        let service = makeService()
        let model = LocalQwenModel.small
        let directory = service.directory(for: model)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // 내려받다 만 폴더 — 설정만 있고 가중치가 없다.
        try Data("{}".utf8).write(to: directory.appendingPathComponent("config.json"))
        XCTAssertFalse(LocalQwenService.hasWeights(in: directory))

        // 가중치가 있어야 쓸 수 있다.
        try Data(repeating: 0, count: 2048).write(to: directory.appendingPathComponent("model.safetensors"))
        XCTAssertTrue(LocalQwenService.hasWeights(in: directory))

        service.refresh()
        XCTAssertTrue(service.isDownloaded(model))
        XCTAssertGreaterThanOrEqual(service.bytesOnDisk(for: model), 2048 + 2)
    }

    @MainActor
    func testRefreshIgnoresEmptyDirectory() throws {
        let service = makeService()
        try FileManager.default.createDirectory(
            at: service.directory(for: .large),
            withIntermediateDirectories: true
        )
        service.refresh()
        XCTAssertFalse(service.isDownloaded(.large))
    }

    @MainActor
    func testDeleteRemovesFiles() throws {
        let service = makeService()
        let model = LocalQwenModel.small
        let directory = service.directory(for: model)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: directory.appendingPathComponent("config.json"))
        try Data(repeating: 1, count: 16).write(to: directory.appendingPathComponent("weights.safetensors"))
        service.refresh()
        XCTAssertTrue(service.isDownloaded(model))

        service.delete(model)

        XCTAssertFalse(service.isDownloaded(model))
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
        XCTAssertEqual(service.bytesOnDisk(for: model), 0)
    }

    // MARK: - 지금 대화할 수 있나

    @MainActor
    func testAvailabilityAsksForDownloadFirst() {
        let service = makeService(canRun: true)
        let settings = makeSettings(service: service)
        settings.provider = .localQwen

        XCTAssertEqual(settings.availability, .needsDownload(settings.localChoice.resolve()))
        XCTAssertFalse(settings.availability.canChat)
    }

    @MainActor
    func testAvailabilityIsReadyOnceDownloaded() throws {
        let service = makeService(canRun: true)
        let settings = makeSettings(service: service)
        settings.provider = .localQwen

        let model = settings.localModel
        let directory = service.directory(for: model)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: directory.appendingPathComponent("config.json"))
        try Data(repeating: 0, count: 8).write(to: directory.appendingPathComponent("w.safetensors"))
        service.refresh()

        XCTAssertEqual(settings.availability, .ready)
        XCTAssertTrue(settings.availability.canChat)
    }

    @MainActor
    func testSimulatorCannotRunLocalModel() {
        let service = makeService(canRun: false)
        let settings = makeSettings(service: service)
        settings.provider = .localQwen

        XCTAssertEqual(settings.availability, .localUnsupportedDevice)
        XCTAssertFalse(settings.availability.canChat)
    }

    @MainActor
    func testFallsBackToModelAlreadyOnDisk() throws {
        // 기기는 1.7B 를 권하지만, 이미 0.6B 를 받아 두었다면 그것을 쓴다.
        let service = makeService(canRun: true)
        let settings = makeSettings(service: service)
        settings.provider = .localQwen
        settings.localChoice = .automatic

        let small = LocalQwenModel.small
        let directory = service.directory(for: small)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: directory.appendingPathComponent("config.json"))
        try Data(repeating: 0, count: 8).write(to: directory.appendingPathComponent("w.safetensors"))
        service.refresh()

        XCTAssertEqual(settings.localModel, small)
        XCTAssertEqual(settings.availability, .ready)
    }

    // MARK: - 통로 성질

    func testProviderProperties() {
        XCTAssertFalse(AIChatProvider.localQwen.leavesDevice)
        XCTAssertFalse(AIChatProvider.localQwen.requiresKey)
        XCTAssertTrue(AIChatProvider.localQwen.requiresModelDownload)

        XCTAssertTrue(AIChatProvider.qwen.leavesDevice)
        XCTAssertTrue(AIChatProvider.qwen.requiresKey)
        XCTAssertFalse(AIChatProvider.qwen.requiresModelDownload)

        // 세 통로 모두 설정 화면에 보여야 한다(기능을 숨기지 않는다).
        XCTAssertEqual(AIChatProvider.allCases.count, 3)
    }

    // MARK: - 도우미

    @MainActor
    private func makeService(canRun: Bool = true) -> LocalQwenService {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalQwenTests-\(UUID().uuidString)", isDirectory: true)
        return LocalQwenService(downloadBase: base, canRun: canRun)
    }

    @MainActor
    private func makeSettings(service: LocalQwenService) -> AIChatSettings {
        let defaults = UserDefaults(suiteName: "LocalQwenTests-\(UUID().uuidString)") ?? .standard
        return AIChatSettings(defaults: defaults, keyStore: MemoryKeyStore(), localService: service)
    }
}

import Foundation

/// 해설을 기기에 저장해 두는 곳.
///
/// 해설은 명언 + 언어마다 한 번만 만들면 된다. 매번 다시 만들면 배터리와 시간을
/// 쓰고, 같은 명언을 다시 열었을 때 **다른 해설**이 나와 사용자가 혼란스럽다.
/// 그래서 파일 하나에 모아 두고, 필요할 때 꺼내 쓴다.
///
/// `UserDefaults` 가 아니라 파일을 쓰는 이유: 201편 × 4언어 × 세 문단이면
/// 수백 KB 가 되는데, 그 크기를 기본값 저장소에 넣으면 앱 시작이 느려진다.
public struct QuoteExplanationCache: Sendable {
    struct Entry: Codable, Sendable {
        let explanation: QuoteExplanation
        let savedAt: Date
    }

    /// 파일을 읽고 쓰는 일만 한다. 테스트에서는 임시 폴더를 넣는다.
    private let fileURL: URL
    private let limit: Int

    public init(fileURL: URL, limit: Int = 600) {
        self.fileURL = fileURL
        self.limit = limit
    }

    /// 앱이 쓰는 기본 위치. `Application Support/QuoteDay/explanations.json`
    public static func standard() -> QuoteExplanationCache {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let folder = base.appendingPathComponent("QuoteDay", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return QuoteExplanationCache(fileURL: folder.appendingPathComponent("explanations.json"))
    }

    // MARK: - 읽기

    /// 저장된 모든 해설. 파일이 깨졌으면 빈 사전을 준다(앱은 그냥 다시 만든다).
    public func load() -> [String: QuoteExplanation] {
        guard let data = try? Data(contentsOf: fileURL) else { return [:] }
        guard let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) else {
            return [:]
        }
        return decoded.mapValues(\.explanation)
    }

    public func explanation(forKey key: String) -> QuoteExplanation? {
        load()[key]
    }

    // MARK: - 쓰기

    /// 한 편을 더한다. 오래된 것부터 지워 `limit` 을 넘지 않게 한다.
    @discardableResult
    public func save(_ explanation: QuoteExplanation, forKey key: String, now: Date = .now) -> Bool {
        var entries: [String: Entry]
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) {
            entries = decoded
        } else {
            entries = [:]
        }

        entries[key] = Entry(explanation: explanation, savedAt: now)

        if entries.count > limit {
            let keep = entries
                .sorted { $0.value.savedAt > $1.value.savedAt }
                .prefix(limit)
            entries = Dictionary(uniqueKeysWithValues: keep.map { ($0.key, $0.value) })
        }

        guard let encoded = try? JSONEncoder().encode(entries) else { return false }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        do {
            try encoded.write(to: fileURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    /// 한 편만 지운다. ("다시 생성" 이 예전 글을 덮어쓰지 않게)
    public func remove(forKey key: String) {
        var entries: [String: Entry]
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) {
            entries = decoded
        } else {
            return
        }
        entries.removeValue(forKey: key)
        guard let encoded = try? JSONEncoder().encode(entries) else { return }
        try? encoded.write(to: fileURL, options: .atomic)
    }

    /// 전부 지운다. (설정의 "저장된 해설 지우기")
    public func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// 저장된 편수. 설정 화면에서 보여 준다.
    public func count() -> Int {
        load().count
    }
}

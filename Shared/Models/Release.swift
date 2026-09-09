import Foundation

/// 릴리스 한 건. `CHANGELOG.md` 의 `## [버전] - 날짜` 절 하나에 대응한다.
///
/// 앱 정보에 뜨는 버전과 깃허브 릴리스 태그가 어긋나면 사용자는 지금 쓰는 것이
/// 어느 버전인지 확인할 방법이 없다. 그래서 셋을 한 줄로 묶어 두었다.
///
///     CHANGELOG.md ──generate_release_history.py──▶ ReleaseHistory.all (앱 화면)
///           │
///           └─ project.yml 의 MARKETING_VERSION ─▶ Info.plist ─▶ release.yml 이 v<버전> 태그
///
/// `check_project.py` 가 셋이 같은지 확인하고 다르면 CI 를 실패시킨다.
public struct Release: Identifiable, Hashable, Sendable {
    /// 마케팅 버전. 예: `"1.7.1"`.
    public let version: String
    /// `yyyy-MM-dd`.
    public let date: String
    /// 첫 절 앞에 붙은 한 줄 요약. 없으면 nil.
    public let summary: String?
    public let sections: [ReleaseSection]

    public var id: String { version }

    public init(version: String, date: String, summary: String?, sections: [ReleaseSection]) {
        self.version = version
        self.date = date
        self.summary = summary
        self.sections = sections
    }

    /// 깃허브 태그. 릴리스 워크플로가 `v<MARKETING_VERSION>` 으로 단다.
    public var tag: String { "v" + version }

    public var releaseURL: URL? {
        URL(string: "https://github.com/BraveKoon/QuoteDay/releases/tag/\(tag)")
    }

    /// "2026년 9월 9일". `DateFormatter` 를 쓰지 않는 이유는 이 값이 사람이 읽는
    /// 고정 문자열이기 때문이다. 기기 지역 설정에 따라 표기가 흔들릴 이유가 없다.
    public var displayDate: String {
        let parts = date.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return date }
        return "\(parts[0])년 \(parts[1])월 \(parts[2])일"
    }
}

/// 릴리스 안의 한 절(`### 추가`, `### 고침` …).
public struct ReleaseSection: Hashable, Sendable {
    public let title: String
    public let items: [String]

    public init(title: String, items: [String]) {
        self.title = title
        self.items = items
    }
}

/// 릴리스 목록. `all` 은 `ReleaseHistory.swift` 에 생성된다.
public enum ReleaseHistory {
    /// 가장 최근 릴리스. 목록이 비어 있을 일은 없지만 강제로 꺼내지는 않는다.
    public static var latest: Release? { all.first }

    public static func release(version: String) -> Release? {
        all.first { $0.version == version }
    }
}

/// 지금 실행 중인 빌드의 버전.
///
/// 값은 번들에서 읽는다. 번들의 `CFBundleShortVersionString` 은 `project.yml` 의
/// `MARKETING_VERSION` 이고, 릴리스 워크플로가 태그를 다는 값도 그것이다.
/// 그래서 화면에 뜨는 태그는 깃허브의 태그와 같을 수밖에 없다.
public enum AppVersion {
    public static let marketing: String = string(for: "CFBundleShortVersionString") ?? "1.0"
    public static let build: String = string(for: "CFBundleVersion") ?? "1"

    /// "1.7.1 (10)"
    public static var display: String { "\(marketing) (\(build))" }

    /// "v1.7.1" — 깃허브 릴리스 태그와 같은 문자열.
    public static var tag: String { "v" + marketing }

    /// 이 빌드에 해당하는 릴리스 기록. 변경 이력에 아직 없는 개발 빌드면 nil.
    public static var release: Release? { ReleaseHistory.release(version: marketing) }

    public static var releaseURL: URL? {
        URL(string: "https://github.com/BraveKoon/QuoteDay/releases/tag/\(tag)")
    }

    private static func string(for key: String) -> String? {
        guard let value = Bundle.main.infoDictionary?[key] as? String,
              !value.isEmpty else { return nil }
        return value
    }
}

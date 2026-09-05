import Foundation

/// 명언을 남긴 인물.
///
/// 사진은 번들 에셋(`portraitAssetName`)이 있으면 사용하고, 없으면
/// 이니셜 + SF Symbol 로 만든 플레이스홀더를 그린다. 네트워크는 사용하지 않는다.
public struct Author: Identifiable, Hashable, Codable, Sendable {
    /// 안정적인 slug (예: `"churchill"`). 명언이 이 값으로 인물을 참조한다.
    public let id: String
    public let name: String
    /// 한국어 표기(있을 때만). 없으면 `name` 을 그대로 쓴다.
    public let koreanName: String?
    public let birthYear: Int?
    public let deathYear: Int?
    /// 직업 (예: `"영국 정치인 · 작가"`).
    public let occupation: String
    public let nationality: String
    /// 간단한 생애 소개 2~3문장.
    public let biography: String
    /// 주요 업적.
    public let achievements: [String]
    /// 활동한 시대의 배경 (예: "두 차례 세계대전과 대영제국의 쇠퇴기").
    /// Quote Plus 프로필 카드에서 쓴다. 비어 있으면 그 줄을 그리지 않는다.
    public let era: String?
    /// 대표 저서. Quote Plus 의 "관련 저서" 추천에 쓴다.
    public let notableWorks: [String]
    /// `Assets.xcassets` 에 초상 이미지를 추가하면 여기에 이름을 넣는다.
    public let portraitAssetName: String?

    public init(
        id: String,
        name: String,
        koreanName: String? = nil,
        birthYear: Int?,
        deathYear: Int? = nil,
        occupation: String,
        nationality: String,
        biography: String,
        achievements: [String] = [],
        era: String? = nil,
        notableWorks: [String] = [],
        portraitAssetName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.koreanName = koreanName
        self.birthYear = birthYear
        self.deathYear = deathYear
        self.occupation = occupation
        self.nationality = nationality
        self.biography = biography
        self.achievements = achievements
        self.era = era
        self.notableWorks = notableWorks
        self.portraitAssetName = portraitAssetName
    }

    public var displayName: String { koreanName ?? name }

    /// "1874 — 1965" / "1955 — " / 연도 미상이면 nil.
    public var lifespanText: String? {
        switch (birthYear, deathYear) {
        case let (birth?, death?): "\(birth) — \(death)"
        case let (birth?, nil): "\(birth) — "
        case let (nil, death?): "? — \(death)"
        default: nil
        }
    }

    /// 플레이스홀더 초상에 그릴 이니셜.
    public var initials: String {
        let source = name.isEmpty ? (koreanName ?? "?") : name
        let words = source.split(separator: " ").prefix(2)
        let letters = words.compactMap { $0.first }.map(String.init)
        return letters.isEmpty ? "?" : letters.joined().uppercased()
    }

    /// 데이터가 비어 있을 때 UI 가 참조하는 안전한 기본값.
    public static let unknown = Author(
        id: "unknown",
        name: "미상",
        birthYear: nil,
        occupation: "알 수 없음",
        nationality: "미상",
        biography: "이 인물에 대한 정보를 아직 준비하지 못했습니다.",
        achievements: []
    )
}

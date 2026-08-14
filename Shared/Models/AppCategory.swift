import SwiftUI

/// 일정과 명언이 공유하는 단일 카테고리 도메인.
///
/// 새 카테고리를 추가하려면 `case`를 하나 추가하고 `emoji` / `title` /
/// `related` / `notificationLead` 값을 채우면 된다. 나머지 화면·알림·위젯은
/// `allCases` 와 프로퍼티만 사용하므로 자동으로 반영된다.
public enum AppCategory: String, CaseIterable, Codable, Sendable, Identifiable, Hashable {
    case work
    case leisure
    case meal
    case study
    case exercise
    case health
    case relationship
    case growth
    case daily
    case etc

    public var id: String { rawValue }

    /// 카테고리를 대표하는 이모지.
    public var emoji: String {
        switch self {
        case .work: "💼"
        case .leisure: "🎮"
        case .meal: "🍽"
        case .study: "📚"
        case .exercise: "🏃"
        case .health: "❤️"
        case .relationship: "👥"
        case .growth: "💡"
        case .daily: "🏠"
        case .etc: "⭐"
        }
    }

    /// 사용자에게 보여줄 이름.
    public var title: String {
        switch self {
        case .work: "직장"
        case .leisure: "여가"
        case .meal: "식사"
        case .study: "학업"
        case .exercise: "운동"
        case .health: "건강"
        case .relationship: "인간관계"
        case .growth: "자기계발"
        case .daily: "일상"
        case .etc: "기타"
        }
    }

    public var displayName: String { "\(emoji) \(title)" }

    /// 알림 제목에 쓰이는 짧은 안내 문구.
    public var notificationLead: String {
        switch self {
        case .work: "일에 집중할 시간이에요"
        case .leisure: "즐거운 시간을 보내세요"
        case .meal: "맛있는 식사 하세요"
        case .study: "지금은 공부할 시간이에요"
        case .exercise: "몸을 움직일 시간이에요"
        case .health: "나를 돌볼 시간이에요"
        case .relationship: "함께할 시간이에요"
        case .growth: "한 걸음 더 나아갈 시간이에요"
        case .daily: "오늘 하루를 챙겨요"
        case .etc: "잠시 숨을 고르세요"
        }
    }

    /// 해당 카테고리에 명언이 부족할 때 사용할 대체 카테고리 우선순위.
    ///
    /// 마지막 fallback 은 `QuoteService` 가 전체 풀로 자동 확장하므로
    /// 여기서는 "의미적으로 가까운" 카테고리만 나열한다.
    public var related: [AppCategory] {
        switch self {
        case .work: [.growth, .daily]
        case .leisure: [.relationship, .daily]
        case .meal: [.health, .daily]
        case .study: [.growth, .work]
        case .exercise: [.health, .growth]
        case .health: [.exercise, .daily]
        case .relationship: [.leisure, .daily]
        case .growth: [.study, .work]
        case .daily: [.growth, .health]
        case .etc: [.daily, .growth]
        }
    }

    /// 카테고리 지정 없이 명언만 고를 때 사용하는 기본 순서.
    public static var selectableForQuotes: [AppCategory] {
        allCases.filter { $0 != .etc }
    }

    /// 클레이 UI 에서 카테고리를 구분하는 파스텔 색.
    public var tint: Color {
        switch self {
        case .work: ClayPalette.periwinkle
        case .leisure: ClayPalette.mint
        case .meal: ClayPalette.apricot
        case .study: ClayPalette.lilac
        case .exercise: ClayPalette.coral
        case .health: ClayPalette.rose
        case .relationship: ClayPalette.sky
        case .growth: ClayPalette.lemon
        case .daily: ClayPalette.sage
        case .etc: ClayPalette.pebble
        }
    }

    /// SF Symbol (접근성 라벨과 위젯 폴백 표현에 사용).
    public var symbolName: String {
        switch self {
        case .work: "briefcase.fill"
        case .leisure: "gamecontroller.fill"
        case .meal: "fork.knife"
        case .study: "book.fill"
        case .exercise: "figure.run"
        case .health: "heart.fill"
        case .relationship: "person.2.fill"
        case .growth: "lightbulb.fill"
        case .daily: "house.fill"
        case .etc: "star.fill"
        }
    }
}

public extension AppCategory {
    /// 저장된 문자열이 손상되었거나 앱 버전이 낮아 모르는 값일 때도 크래시하지 않는다.
    init(storedValue: String?) {
        self = AppCategory(rawValue: storedValue ?? "") ?? .etc
    }
}

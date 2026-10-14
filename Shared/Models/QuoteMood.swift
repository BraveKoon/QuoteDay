import Foundation

/// 지금 기분으로 명언을 고르기 위한 꼬리표.
///
/// **여기에 AI 는 한 방울도 필요 없다.** 201편에 손으로 태그를 붙이면 끝난다.
/// 하루면 되고, 결과가 결정적이고, 테스트가 되고, 런타임 비용이 0이다.
/// "AI 추천"이 흉내만 내는 일을 이쪽이 진짜로 해낸다.
///
/// 추천은 취향을 알아맞히는 문제가 아니라 **지금 상태를 물어보는 문제**다.
/// 사용자가 직접 고르는 편이 앱이 추측하는 것보다 정확하고, 빠르고, 공짜다.
///
/// `AppCategory` 와 **따로** 둔다. 카테고리는 일정에 붙는 것이고(직장·식사·운동),
/// 기분은 사람에게 붙는 것이다. 하나로 합치면 둘 다 흐려진다.
public enum QuoteMood: String, CaseIterable, Codable, Sendable, Identifiable {
    /// 지쳤을 때.
    case tired
    /// 다 타 버렸을 때. 지침보다 깊다.
    case burntOut
    /// 공부하거나 익혀야 할 때.
    case studying
    /// 뭔가에 덤벼야 할 때.
    case challenging
    /// 사람 사이가 힘들 때.
    case relationships
    /// 좋은 일이 있을 때. 기쁨을 붙잡아 두는 문장도 필요하다.
    case joyful

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .tired: "지침"
        case .burntOut: "번아웃"
        case .studying: "공부"
        case .challenging: "도전"
        case .relationships: "인간관계"
        case .joyful: "기쁨"
        }
    }

    public var emoji: String {
        switch self {
        case .tired: "😮‍💨"
        case .burntOut: "🪫"
        case .studying: "📖"
        case .challenging: "🔥"
        case .relationships: "🤝"
        case .joyful: "🌤️"
        }
    }

    /// 칩을 눌렀을 때 보여 줄 한 줄.
    public var invitation: String {
        switch self {
        case .tired: "쉬어 가도 괜찮다고 말해 주는 문장"
        case .burntOut: "다시 불을 붙이기 전에 읽는 문장"
        case .studying: "오래 앉아 있는 날의 문장"
        case .challenging: "한 발 내딛기 전에 읽는 문장"
        case .relationships: "사람 사이가 어려운 날의 문장"
        case .joyful: "좋은 날을 더 좋게 하는 문장"
        }
    }
}

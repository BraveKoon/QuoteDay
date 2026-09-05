import SwiftUI

/// 명언 이미지 카드의 배경·서체 조합.
///
/// 무료 테마 2종은 앱의 기본 팔레트를 그대로 쓴다. 프리미엄 테마는
/// 카테고리 파스텔을 배경 전체로 끌어와 분위기를 바꾼다.
public enum ShareCardTheme: String, CaseIterable, Identifiable, Sendable {
    // 무료
    case paper
    case ink
    // Quote Plus
    case dawn
    case forest
    case dusk
    case sand

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .paper: "종이"
        case .ink: "먹지"
        case .dawn: "새벽"
        case .forest: "숲"
        case .dusk: "노을"
        case .sand: "모래"
        }
    }

    /// Quote Plus 가 있어야 쓸 수 있는 테마인지.
    public var requiresPlus: Bool {
        switch self {
        case .paper, .ink: false
        case .dawn, .forest, .dusk, .sand: true
        }
    }

    public static var free: [ShareCardTheme] { allCases.filter { !$0.requiresPlus } }
    public static var premium: [ShareCardTheme] { allCases.filter(\.requiresPlus) }

    /// 저장된 값이 이상하면 기본 테마로 떨어뜨린다.
    public init(storedValue: String?) {
        self = ShareCardTheme(rawValue: storedValue ?? "") ?? .paper
    }

    // MARK: - 색

    public var background: Color {
        switch self {
        case .paper: Color(hex: 0xFBFAF7)
        case .ink: Color(hex: 0x1B1F2A)
        case .dawn: Color(hex: 0xF4EEFF)
        case .forest: Color(hex: 0xE8F3EC)
        case .dusk: Color(hex: 0xFFF0E8)
        case .sand: Color(hex: 0xF6F0E4)
        }
    }

    public var textColor: Color {
        switch self {
        case .ink: Color(hex: 0xF3F4F8)
        default: Color(hex: 0x2E3350)
        }
    }

    public var secondaryTextColor: Color {
        switch self {
        case .ink: Color(hex: 0xA9B0C6)
        default: Color(hex: 0x6E7595)
        }
    }

    /// 따옴표 기호와 밑줄에 쓰는 강조색.
    public var accentColor: Color {
        switch self {
        case .paper: Color(hex: 0xB6BDD6)
        case .ink: Color(hex: 0x6D7CD8)
        case .dawn: Color(hex: 0xB39DDB)
        case .forest: Color(hex: 0x7CA162)
        case .dusk: Color(hex: 0xE39B7B)
        case .sand: Color(hex: 0xC7A44A)
        }
    }

    /// 프리미엄 테마는 세리프 계열로 분위기를 바꾼다.
    public var usesSerif: Bool { requiresPlus }

    public func quoteFont(size: CGFloat) -> Font {
        usesSerif
            ? .system(size: size, weight: .semibold, design: .serif)
            : .system(size: size, weight: .semibold, design: .rounded)
    }

    public func captionFont(size: CGFloat) -> Font {
        usesSerif
            ? .system(size: size, weight: .regular, design: .serif)
            : .system(size: size, weight: .medium, design: .rounded)
    }
}

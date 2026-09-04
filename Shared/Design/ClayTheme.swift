import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 색 유틸리티

public extension Color {
    /// 0xRRGGBB 정수로 색을 만든다.
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }

    /// 라이트/다크에서 서로 다른 값을 갖는 동적 색.
    static func clay(light: UInt32, dark: UInt32, opacity: Double = 1) -> Color {
        #if canImport(UIKit)
        return Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: CGFloat(opacity)
            )
        })
        #else
        return Color(hex: light, opacity: opacity)
        #endif
    }
}

// MARK: - 파스텔 팔레트

/// 카테고리와 강조 요소에 쓰는 파스텔 색.
public enum ClayPalette {
    public static let periwinkle = Color.clay(light: 0xA9B7FF, dark: 0x6D7CD8)
    public static let mint = Color.clay(light: 0x9EE6C9, dark: 0x53A98A)
    public static let apricot = Color.clay(light: 0xFFC9A0, dark: 0xC8875A)
    public static let lilac = Color.clay(light: 0xD5B6F5, dark: 0x9370C4)
    public static let coral = Color.clay(light: 0xFFAFA3, dark: 0xC97466)
    public static let rose = Color.clay(light: 0xFFAFC9, dark: 0xC97292)
    public static let sky = Color.clay(light: 0x9FD8F5, dark: 0x5C9BC0)
    public static let lemon = Color.clay(light: 0xFFE08A, dark: 0xC7A44A)
    public static let sage = Color.clay(light: 0xBEDBA5, dark: 0x7CA162)
    public static let pebble = Color.clay(light: 0xCFD3E3, dark: 0x7C8194)
}

// MARK: - 테마 토큰

/// UI 를 구성하는 표면·문자 색과 치수.
///
/// 표면은 모두 **단색**이다. 그라데이션·블러·광택으로 입체감을 만들지 않고,
/// 배경과 카드의 밝기 차이 + 얇은 구분선만으로 층을 나눈다.
/// 하드코딩을 피하기 위해 뷰에서는 반드시 이 토큰만 참조한다.
public enum ClayTheme {

    // 표면
    /// 화면 배경. 카드보다 한 단계 어둡다(다크 모드에서는 더 어둡다).
    public static let background = Color.clay(light: 0xF3F4F8, dark: 0x121420)
    /// 카드·시트의 면.
    public static let surface = Color.clay(light: 0xFFFFFF, dark: 0x1C1F2C)
    /// 카드 위에 한 겹 더 얹는 면(칩, 작은 버튼).
    public static let surfaceRaised = Color.clay(light: 0xF7F8FB, dark: 0x252938)
    /// 입력 필드처럼 안으로 들어간 면.
    public static let surfaceSunken = Color.clay(light: 0xEDEFF5, dark: 0x161822)

    // 선
    /// 카드 테두리와 구분선. 배경 대비 아주 약하게만 보인다.
    public static let separator = Color.clay(light: 0xDFE2EC, dark: 0x333849)
    /// 떠 있는 요소(탭 바 등)에만 쓰는 옅은 그림자.
    public static let shadow = Color.clay(light: 0x2E3350, dark: 0x000000).opacity(0.10)

    // 문자
    public static let textPrimary = Color.clay(light: 0x2E3350, dark: 0xF1F3FF)
    public static let textSecondary = Color.clay(light: 0x6E7595, dark: 0xB3B9D6)
    /// 파스텔 위에 얹는 글자색.
    public static let textOnTint = Color.clay(light: 0x2A2F49, dark: 0x151827)
    /// 강조색 위에 얹는 글자색.
    public static let textOnAccent = Color.white

    // 강조
    public static let accent = Color.clay(light: 0x5A64D8, dark: 0x99A2FF)
    public static let danger = Color.clay(light: 0xD65A5A, dark: 0xE58686)

    // 치수
    public enum Radius {
        public static let card: CGFloat = 16
        public static let hero: CGFloat = 20
        public static let control: CGFloat = 12
        public static let chip: CGFloat = 8
        public static let tiny: CGFloat = 8
    }

    public enum Spacing {
        public static let xs: CGFloat = 6
        public static let s: CGFloat = 12
        public static let m: CGFloat = 18
        public static let l: CGFloat = 26
        public static let xl: CGFloat = 36
    }
}

// MARK: - 타이포그래피

/// 둥근 서체를 기본으로 하는 텍스트 스타일. 모두 Dynamic Type 을 따른다.
public enum ClayFont {
    public static func hero() -> Font { .system(.title, design: .rounded, weight: .bold) }
    public static func title() -> Font { .system(.title3, design: .rounded, weight: .bold) }
    public static func headline() -> Font { .system(.headline, design: .rounded, weight: .semibold) }
    public static func body() -> Font { .system(.body, design: .rounded, weight: .regular) }
    public static func callout() -> Font { .system(.callout, design: .rounded, weight: .medium) }
    public static func caption() -> Font { .system(.caption, design: .rounded, weight: .medium) }
    public static func quote() -> Font { .system(.title2, design: .rounded, weight: .semibold) }
}

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
    ///
    /// 클레이모피즘은 그림자와 하이라이트의 대비로 입체감을 만들기 때문에
    /// 두 모드에서 색을 각각 지정해야 형태가 살아남는다.
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

/// 클레이 UI 를 구성하는 표면·그림자·문자 색과 치수.
///
/// 하드코딩을 피하기 위해 뷰에서는 반드시 이 토큰만 참조한다.
public enum ClayTheme {

    // 표면
    /// 카드의 밝은 쪽 (좌상단).
    public static let surfaceTop = Color.clay(light: 0xFFFFFF, dark: 0x39405A)
    /// 카드의 어두운 쪽 (우하단).
    public static let surfaceBottom = Color.clay(light: 0xEDF0FA, dark: 0x2C3149)
    /// 카드 위에 얹는 보조 표면(칩, 작은 버튼).
    public static let surfaceRaised = Color.clay(light: 0xF7F8FE, dark: 0x424A68)
    /// 눌린 상태/입력 필드의 안쪽 면.
    public static let surfaceSunken = Color.clay(light: 0xE4E8F5, dark: 0x252A3E)

    // 배경
    public static let backgroundTop = Color.clay(light: 0xF2F1FC, dark: 0x1B1F30)
    public static let backgroundBottom = Color.clay(light: 0xFDF0F3, dark: 0x141726)
    public static let backgroundBlobA = Color.clay(light: 0xCBD5FF, dark: 0x394373)
    public static let backgroundBlobB = Color.clay(light: 0xFFD9E4, dark: 0x4A2E45)
    public static let backgroundBlobC = Color.clay(light: 0xCFF3E4, dark: 0x22453C)

    // 그림자 / 하이라이트
    /// 카드 바깥쪽 아래 그림자.
    public static let dropShadow = Color.clay(light: 0x9AA3C7, dark: 0x05060C).opacity(0.45)
    /// 카드 바깥쪽 위 하이라이트(빛이 좌상단에서 온다고 가정).
    public static let dropHighlight = Color.clay(light: 0xFFFFFF, dark: 0x59628C).opacity(0.75)
    /// 카드 안쪽 하이라이트.
    public static let innerHighlight = Color.clay(light: 0xFFFFFF, dark: 0x707CAE).opacity(0.85)
    /// 카드 안쪽 그림자.
    public static let innerShade = Color.clay(light: 0xA7AEC9, dark: 0x11141F).opacity(0.55)
    /// 테두리 스트로크.
    public static let strokeLight = Color.clay(light: 0xFFFFFF, dark: 0x6A749E).opacity(0.6)
    public static let strokeDark = Color.clay(light: 0xB6BDD6, dark: 0x0F1220).opacity(0.35)

    // 문자
    public static let textPrimary = Color.clay(light: 0x2E3350, dark: 0xF1F3FF)
    public static let textSecondary = Color.clay(light: 0x6E7595, dark: 0xB3B9D6)
    public static let textOnTint = Color.clay(light: 0x2A2F49, dark: 0x151827)

    // 강조
    public static let accent = Color.clay(light: 0x7C86F0, dark: 0x99A2FF)
    public static let danger = Color.clay(light: 0xF08080, dark: 0xE58686)

    // 치수
    public enum Radius {
        public static let card: CGFloat = 32
        public static let hero: CGFloat = 40
        public static let control: CGFloat = 24
        public static let chip: CGFloat = 18
        public static let tiny: CGFloat = 14
    }

    public enum Spacing {
        public static let xs: CGFloat = 6
        public static let s: CGFloat = 12
        public static let m: CGFloat = 18
        public static let l: CGFloat = 26
        public static let xl: CGFloat = 36
    }

    /// 카드 표면 그라데이션.
    public static var surfaceGradient: LinearGradient {
        LinearGradient(
            colors: [surfaceTop, surfaceBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    public static var raisedGradient: LinearGradient {
        LinearGradient(
            colors: [surfaceRaised, surfaceBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    public static var sunkenGradient: LinearGradient {
        LinearGradient(
            colors: [surfaceSunken, surfaceRaised],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// 카테고리 색을 클레이 표면에 얹을 때 쓰는 그라데이션.
    public static func tintedGradient(_ tint: Color) -> LinearGradient {
        LinearGradient(
            colors: [tint.opacity(0.95), tint.opacity(0.65)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// 테두리용 그라데이션(좌상단 밝고 우하단 어둡게).
    public static var edgeGradient: LinearGradient {
        LinearGradient(
            colors: [strokeLight, .clear, strokeDark],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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

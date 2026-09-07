import SwiftUI
import UIKit

/// 공유 카드에서 사용자가 고를 수 있는 것들.
///
/// 사진(`UIImage`)은 값 비교가 비싸고 `Equatable` 도 아니라서 여기 담지 않는다.
/// 화면이 따로 들고 있다가 카드에 넘긴다.
struct ShareCardDesign: Equatable {
    /// 서체와, 색을 직접 고르지 않았을 때의 프리셋 색.
    var theme: ShareCardTheme = .paper
    /// 직접 고른 배경색. nil 이면 테마 색을 쓴다.
    var backgroundColor: Color? = nil
    /// 카드에 함께 넣는 내 감상.
    var note: String = ""
    /// 아래쪽 QuoteDay 표시.
    var showsWatermark: Bool = true

    /// QuoteDay 의 메인 색. 사진도 색도 고르지 않았을 때 카드의 기본값이다.
    static let defaultColor = Color(hex: 0x5A64D8)

    /// 색 고르개 옆에 함께 놓는 기본 견본. 첫 번째가 앱의 메인 색이다.
    static let presetColors: [(name: String, color: Color)] = [
        ("QuoteDay", defaultColor),
        ("자정", Color(hex: 0x1B1F2A)),
        ("종이", Color(hex: 0xFBFAF7)),
        ("라일락", Color(hex: 0xB39DDB)),
        ("숲", Color(hex: 0x4F7A5B)),
        ("노을", Color(hex: 0xE39B7B)),
        ("바다", Color(hex: 0x3A6EA5)),
        ("모래", Color(hex: 0xC7A44A))
    ]

    /// 감상 글자 수 상한. 카드가 정사각형이라 이보다 길면 글씨가 읽기 어려워진다.
    static let noteLimit = 90

    var trimmedNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasNote: Bool { !trimmedNote.isEmpty }

    /// 사진이 깔릴 때의 색 조합. 사진 위에서는 늘 밝은 글자를 쓴다.
    static let photoPalette = ShareCardPalette(
        background: .black,
        text: .white,
        secondaryText: Color.white.opacity(0.78),
        accent: .white
    )

    /// 사진이 없을 때의 색 조합.
    func palette() -> ShareCardPalette {
        guard let backgroundColor else {
            return ShareCardPalette(
                background: theme.background,
                text: theme.textColor,
                secondaryText: theme.secondaryTextColor,
                accent: theme.accentColor
            )
        }
        // 직접 고른 색 위에서는 글자색을 계산으로 정한다.
        // 어두운 보라를 골랐는데 검은 글씨가 얹히면 아무것도 안 보인다.
        let light = backgroundColor.prefersLightText
        return ShareCardPalette(
            background: backgroundColor,
            text: light ? .white : Color(hex: 0x2E3350),
            secondaryText: light ? Color.white.opacity(0.75) : Color(hex: 0x6E7595),
            accent: light ? Color.white.opacity(0.85) : Color(hex: 0x2E3350).opacity(0.5)
        )
    }
}

/// 카드 한 장에 실제로 쓰이는 색.
struct ShareCardPalette: Equatable {
    let background: Color
    let text: Color
    let secondaryText: Color
    let accent: Color
}

extension Color {
    /// 이 색을 배경으로 깔았을 때 흰 글자가 더 잘 읽히는지.
    ///
    /// WCAG 상대 휘도를 계산해 검정과 흰색 중 대비가 큰 쪽을 고른다.
    /// 기준값 0.179 는 두 대비가 같아지는 지점이다.
    var prefersLightText: Bool {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return false
        }
        func linear(_ value: CGFloat) -> CGFloat {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        return luminance <= 0.179
    }
}

extension Color {
    /// "5A64D8" 형태의 여섯 자리 16진수. 변환할 수 없으면 nil.
    var hexString: String? {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }
        func byte(_ value: CGFloat) -> Int { Int((min(max(value, 0), 1) * 255).rounded()) }
        return String(format: "%02X%02X%02X", byte(red), byte(green), byte(blue))
    }

    /// 저장해 둔 16진수 문자열을 되읽는다. 형식이 어긋나면 nil 이라 기본색으로 떨어진다.
    init?(hexString: String?) {
        guard var text = hexString?.trimmingCharacters(in: .whitespaces), !text.isEmpty else {
            return nil
        }
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6, let value = UInt32(text, radix: 16) else { return nil }
        self.init(hex: value)
    }
}

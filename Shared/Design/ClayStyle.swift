import SwiftUI

// MARK: - 카드

/// 배경 위에 얹는 평면 카드.
///
/// 입체감은 표면 밝기 차이와 얇은 테두리로만 만든다.
/// 그라데이션·안쪽 그림자·광택은 쓰지 않는다.
public struct ClayCardModifier: ViewModifier {
    var cornerRadius: CGFloat
    var tint: Color?
    /// 떠 있는 정도. 0 이면 그림자 없이 테두리만 그린다.
    var elevation: CGFloat
    var isPressed: Bool

    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return content
            .background {
                shape.fill(tint ?? ClayTheme.surface)
            }
            .overlay {
                // 색을 채운 카드는 자기 색으로 이미 구분되므로 테두리를 그리지 않는다.
                if tint == nil {
                    shape.strokeBorder(ClayTheme.separator, lineWidth: 1)
                }
            }
            .compositingGroup()
            .shadow(
                color: elevation > 0 ? ClayTheme.shadow : .clear,
                radius: elevation * 0.4,
                x: 0,
                y: elevation * 0.15
            )
            .opacity(isPressed ? 0.72 : 1)
            .scaleEffect(isPressed ? 0.985 : 1)
    }
}

/// 안으로 들어간 면. 입력 필드나 선택되지 않은 셀에 쓴다.
public struct ClaySunkenModifier: ViewModifier {
    var cornerRadius: CGFloat

    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return content
            .background {
                shape.fill(ClayTheme.surfaceSunken)
            }
            .overlay {
                shape.strokeBorder(ClayTheme.separator, lineWidth: 1)
            }
    }
}

// MARK: - 배경

/// 앱 전체 배경. 단색이다.
public struct ClayBackgroundModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content.background {
            ClayTheme.background.ignoresSafeArea()
        }
    }
}

// MARK: - 구분선

/// 카드 안에서 항목을 나누는 1px 선. 테두리와 같은 색을 쓴다.
public struct ClayDivider: View {
    public init() {}

    public var body: some View {
        Rectangle()
            .fill(ClayTheme.separator)
            .frame(height: 1)
    }
}

// MARK: - 버튼

/// 누르면 살짝 흐려지는 평면 버튼.
public struct ClayButtonStyle: ButtonStyle {
    public enum Prominence {
        case primary
        case secondary
        case tinted(Color)
        case destructive
    }

    var prominence: Prominence
    var cornerRadius: CGFloat
    var horizontalPadding: CGFloat
    var verticalPadding: CGFloat
    var fullWidth: Bool

    public init(
        prominence: Prominence = .primary,
        cornerRadius: CGFloat = ClayTheme.Radius.control,
        horizontalPadding: CGFloat = ClayTheme.Spacing.l,
        verticalPadding: CGFloat = ClayTheme.Spacing.s + 2,
        fullWidth: Bool = false
    ) {
        self.prominence = prominence
        self.cornerRadius = cornerRadius
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.fullWidth = fullWidth
    }

    // `ButtonStyle` 은 `DynamicProperty` 가 아니라서 @Environment 를 직접 담으면
    // 값이 갱신되지 않는다. 실제 뷰로 한 겹 감싸서 환경 값을 읽는다.
    public func makeBody(configuration: Configuration) -> some View {
        ClayButtonBody(style: self, configuration: configuration)
    }

    /// 보조 버튼만 면을 비우고 테두리로 형태를 잡는다.
    fileprivate var fill: Color {
        switch prominence {
        case .primary: ClayTheme.accent
        case .secondary: ClayTheme.surfaceRaised
        case .tinted(let color): color
        case .destructive: ClayTheme.danger
        }
    }

    fileprivate var foreground: Color {
        switch prominence {
        case .primary, .destructive: ClayTheme.textOnAccent
        case .secondary: ClayTheme.textPrimary
        case .tinted: ClayTheme.textOnTint
        }
    }

    fileprivate var hasBorder: Bool {
        if case .secondary = prominence { return true }
        return false
    }
}

private struct ClayButtonBody: View {
    let style: ClayButtonStyle
    let configuration: ClayButtonStyle.Configuration

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)

        return configuration.label
            .font(ClayFont.headline())
            .foregroundStyle(style.foreground)
            .padding(.horizontal, style.horizontalPadding)
            .padding(.vertical, style.verticalPadding)
            .frame(maxWidth: style.fullWidth ? .infinity : nil)
            .background { shape.fill(style.fill) }
            .overlay {
                if style.hasBorder {
                    shape.strokeBorder(ClayTheme.separator, lineWidth: 1)
                }
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.72 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.15),
                value: configuration.isPressed
            )
    }
}

// MARK: - View 확장

public extension View {
    /// 평면 카드 표면을 입힌다.
    /// - Parameter elevation: 그림자 세기. 0 이면 그림자 없이 테두리만 남는다.
    func clayCard(
        cornerRadius: CGFloat = ClayTheme.Radius.card,
        tint: Color? = nil,
        elevation: CGFloat = 0,
        isPressed: Bool = false
    ) -> some View {
        modifier(ClayCardModifier(
            cornerRadius: cornerRadius,
            tint: tint,
            elevation: elevation,
            isPressed: isPressed
        ))
    }

    /// 안으로 들어간 면을 입힌다.
    func claySunken(cornerRadius: CGFloat = ClayTheme.Radius.control) -> some View {
        modifier(ClaySunkenModifier(cornerRadius: cornerRadius))
    }

    /// 앱 전체 배경.
    func clayBackground() -> some View {
        modifier(ClayBackgroundModifier())
    }

    /// 버튼 스타일 단축 표기.
    func clayButton(
        _ prominence: ClayButtonStyle.Prominence = .primary,
        cornerRadius: CGFloat = ClayTheme.Radius.control,
        fullWidth: Bool = false
    ) -> some View {
        buttonStyle(ClayButtonStyle(
            prominence: prominence,
            cornerRadius: cornerRadius,
            fullWidth: fullWidth
        ))
    }
}

// MARK: - 등장 애니메이션

/// 카드가 페이드로 나타나는 효과. `reduceMotion` 이면 즉시 표시한다.
public struct ClayAppearModifier: ViewModifier {
    var delay: Double
    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public func body(content: Content) -> some View {
        content
            .opacity(hasAppeared || reduceMotion ? 1 : 0)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: 0.25).delay(delay)) {
                    hasAppeared = true
                }
            }
    }
}

public extension View {
    func clayAppear(delay: Double = 0) -> some View {
        modifier(ClayAppearModifier(delay: delay))
    }
}

// MARK: - Preview

#Preview("디자인 시스템") {
    ScrollView {
        VStack(spacing: ClayTheme.Spacing.l) {
            Text("카드")
                .font(ClayFont.title())
                .foregroundStyle(ClayTheme.textPrimary)
                .padding(ClayTheme.Spacing.l)
                .frame(maxWidth: .infinity)
                .clayCard()

            Text("들어간 면")
                .font(ClayFont.body())
                .foregroundStyle(ClayTheme.textSecondary)
                .padding(ClayTheme.Spacing.l)
                .frame(maxWidth: .infinity)
                .claySunken()

            Button("기본 버튼") {}
                .clayButton(.primary, fullWidth: true)

            Button("보조 버튼") {}
                .clayButton(.secondary, fullWidth: true)

            HStack {
                ForEach(AppCategory.allCases.prefix(5)) { category in
                    Text(category.emoji)
                        .padding(ClayTheme.Spacing.s)
                        .clayCard(cornerRadius: ClayTheme.Radius.chip, tint: category.tint)
                }
            }
        }
        .padding(ClayTheme.Spacing.l)
    }
    .clayBackground()
}

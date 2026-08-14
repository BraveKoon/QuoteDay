import SwiftUI

// MARK: - 카드

/// 클레이 오브젝트처럼 살짝 튀어나온 표면.
///
/// 입체감은 네 겹으로 만든다.
/// 1. 표면 그라데이션 (좌상단 밝음 → 우하단 어두움)
/// 2. 안쪽 하이라이트 / 안쪽 그림자 (`ShapeStyle.shadow(.inner:)`)
/// 3. 바깥쪽 드롭 섀도 + 바깥쪽 하이라이트
/// 4. 가장자리 스트로크
public struct ClayCardModifier: ViewModifier {
    var cornerRadius: CGFloat
    var tint: Color?
    var elevation: CGFloat
    var isPressed: Bool

    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let innerRadius = max(3, cornerRadius * 0.22)
        // 눌리면 빛의 방향이 뒤집혀 안으로 들어간 것처럼 보인다.
        let highlightOffset: CGFloat = isPressed ? 2.5 : -2.5
        let shadeOffset: CGFloat = isPressed ? -3 : 3.5

        return content
            .background {
                shape
                    .fill(
                        baseStyle
                            .shadow(.inner(
                                color: ClayTheme.innerHighlight,
                                radius: innerRadius,
                                x: highlightOffset,
                                y: highlightOffset
                            ))
                            .shadow(.inner(
                                color: ClayTheme.innerShade,
                                radius: innerRadius * 1.2,
                                x: shadeOffset,
                                y: shadeOffset * 1.15
                            ))
                    )
                    .overlay {
                        shape.strokeBorder(ClayTheme.edgeGradient, lineWidth: 1)
                    }
            }
            .compositingGroup()
            .shadow(
                color: ClayTheme.dropShadow,
                radius: isPressed ? elevation * 0.35 : elevation,
                x: 0,
                y: isPressed ? elevation * 0.18 : elevation * 0.55
            )
            .shadow(
                color: ClayTheme.dropHighlight,
                radius: isPressed ? elevation * 0.3 : elevation * 0.8,
                x: -elevation * 0.28,
                y: -elevation * 0.32
            )
            .scaleEffect(isPressed ? 0.975 : 1)
    }

    private var baseStyle: AnyShapeStyle {
        if let tint {
            AnyShapeStyle(ClayTheme.tintedGradient(tint))
        } else {
            AnyShapeStyle(ClayTheme.surfaceGradient)
        }
    }
}

/// 안으로 파인 표면. 입력 필드나 선택되지 않은 셀에 쓴다.
public struct ClaySunkenModifier: ViewModifier {
    var cornerRadius: CGFloat

    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return content
            .background {
                shape
                    .fill(
                        ClayTheme.sunkenGradient
                            .shadow(.inner(color: ClayTheme.innerShade, radius: 5, x: 3, y: 3))
                            .shadow(.inner(color: ClayTheme.innerHighlight, radius: 4, x: -2, y: -2))
                    )
                    .overlay {
                        shape.strokeBorder(ClayTheme.strokeDark, lineWidth: 0.8)
                    }
            }
    }
}

// MARK: - 배경

/// 파스텔 그라데이션 + 흐릿한 색 덩어리로 만드는 앱 전체 배경.
public struct ClayBackgroundModifier: ViewModifier {
    var showsBlobs: Bool

    public func body(content: Content) -> some View {
        content.background {
            ZStack {
                LinearGradient(
                    colors: [ClayTheme.backgroundTop, ClayTheme.backgroundBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                if showsBlobs {
                    GeometryReader { proxy in
                        let side = max(proxy.size.width, proxy.size.height)
                        ZStack {
                            blob(ClayTheme.backgroundBlobA, side: side * 0.75)
                                .offset(x: -side * 0.28, y: -side * 0.30)
                            blob(ClayTheme.backgroundBlobB, side: side * 0.68)
                                .offset(x: side * 0.34, y: -side * 0.10)
                            blob(ClayTheme.backgroundBlobC, side: side * 0.60)
                                .offset(x: -side * 0.10, y: side * 0.42)
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                    .blur(radius: 60)
                    .opacity(0.55)
                }
            }
            .ignoresSafeArea()
        }
    }

    private func blob(_ color: Color, side: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: side, height: side)
    }
}

// MARK: - 버튼

/// 눌리면 안으로 들어가는 볼록한 클레이 버튼.
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

    fileprivate var tint: Color? {
        switch prominence {
        case .primary: ClayTheme.accent
        case .secondary: nil
        case .tinted(let color): color
        case .destructive: ClayTheme.danger
        }
    }

    fileprivate var foreground: Color {
        switch prominence {
        case .primary, .destructive: .white
        case .secondary: ClayTheme.textPrimary
        case .tinted: ClayTheme.textOnTint
        }
    }
}

private struct ClayButtonBody: View {
    let style: ClayButtonStyle
    let configuration: ClayButtonStyle.Configuration

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .font(ClayFont.headline())
            .foregroundStyle(style.foreground)
            .padding(.horizontal, style.horizontalPadding)
            .padding(.vertical, style.verticalPadding)
            .frame(maxWidth: style.fullWidth ? .infinity : nil)
            .modifier(ClayCardModifier(
                cornerRadius: style.cornerRadius,
                tint: style.tint,
                elevation: 10,
                isPressed: configuration.isPressed
            ))
            .opacity(isEnabled ? 1 : 0.45)
            .animation(
                reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.62),
                value: configuration.isPressed
            )
    }
}

// MARK: - View 확장

public extension View {
    /// 튀어나온 클레이 카드 표면을 입힌다.
    func clayCard(
        cornerRadius: CGFloat = ClayTheme.Radius.card,
        tint: Color? = nil,
        elevation: CGFloat = 14,
        isPressed: Bool = false
    ) -> some View {
        modifier(ClayCardModifier(
            cornerRadius: cornerRadius,
            tint: tint,
            elevation: elevation,
            isPressed: isPressed
        ))
    }

    /// 안으로 파인 표면을 입힌다.
    func claySunken(cornerRadius: CGFloat = ClayTheme.Radius.control) -> some View {
        modifier(ClaySunkenModifier(cornerRadius: cornerRadius))
    }

    /// 앱 전체 파스텔 배경.
    func clayBackground(showsBlobs: Bool = true) -> some View {
        modifier(ClayBackgroundModifier(showsBlobs: showsBlobs))
    }

    /// 클레이 버튼 스타일 단축 표기.
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

/// 카드가 살짝 떠오르며 나타나는 효과. `reduceMotion` 이면 즉시 표시한다.
public struct ClayAppearModifier: ViewModifier {
    var delay: Double
    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public func body(content: Content) -> some View {
        content
            .opacity(hasAppeared || reduceMotion ? 1 : 0)
            .scaleEffect(hasAppeared || reduceMotion ? 1 : 0.94)
            .offset(y: hasAppeared || reduceMotion ? 0 : 14)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.spring(response: 0.55, dampingFraction: 0.78).delay(delay)) {
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

#Preview("Clay 디자인 시스템") {
    ScrollView {
        VStack(spacing: ClayTheme.Spacing.l) {
            Text("클레이 카드")
                .font(ClayFont.title())
                .foregroundStyle(ClayTheme.textPrimary)
                .padding(ClayTheme.Spacing.l)
                .frame(maxWidth: .infinity)
                .clayCard()

            Text("파인 표면")
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
                        .clayCard(cornerRadius: ClayTheme.Radius.chip, tint: category.tint, elevation: 8)
                }
            }
        }
        .padding(ClayTheme.Spacing.l)
    }
    .clayBackground()
}

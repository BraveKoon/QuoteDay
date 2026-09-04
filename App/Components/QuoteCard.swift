import SwiftUI

/// 명언을 보여 주는 클레이 카드.
///
/// 홈의 메인 카드(`.hero`)와 목록의 작은 카드(`.compact`) 두 가지 크기를 지원한다.
struct QuoteCard: View {
    enum Style {
        case hero
        case compact
    }

    let presentation: QuotePresentation
    var style: Style = .hero
    var action: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false

    private var quote: Quote { presentation.quote }
    private var author: Author { presentation.author }

    var body: some View {
        Group {
            if let action {
                Button(action: action) { cardBody }
                    .buttonStyle(PressReportingStyle(isPressed: $isPressed))
            } else {
                cardBody
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(quote.text). \(author.displayName)의 명언")
        .accessibilityHint(action == nil ? "" : "두 번 탭하면 상세 화면으로 이동합니다.")
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: spacing) {
            HStack(spacing: ClayTheme.Spacing.xs) {
                CategoryChip(category: quote.category, size: style == .hero ? .regular : .small)
                Spacer(minLength: 0)
                Image(systemName: "quote.opening")
                    .font(.system(size: style == .hero ? 22 : 16, weight: .bold))
                    .foregroundStyle(ClayTheme.textSecondary.opacity(0.5))
            }

            Text(quote.text)
                .font(style == .hero ? ClayFont.quote() : ClayFont.body())
                .foregroundStyle(ClayTheme.textPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(style == .hero ? 6 : 3)
                .lineLimit(style == .hero ? nil : 4)

            VStack(alignment: .leading, spacing: 2) {
                Text("— \(author.displayName)")
                    .font(ClayFont.headline())
                    .foregroundStyle(ClayTheme.textPrimary)
                Text(author.occupation)
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.textSecondary)
            }
        }
        .padding(style == .hero ? ClayTheme.Spacing.l : ClayTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clayCard(
            cornerRadius: style == .hero ? ClayTheme.Radius.hero : ClayTheme.Radius.card,
            isPressed: isPressed
        )
        .animation(
            reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.65),
            value: isPressed
        )
    }

    private var spacing: CGFloat {
        style == .hero ? ClayTheme.Spacing.m : ClayTheme.Spacing.s
    }
}

/// 버튼의 눌림 상태를 바깥으로 알려 주는 스타일.
/// (클레이 카드가 직접 눌린 모양을 그리기 위해 필요하다.)
struct PressReportingStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .onChange(of: configuration.isPressed) { _, newValue in
                isPressed = newValue
            }
    }
}

#Preview("명언 카드") {
    ScrollView {
        VStack(spacing: ClayTheme.Spacing.l) {
            QuoteCard(
                presentation: QuoteService.shared.presentationOfTheDay(),
                style: .hero
            ) {}
            QuoteCard(
                presentation: QuoteService.shared.presentation(
                    for: QuoteService.shared.quote(for: .study, seed: "preview")
                ),
                style: .compact
            ) {}
        }
        .padding(ClayTheme.Spacing.l)
    }
    .clayBackground()
}

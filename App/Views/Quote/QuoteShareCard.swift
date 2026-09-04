import SwiftUI

/// 공유용 정사각형 명언 카드.
///
/// 화면에 보이는 미리보기와 실제로 내보내는 이미지가 **같은 뷰**여야
/// "미리보기와 다르게 나온다"는 문제가 생기지 않는다. 그래서 이 뷰 하나를
/// 미리보기와 `ImageRenderer` 양쪽에서 함께 쓴다.
struct QuoteShareCard: View {
    let presentation: QuotePresentation
    let theme: ShareCardTheme
    /// 워터마크를 그릴지. Quote Plus 사용자는 끌 수 있다.
    var showsWatermark: Bool = true
    /// 내보낼 이미지의 한 변 길이. 미리보기는 더 작은 값을 넣는다.
    var side: CGFloat = 1080

    /// 크기가 달라져도 비율이 유지되도록 한 변을 기준으로 환산한다.
    private var scale: CGFloat { side / 1080 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\u{201C}")
                .font(.system(size: 96 * scale, weight: .bold, design: theme.usesSerif ? .serif : .rounded))
                .foregroundStyle(theme.accentColor)
                .frame(height: 72 * scale, alignment: .top)

            Text(presentation.quote.text)
                .font(theme.quoteFont(size: 54 * scale))
                .foregroundStyle(theme.textColor)
                .lineSpacing(16 * scale)
                .multilineTextAlignment(.leading)
                .minimumScaleFactor(0.45)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 24 * scale)

            Rectangle()
                .fill(theme.accentColor)
                .frame(width: 64 * scale, height: 3 * scale)
                .padding(.bottom, 20 * scale)

            Text(presentation.author.displayName)
                .font(theme.captionFont(size: 34 * scale))
                .foregroundStyle(theme.textColor)

            Text(presentation.author.occupation)
                .font(theme.captionFont(size: 24 * scale))
                .foregroundStyle(theme.secondaryTextColor)

            if showsWatermark {
                HStack(spacing: 6 * scale) {
                    Image(systemName: "quote.bubble.fill")
                    Text("QuoteDay")
                }
                .font(.system(size: 22 * scale, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.secondaryTextColor.opacity(0.7))
                .padding(.top, 28 * scale)
            }
        }
        .padding(72 * scale)
        .frame(width: side, height: side, alignment: .topLeading)
        .background(theme.background)
    }
}

/// 프리뷰에서 모든 테마를 한 번에 보기 위한 래퍼.
private struct ShareCardGallery: View {
    private let presentation = QuoteService.shared.presentation(
        for: QuoteService.shared.quoteOfTheDay()
    )

    var body: some View {
        ScrollView {
            VStack(spacing: ClayTheme.Spacing.m) {
                ForEach(ShareCardTheme.allCases) { theme in
                    QuoteShareCard(presentation: presentation, theme: theme, side: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(ClayTheme.Spacing.m)
        }
        .clayBackground()
    }
}

#Preview("공유 카드") {
    ShareCardGallery()
}

import SwiftUI
import UIKit

/// 공유용 정사각형 명언 카드.
///
/// 화면에 보이는 미리보기와 실제로 내보내는 이미지가 **같은 뷰**여야
/// "미리보기와 다르게 나온다"는 문제가 생기지 않는다. 그래서 이 뷰 하나를
/// 미리보기와 `ImageRenderer` 양쪽에서 함께 쓴다.
struct QuoteShareCard: View {
    let presentation: QuotePresentation
    var design = ShareCardDesign()
    /// 배경에 깔 사진. 없으면 색으로 채운다.
    var photo: UIImage? = nil
    /// 내보낼 이미지의 한 변 길이. 미리보기는 더 작은 값을 넣는다.
    var side: CGFloat = 1080

    /// 크기가 달라져도 비율이 유지되도록 한 변을 기준으로 환산한다.
    private var scale: CGFloat { side / 1080 }

    private var palette: ShareCardPalette {
        photo == nil ? design.palette() : ShareCardDesign.photoPalette
    }

    private var usesSerif: Bool { design.theme.usesSerif }

    /// 감상이 붙으면 명언에 줄 수 있는 자리가 줄어드므로 글자를 조금 줄인다.
    private var quoteSize: CGFloat { design.hasNote ? 46 : 54 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\u{201C}")
                .font(.system(size: 96 * scale, weight: .bold, design: usesSerif ? .serif : .rounded))
                .foregroundStyle(palette.accent)
                .frame(height: 72 * scale, alignment: .top)

            Text(presentation.quote.text)
                .font(quoteFont(size: quoteSize * scale))
                .foregroundStyle(palette.text)
                .lineSpacing(16 * scale)
                .multilineTextAlignment(.leading)
                .minimumScaleFactor(0.4)
                .frame(maxWidth: .infinity, alignment: .leading)

            if design.hasNote {
                noteBlock
            }

            Spacer(minLength: 24 * scale)

            Rectangle()
                .fill(palette.accent)
                .frame(width: 64 * scale, height: 3 * scale)
                .padding(.bottom, 20 * scale)

            Text(presentation.author.displayName)
                .font(captionFont(size: 34 * scale))
                .foregroundStyle(palette.text)

            Text(presentation.author.occupation)
                .font(captionFont(size: 24 * scale))
                .foregroundStyle(palette.secondaryText)

            if design.showsWatermark {
                HStack(spacing: 6 * scale) {
                    Image(systemName: "quote.bubble.fill")
                    Text("QuoteDay")
                }
                .font(.system(size: 22 * scale, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.secondaryText)
                .padding(.top, 28 * scale)
            }
        }
        .padding(72 * scale)
        .frame(width: side, height: side, alignment: .topLeading)
        .background(background)
    }

    /// 내가 적은 감상. 명언과 섞이지 않도록 왼쪽에 세로선을 세운다.
    private var noteBlock: some View {
        HStack(alignment: .top, spacing: 16 * scale) {
            Rectangle()
                .fill(palette.accent)
                .frame(width: 3 * scale)

            Text(design.trimmedNote)
                .font(captionFont(size: 26 * scale))
                .foregroundStyle(palette.secondaryText)
                .lineSpacing(8 * scale)
                .multilineTextAlignment(.leading)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 28 * scale)
    }

    @ViewBuilder
    private var background: some View {
        if let photo {
            // 사진 위에 글씨를 얹으려면 어둡게 깔아야 한다. 그라데이션 대신
            // 단색 반투명을 쓰는 것은 앱의 나머지 화면과 같은 규칙이다.
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .frame(width: side, height: side)
                .clipped()
                .overlay(Color.black.opacity(0.45))
        } else {
            palette.background
        }
    }

    private func quoteFont(size: CGFloat) -> Font {
        usesSerif
            ? .system(size: size, weight: .semibold, design: .serif)
            : .system(size: size, weight: .semibold, design: .rounded)
    }

    private func captionFont(size: CGFloat) -> Font {
        usesSerif
            ? .system(size: size, weight: .regular, design: .serif)
            : .system(size: size, weight: .medium, design: .rounded)
    }
}

/// 프리뷰에서 여러 조합을 한 번에 보기 위한 래퍼.
private struct ShareCardGallery: View {
    private let presentation = QuoteService.shared.presentation(
        for: QuoteService.shared.quoteOfTheDay()
    )

    private var samples: [ShareCardDesign] {
        var purple = ShareCardDesign()
        purple.backgroundColor = ShareCardDesign.defaultColor

        var withNote = purple
        withNote.note = "오늘 이 문장이 필요했다. 서두르지 않기로."

        var paper = ShareCardDesign()
        paper.theme = .paper

        var ink = ShareCardDesign()
        ink.theme = .ink

        return [purple, withNote, paper, ink]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ClayTheme.Spacing.m) {
                ForEach(Array(samples.enumerated()), id: \.offset) { _, design in
                    QuoteShareCard(presentation: presentation, design: design, side: 300)
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

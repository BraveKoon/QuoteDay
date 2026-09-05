import SwiftUI
import UIKit

/// SwiftUI 카드 뷰를 공유 가능한 이미지로 굽는다.
///
/// `ImageRenderer` 는 메인 액터에서만 쓸 수 있다.
@MainActor
enum QuoteCardRenderer {
    /// 인스타그램 정사각형 기준. 대부분의 SNS 가 이 크기를 그대로 받는다.
    static let exportSide: CGFloat = 1080

    /// 카드 이미지를 만든다. 렌더링에 실패하면 nil.
    static func image(
        presentation: QuotePresentation,
        theme: ShareCardTheme,
        showsWatermark: Bool
    ) -> UIImage? {
        let card = QuoteShareCard(
            presentation: presentation,
            theme: theme,
            showsWatermark: showsWatermark,
            side: exportSide
        )
        let renderer = ImageRenderer(content: card)
        // 카드는 이미 1080pt 로 그리므로 1배로 굽는다. 2배로 하면 2160px 이 되어
        // 공유 시트에서 쓸데없이 무거워진다.
        renderer.scale = 1
        return renderer.uiImage
    }

    /// 공유 시트에 넘길 임시 PNG 파일. 파일로 넘겨야 파일 이름이 보존된다.
    static func pngFile(
        presentation: QuotePresentation,
        theme: ShareCardTheme,
        showsWatermark: Bool
    ) -> URL? {
        guard
            let image = image(presentation: presentation, theme: theme, showsWatermark: showsWatermark),
            let data = image.pngData()
        else { return nil }

        let name = "QuoteDay-\(presentation.quote.slug).png"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            AppLog.quotes.error("카드 이미지 저장 실패: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}

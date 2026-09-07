import Photos
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
        design: ShareCardDesign,
        photo: UIImage?
    ) -> UIImage? {
        let card = QuoteShareCard(
            presentation: presentation,
            design: design,
            photo: photo,
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
        design: ShareCardDesign,
        photo: UIImage?
    ) -> URL? {
        guard
            let image = image(presentation: presentation, design: design, photo: photo),
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

    // MARK: - 사진 앱에 저장

    enum SaveOutcome: Equatable {
        case saved
        /// 사진 접근을 거부했다. 설정에서 바꿔야 한다.
        case denied
        case failed(String)

        var message: String {
            switch self {
            case .saved: "사진 앱에 저장했어요."
            case .denied: "사진 추가 권한이 없어요. 설정 > QuoteDay 에서 허용해 주세요."
            case .failed(let reason): "저장하지 못했어요. \(reason)"
            }
        }
    }

    /// 카드를 사진 앱에 저장한다.
    ///
    /// `.addOnly` 권한만 요청한다. 앱은 사진을 **넣기만** 하고 읽을 일이 없어서,
    /// 전체 라이브러리 접근을 요구하면 필요 이상을 달라고 하는 것이 된다.
    static func saveToPhotos(
        presentation: QuotePresentation,
        design: ShareCardDesign,
        photo: UIImage?
    ) async -> SaveOutcome {
        guard let image = image(presentation: presentation, design: design, photo: photo) else {
            return .failed("이미지를 만들지 못했습니다.")
        }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return .denied }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            return .saved
        } catch {
            AppLog.quotes.error("사진 앱 저장 실패: \(error.localizedDescription, privacy: .public)")
            return .failed(error.localizedDescription)
        }
    }
}

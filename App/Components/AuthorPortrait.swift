import SwiftUI
import UIKit

/// 인물 사진 영역.
///
/// 번들에 초상 이미지가 있으면 그것을 쓰고, 없으면 이니셜과 파스텔 그라데이션으로
/// 플레이스홀더를 그린다. 네트워크는 사용하지 않으므로 오프라인에서도 동일하다.
struct AuthorPortrait: View {
    let author: Author
    var size: CGFloat = 96

    var body: some View {
        ZStack {
            if let assetName = author.portraitAssetName, let image = UIImage(named: assetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle().strokeBorder(ClayTheme.edgeGradient, lineWidth: 1.5)
        }
        .compositingGroup()
        .shadow(color: ClayTheme.dropShadow, radius: size * 0.14, x: 0, y: size * 0.08)
        .shadow(color: ClayTheme.dropHighlight, radius: size * 0.1, x: -size * 0.05, y: -size * 0.05)
        .accessibilityLabel("\(author.displayName) 초상")
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [tint.opacity(0.95), tint.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(author.initials)
                .font(.system(size: size * 0.34, weight: .bold, design: .rounded))
                .foregroundStyle(ClayTheme.textOnTint)
        }
    }

    /// 인물 id 로부터 항상 같은 색을 고른다.
    private var tint: Color {
        let palette: [Color] = [
            ClayPalette.periwinkle, ClayPalette.mint, ClayPalette.apricot,
            ClayPalette.lilac, ClayPalette.coral, ClayPalette.sky,
            ClayPalette.lemon, ClayPalette.sage, ClayPalette.rose
        ]
        let index = StableHash.index(for: "author:\(author.id)", count: palette.count)
        return palette[index]
    }
}

#Preview("인물 초상") {
    HStack(spacing: ClayTheme.Spacing.l) {
        AuthorPortrait(author: AuthorLibrary.author(id: "churchill"))
        AuthorPortrait(author: AuthorLibrary.author(id: "curie"), size: 64)
        AuthorPortrait(author: .unknown, size: 48)
    }
    .padding(ClayTheme.Spacing.xl)
    .clayBackground()
}

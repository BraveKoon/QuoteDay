import SwiftUI

/// 명언을 이미지 카드로 만들어 공유하는 시트.
///
/// 무료 사용자도 카드를 만들고 공유할 수 있다. 잠기는 것은 테마 선택지와
/// 워터마크 제거뿐이다 — 공유 자체를 막으면 앱이 알려질 길도 같이 막힌다.
struct ShareCardSheet: View {
    let presentation: QuotePresentation

    @Environment(PlusStore.self) private var plus
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var theme: ShareCardTheme = .paper
    @State private var hidesWatermark = false
    @State private var showsPaywall = false
    @State private var renderedFile: URL?

    private var canUsePremiumTheme: Bool { plus.isUnlocked(.premiumShareTheme) }
    private var canHideWatermark: Bool { plus.isUnlocked(.watermarkFree) }
    private var showsWatermark: Bool { !(canHideWatermark && hidesWatermark) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ClayTheme.Spacing.m) {
                    preview
                    themePicker
                    watermarkToggle
                    shareButton
                }
                .padding(ClayTheme.Spacing.m)
                .padding(.bottom, ClayTheme.Spacing.xl)
            }
            .scrollIndicators(.hidden)
            .clayBackground()
            .navigationTitle("카드로 공유")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .onAppear {
                let saved = ShareCardTheme(storedValue: settings.shareCardTheme)
                // 구독이 끝난 뒤 다시 열었을 때 프리미엄 테마가 남아 있지 않게 한다.
                theme = (saved.requiresPlus && !canUsePremiumTheme) ? .paper : saved
            }
            .onChange(of: theme) { _, newValue in
                settings.shareCardTheme = newValue.rawValue
                renderedFile = nil
            }
            .onChange(of: hidesWatermark) { _, _ in renderedFile = nil }
            .sheet(isPresented: $showsPaywall) {
                PaywallView(highlighted: .premiumShareTheme)
            }
        }
    }

    private var preview: some View {
        QuoteShareCard(
            presentation: presentation,
            theme: theme,
            showsWatermark: showsWatermark,
            side: 300
        )
        .clipShape(RoundedRectangle(cornerRadius: ClayTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: ClayTheme.Radius.card, style: .continuous)
                .strokeBorder(ClayTheme.separator, lineWidth: 1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel("\(theme.title) 테마 미리보기")
    }

    private var themePicker: some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
            HStack {
                Text("테마")
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.textSecondary)
                Spacer()
                if !canUsePremiumTheme {
                    PlusBadge()
                }
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 84), spacing: ClayTheme.Spacing.s)],
                spacing: ClayTheme.Spacing.s
            ) {
                ForEach(ShareCardTheme.allCases) { candidate in
                    themeChip(candidate)
                }
            }
        }
        .padding(ClayTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clayCard()
    }

    private func themeChip(_ candidate: ShareCardTheme) -> some View {
        let isLocked = candidate.requiresPlus && !canUsePremiumTheme
        let isSelected = candidate == theme

        return Button {
            if isLocked {
                showsPaywall = true
            } else {
                theme = candidate
            }
        } label: {
            VStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(candidate.background)
                    .frame(height: 34)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(ClayTheme.separator, lineWidth: 1)
                    }
                    .overlay {
                        if isLocked {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(candidate.secondaryTextColor)
                        }
                    }
                Text(candidate.title)
                    .font(ClayFont.caption())
                    .foregroundStyle(isSelected ? ClayTheme.accent : ClayTheme.textSecondary)
            }
            .padding(4)
        }
        .buttonStyle(.plain)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: ClayTheme.Radius.chip, style: .continuous)
                    .strokeBorder(ClayTheme.accent, lineWidth: 2)
            }
        }
        .accessibilityLabel(isLocked ? "\(candidate.title) 테마, Quote Plus 필요" : "\(candidate.title) 테마")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    private var watermarkToggle: some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.xs) {
            Toggle(isOn: Binding(
                get: { hidesWatermark },
                set: { newValue in
                    if canHideWatermark {
                        hidesWatermark = newValue
                    } else {
                        showsPaywall = true
                    }
                }
            )) {
                HStack(spacing: ClayTheme.Spacing.xs) {
                    Text("워터마크 숨기기")
                        .font(ClayFont.headline())
                        .foregroundStyle(ClayTheme.textPrimary)
                    if !canHideWatermark { PlusBadge() }
                }
            }
            .tint(ClayTheme.accent)

            Text("무료로도 카드를 만들고 공유할 수 있어요. 아래 QuoteDay 표시만 남습니다.")
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(ClayTheme.Spacing.m)
        .clayCard()
    }

    @ViewBuilder
    private var shareButton: some View {
        if let renderedFile {
            ShareLink(item: renderedFile, preview: SharePreview(presentation.quote.text)) {
                Label("이미지 공유하기", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .clayButton(.primary, fullWidth: true)
        } else {
            Button {
                renderedFile = QuoteCardRenderer.pngFile(
                    presentation: presentation,
                    theme: theme,
                    showsWatermark: showsWatermark
                )
            } label: {
                Label("이미지 만들기", systemImage: "photo")
                    .frame(maxWidth: .infinity)
            }
            .clayButton(.primary, fullWidth: true)
        }
    }
}

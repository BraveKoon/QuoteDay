import PhotosUI
import SwiftUI

/// 명언을 이미지 카드로 만들어 저장하거나 공유하는 시트.
///
/// 무료 사용자도 카드를 만들고 공유할 수 있다. 잠기는 것은 프리셋 테마와
/// 워터마크 제거뿐이다 — 공유 자체를 막으면 앱이 알려질 길도 같이 막힌다.
struct ShareCardSheet: View {
    let presentation: QuotePresentation

    @Environment(PlusStore.self) private var plus
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var design = ShareCardDesign()
    @State private var photo: UIImage?
    @State private var photoItem: PhotosPickerItem?
    @State private var showsPaywall = false
    @State private var renderedFile: URL?
    @State private var saveMessage: String?
    @State private var isSaving = false

    private var canUsePremiumTheme: Bool { plus.isUnlocked(.premiumShareTheme) }
    private var canHideWatermark: Bool { plus.isUnlocked(.watermarkFree) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ClayTheme.Spacing.m) {
                    preview
                    backgroundCard
                    noteCard
                    watermarkCard
                    actions
                }
                .padding(ClayTheme.Spacing.m)
                .padding(.bottom, ClayTheme.Spacing.xl)
            }
            .scrollIndicators(.hidden)
            .clayBackground()
            .navigationTitle("카드 만들기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .onAppear(perform: restore)
            .onChange(of: design) { _, newValue in
                settings.shareCardTheme = newValue.theme.rawValue
                settings.shareCardColorHex = newValue.backgroundColor?.hexString
                // 무엇이든 바뀌면 구워 둔 파일은 더 이상 지금 화면이 아니다.
                renderedFile = nil
            }
            .onChange(of: photoItem) { _, item in
                Task { await loadPhoto(item) }
            }
            .sheet(isPresented: $showsPaywall) {
                PaywallView(highlighted: .premiumShareTheme)
            }
        }
    }

    /// 마지막에 고른 값을 되살린다. 처음 열면 QuoteDay 보라로 시작한다.
    private func restore() {
        let savedTheme = ShareCardTheme(storedValue: settings.shareCardTheme)
        // 구독이 끝난 뒤 다시 열었을 때 프리미엄 테마가 남아 있지 않게 한다.
        design.theme = (savedTheme.requiresPlus && !canUsePremiumTheme) ? .paper : savedTheme
        design.backgroundColor = Color(hexString: settings.shareCardColorHex) ?? ShareCardDesign.defaultColor
    }

    // MARK: - 미리보기

    private var preview: some View {
        QuoteShareCard(presentation: presentation, design: design, photo: photo, side: 300)
            .clipShape(RoundedRectangle(cornerRadius: ClayTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: ClayTheme.Radius.card, style: .continuous)
                    .strokeBorder(ClayTheme.separator, lineWidth: 1)
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel("카드 미리보기")
    }

    // MARK: - 배경

    private var backgroundCard: some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
            Text("배경")
                .font(ClayFont.headline())
                .foregroundStyle(ClayTheme.textPrimary)

            colorSwatches

            HStack(spacing: ClayTheme.Spacing.s) {
                ColorPicker(
                    "직접 고르기",
                    selection: Binding(
                        get: { design.backgroundColor ?? ShareCardDesign.defaultColor },
                        set: { design.backgroundColor = $0 }
                    ),
                    supportsOpacity: false
                )
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
            }

            ClayDivider()
                .padding(.vertical, 2)

            photoRow

            ClayDivider()
                .padding(.vertical, 2)

            themePicker
        }
        .padding(ClayTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clayCard()
    }

    private var colorSwatches: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 44), spacing: ClayTheme.Spacing.s)],
            spacing: ClayTheme.Spacing.s
        ) {
            ForEach(ShareCardDesign.presetColors, id: \.name) { preset in
                Button {
                    design.backgroundColor = preset.color
                } label: {
                    RoundedRectangle(cornerRadius: ClayTheme.Radius.chip, style: .continuous)
                        .fill(preset.color)
                        .frame(height: 40)
                        .overlay {
                            RoundedRectangle(cornerRadius: ClayTheme.Radius.chip, style: .continuous)
                                .strokeBorder(
                                    isSelected(preset.color) ? ClayTheme.accent : ClayTheme.separator,
                                    lineWidth: isSelected(preset.color) ? 2 : 1
                                )
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(preset.name) 배경색")
                .accessibilityAddTraits(isSelected(preset.color) ? [.isSelected, .isButton] : .isButton)
            }
        }
    }

    private func isSelected(_ color: Color) -> Bool {
        photo == nil && design.backgroundColor?.hexString == color.hexString
    }

    private var photoRow: some View {
        HStack(spacing: ClayTheme.Spacing.s) {
            PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                Label(photo == nil ? "사진 넣기" : "사진 바꾸기", systemImage: "photo")
                    .font(ClayFont.callout())
                    .foregroundStyle(ClayTheme.accent)
            }

            Spacer(minLength: 0)

            if photo != nil {
                Button("사진 빼기") {
                    photo = nil
                    photoItem = nil
                    renderedFile = nil
                }
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.danger)
            }
        }
    }

    private var themePicker: some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
            HStack {
                Text("프리셋")
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.textSecondary)
                Spacer()
                if !canUsePremiumTheme { PlusBadge() }
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 84), spacing: ClayTheme.Spacing.s)],
                spacing: ClayTheme.Spacing.s
            ) {
                ForEach(ShareCardTheme.allCases) { candidate in
                    themeChip(candidate)
                }
            }

            Text("프리셋을 고르면 직접 정한 색 대신 그 조합을 씁니다. 세리프 서체도 여기서 정해집니다.")
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func themeChip(_ candidate: ShareCardTheme) -> some View {
        let isLocked = candidate.requiresPlus && !canUsePremiumTheme
        let isActive = design.backgroundColor == nil && candidate == design.theme

        return Button {
            if isLocked {
                showsPaywall = true
            } else {
                design.theme = candidate
                // 프리셋을 고르면 직접 정한 색은 물러난다. 둘 다 켜 두면 무엇이 이겼는지 알 수 없다.
                design.backgroundColor = nil
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
                    .foregroundStyle(isActive ? ClayTheme.accent : ClayTheme.textSecondary)
            }
            .padding(4)
        }
        .buttonStyle(.plain)
        .background {
            if isActive {
                RoundedRectangle(cornerRadius: ClayTheme.Radius.chip, style: .continuous)
                    .strokeBorder(ClayTheme.accent, lineWidth: 2)
            }
        }
        .accessibilityLabel(isLocked ? "\(candidate.title) 프리셋, Quote Plus 필요" : "\(candidate.title) 프리셋")
        .accessibilityAddTraits(isActive ? [.isSelected, .isButton] : .isButton)
    }

    // MARK: - 느낀 점

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.xs) {
            HStack {
                Text("느낀 점")
                    .font(ClayFont.headline())
                    .foregroundStyle(ClayTheme.textPrimary)
                Spacer()
                Text("\(design.trimmedNote.count) / \(ShareCardDesign.noteLimit)")
                    .font(ClayFont.caption())
                    .foregroundStyle(
                        design.trimmedNote.count > ShareCardDesign.noteLimit
                            ? ClayTheme.danger : ClayTheme.textSecondary
                    )
                    .monospacedDigit()
            }

            TextField("이 문장에서 느낀 점을 적어 보세요", text: $design.note, axis: .vertical)
                .font(ClayFont.body())
                .foregroundStyle(ClayTheme.textPrimary)
                .lineLimit(2...4)
                .padding(ClayTheme.Spacing.s)
                .claySunken()
                .onChange(of: design.note) { _, newValue in
                    // 상한을 넘기면 잘라 낸다. 카드가 정사각형이라 더 넣으면 글씨가 안 보인다.
                    if newValue.count > ShareCardDesign.noteLimit {
                        design.note = String(newValue.prefix(ShareCardDesign.noteLimit))
                    }
                }

            Text("적지 않으면 카드에 나오지 않습니다.")
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
        }
        .padding(ClayTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clayCard()
    }

    // MARK: - 워터마크

    private var watermarkCard: some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.xs) {
            Toggle(isOn: Binding(
                get: { !design.showsWatermark },
                set: { hide in
                    if canHideWatermark {
                        design.showsWatermark = !hide
                    } else {
                        showsPaywall = true
                    }
                }
            )) {
                HStack(spacing: ClayTheme.Spacing.xs) {
                    Text("QuoteDay 표시 숨기기")
                        .font(ClayFont.headline())
                        .foregroundStyle(ClayTheme.textPrimary)
                    if !canHideWatermark { PlusBadge() }
                }
            }
            .tint(ClayTheme.accent)

            Text("무료로도 카드를 만들고 저장할 수 있어요. 아래 QuoteDay 표시만 남습니다.")
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(ClayTheme.Spacing.m)
        .clayCard()
    }

    // MARK: - 버튼

    private var actions: some View {
        VStack(spacing: ClayTheme.Spacing.s) {
            Button {
                Task { await saveToPhotos() }
            } label: {
                Label(isSaving ? "저장 중…" : "사진 앱에 저장", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .clayButton(.primary, fullWidth: true)
            .disabled(isSaving)

            shareButton

            if let saveMessage {
                Text(saveMessage)
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private var shareButton: some View {
        if let renderedFile {
            ShareLink(item: renderedFile, preview: SharePreview(presentation.quote.text)) {
                Label("공유하기", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .clayButton(.secondary, fullWidth: true)
        } else {
            Button {
                renderedFile = QuoteCardRenderer.pngFile(
                    presentation: presentation,
                    design: design,
                    photo: photo
                )
            } label: {
                Label("공유용 이미지 만들기", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .clayButton(.secondary, fullWidth: true)
        }
    }

    // MARK: - 동작

    @MainActor
    private func saveToPhotos() async {
        isSaving = true
        defer { isSaving = false }
        let outcome = await QuoteCardRenderer.saveToPhotos(
            presentation: presentation,
            design: design,
            photo: photo
        )
        saveMessage = outcome.message
    }

    @MainActor
    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard
            let data = try? await item.loadTransferable(type: Data.self),
            let image = UIImage(data: data)
        else {
            saveMessage = "사진을 불러오지 못했어요."
            return
        }
        photo = image
        renderedFile = nil
    }
}

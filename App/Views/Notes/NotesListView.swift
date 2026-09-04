import SwiftUI

/// 지금까지 쓴 노트를 모아 보고, PDF 로 내보내는 화면.
struct NotesListView: View {
    @Environment(NoteStore.self) private var notes
    @Environment(PlusStore.self) private var plus
    @Environment(AppRouter.self) private var router

    @State private var showsPaywall = false
    @State private var exportedFile: URL?
    @State private var exportError: String?
    @State private var isExporting = false

    var body: some View {
        ScrollView {
            VStack(spacing: ClayTheme.Spacing.m) {
                if notes.isEmpty {
                    EmptyStateView(
                        symbol: "square.and.pencil",
                        title: "아직 쓴 노트가 없어요",
                        message: "명언 상세 화면에서 '노트 쓰기'를 누르면 여기 모입니다."
                    )
                    .clayCard()
                } else {
                    exportSection
                    ForEach(notes.notes) { note in
                        noteRow(note)
                    }
                }
            }
            .padding(ClayTheme.Spacing.m)
            .padding(.bottom, ClayTheme.Spacing.xl)
        }
        .scrollIndicators(.hidden)
        .clayBackground()
        .navigationTitle("나의 노트")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsPaywall) {
            PaywallView(highlighted: .noteExport)
        }
        .alert("내보내지 못했어요", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("확인") { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
    }

    @ViewBuilder
    private var exportSection: some View {
        if plus.isUnlocked(.noteExport) {
            VStack(spacing: ClayTheme.Spacing.s) {
                if let exportedFile {
                    ShareLink(item: exportedFile) {
                        Label("PDF 공유하기", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .clayButton(.primary, fullWidth: true)
                }

                Button {
                    export()
                } label: {
                    HStack {
                        if isExporting {
                            ProgressView().tint(ClayTheme.textPrimary)
                        } else {
                            Label(
                                exportedFile == nil ? "노트 \(notes.notes.count)편 PDF 로 내보내기" : "다시 만들기",
                                systemImage: "doc.richtext"
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .clayButton(.secondary, fullWidth: true)
                .disabled(isExporting)
            }
        } else {
            PlusLockedCard(
                feature: .noteExport,
                message: "노트 \(notes.notes.count)편을 표지가 있는 PDF 한 권으로 묶어 드려요."
            ) {
                showsPaywall = true
            }
        }
    }

    private func noteRow(_ note: QuoteNote) -> some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.xs) {
            Text("\u{201C}\(note.quoteTextSnapshot)\u{201D}")
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
                .lineLimit(2)

            Text(note.text)
                .font(ClayFont.body())
                .foregroundStyle(ClayTheme.textPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text(note.authorNameSnapshot)
                Spacer()
                Text(Formatters.shortDateTime.string(from: note.updatedAt))
            }
            .font(ClayFont.caption())
            .foregroundStyle(ClayTheme.textSecondary)
        }
        .padding(ClayTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clayCard()
        .contextMenu {
            Button {
                // 노트를 쓴 명언으로 이동한다. 명언이 사라졌으면 아무 일도 하지 않는다.
                if let quote = QuoteService.shared.quote(slug: note.quoteSlug) {
                    router.showQuote(quote)
                }
            } label: {
                Label("이 명언 보기", systemImage: "quote.bubble")
            }
            Button(role: .destructive) {
                notes.delete(note)
            } label: {
                Label("노트 삭제", systemImage: "trash")
            }
        }
    }

    private func export() {
        isExporting = true
        // PDF 생성은 메인 액터에서 도는 렌더링이라 UI 갱신 뒤로 한 틱 미룬다.
        Task { @MainActor in
            defer { isExporting = false }
            do {
                exportedFile = try NotePDFExporter.export(notes: notes.notes)
            } catch {
                exportError = error.localizedDescription
            }
        }
    }
}

#Preview("나의 노트") {
    NavigationStack {
        NotesListView()
    }
    .injecting(AppEnvironment.preview())
}

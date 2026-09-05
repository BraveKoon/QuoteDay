import SwiftUI

/// 명언 한 편에 대한 노트를 쓰는 시트.
///
/// 쓰기와 읽기는 무료다. 잠기는 것은 내보내기뿐이다.
struct NoteEditorSheet: View {
    let presentation: QuotePresentation

    @Environment(NoteStore.self) private var notes
    @Environment(PlusStore.self) private var plus
    @Environment(\.dismiss) private var dismiss

    @State private var text: String = ""
    @State private var showsPaywall = false
    @FocusState private var isEditing: Bool

    private var existing: QuoteNote? { notes.note(for: presentation.quote.slug) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ClayTheme.Spacing.m) {
                    quoteCard
                    editor
                    if existing != nil { deleteButton }
                    exportHint
                }
                .padding(ClayTheme.Spacing.m)
                .padding(.bottom, ClayTheme.Spacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
            .clayBackground()
            .navigationTitle(existing == nil ? "노트 쓰기" : "노트")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        notes.save(text: text, for: presentation)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                text = existing?.text ?? ""
                isEditing = true
            }
            .sheet(isPresented: $showsPaywall) {
                PaywallView(highlighted: .noteExport)
            }
        }
    }

    private var quoteCard: some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.xs) {
            Text("\u{201C}\(presentation.quote.text)\u{201D}")
                .font(ClayFont.callout())
                .foregroundStyle(ClayTheme.textPrimary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            Text("— \(presentation.author.displayName)")
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
        }
        .padding(ClayTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .claySunken(cornerRadius: ClayTheme.Radius.card)
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.xs) {
            Text("이 문장에서 떠오른 생각")
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)

            TextEditor(text: $text)
                .focused($isEditing)
                .font(ClayFont.body())
                .foregroundStyle(ClayTheme.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 220)
                .padding(ClayTheme.Spacing.s)
                .claySunken()
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("오늘 이 말이 어떻게 와닿았는지, 어디에 써 보고 싶은지 적어 보세요.")
                            .font(ClayFont.body())
                            .foregroundStyle(ClayTheme.textSecondary.opacity(0.7))
                            .padding(.horizontal, ClayTheme.Spacing.s + 5)
                            .padding(.vertical, ClayTheme.Spacing.s + 8)
                            .allowsHitTesting(false)
                    }
                }

            if let updatedAt = existing?.updatedAt {
                Text("마지막 수정 \(Formatters.shortDateTime.string(from: updatedAt))")
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.textSecondary)
            }
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            if let existing { notes.delete(existing) }
            dismiss()
        } label: {
            Label("노트 삭제", systemImage: "trash")
        }
        .clayButton(.destructive, fullWidth: true)
    }

    @ViewBuilder
    private var exportHint: some View {
        if !plus.isUnlocked(.noteExport) {
            PlusLockedCard(
                feature: .noteExport,
                message: "지금 쓰는 노트는 그대로 저장돼요. Quote Plus 를 켜면 모아 둔 노트를 PDF 한 권으로 내보낼 수 있어요."
            ) {
                showsPaywall = true
            }
        }
    }
}

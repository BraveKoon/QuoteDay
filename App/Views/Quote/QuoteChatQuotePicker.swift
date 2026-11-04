import SwiftUI

/// AI 대화에서 **어떤 명언에 대해 물을지** 고르는 시트.
///
/// 대화는 처음에 "지금 보고 있는 명언"(없으면 오늘의 명언)에 묶이는데, 묻고 싶은 것이
/// 다른 명언이면 화면을 닫고 명언 탭에서 그 명언을 찾아 다시 와야 했다. 여기서 바로
/// 고른다. 201편이라 검색을 넣었다 — 명언 본문과 인물 이름으로 찾는다.
struct QuoteChatQuotePicker: View {
    /// 지금 묻고 있는 명언. 목록에서 표시한다.
    let currentSlug: String?
    let onSelect: (Quote) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var term = ""

    private var quotes: [Quote] {
        QuoteService.shared.search(term)
    }

    var body: some View {
        NavigationStack {
            List(quotes) { quote in
                row(for: quote)
                    .listRowBackground(ClayTheme.surface)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(ClayTheme.background)
            .searchable(text: $term, prompt: "명언·인물 검색")
            .navigationTitle("명언 고르기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .overlay {
                if quotes.isEmpty {
                    ContentUnavailableView.search(text: term)
                }
            }
        }
    }

    private func row(for quote: Quote) -> some View {
        let author = QuoteService.shared.presentation(for: quote).author
        let isCurrent = quote.slug == currentSlug

        return Button {
            onSelect(quote)
            dismiss()
        } label: {
            HStack(alignment: .top, spacing: ClayTheme.Spacing.s) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(quote.text)
                        .font(ClayFont.callout())
                        .foregroundStyle(ClayTheme.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                    Text(verbatim: "— \(author.displayName)")
                        .font(ClayFont.caption())
                        .foregroundStyle(ClayTheme.textSecondary)
                }
                Spacer(minLength: 0)
                if isCurrent {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(ClayTheme.accent)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}

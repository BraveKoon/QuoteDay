import SwiftUI

/// 명언 둘러보기 탭. 카테고리 필터와 검색을 제공한다.
struct QuoteBrowserView: View {
    @Environment(AppRouter.self) private var router

    @State private var selectedCategory: AppCategory?
    @State private var searchText = ""

    private let quoteService = QuoteService.shared

    private var results: [Quote] {
        let base = searchText.isEmpty ? quoteService.allQuotes : quoteService.search(searchText)
        guard let selectedCategory else { return base }
        return base.filter { $0.matches(selectedCategory) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClayTheme.Spacing.m) {
                header
                searchField
                categoryFilter

                if results.isEmpty {
                    EmptyStateView(
                        symbol: "magnifyingglass",
                        title: "조건에 맞는 명언이 없어요",
                        message: "검색어를 지우거나 다른 카테고리를 선택해 보세요.",
                        actionTitle: "필터 초기화"
                    ) {
                        withAnimation {
                            searchText = ""
                            selectedCategory = nil
                        }
                    }
                    .clayCard()
                } else {
                    LazyVStack(spacing: ClayTheme.Spacing.s) {
                        ForEach(results) { quote in
                            QuoteCard(
                                presentation: quoteService.presentation(for: quote),
                                style: .compact
                            ) {
                                router.showQuote(quote)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, ClayTheme.Spacing.m)
            .padding(.top, ClayTheme.Spacing.m)
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
        .clayBackground()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("명언 모음")
                .font(ClayFont.hero())
                .foregroundStyle(ClayTheme.textPrimary)
            Text("총 \(quoteService.quoteCount)개 · 표시 중 \(results.count)개")
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var searchField: some View {
        HStack(spacing: ClayTheme.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(ClayTheme.textSecondary)
            TextField("명언이나 인물 검색", text: $searchText)
                .font(ClayFont.body())
                .foregroundStyle(ClayTheme.textPrimary)
                .submitLabel(.search)
            if !searchText.isEmpty {
                Button {
                    withAnimation { searchText = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(ClayTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("검색어 지우기")
            }
        }
        .padding(ClayTheme.Spacing.s + 2)
        .claySunken()
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal) {
            HStack(spacing: ClayTheme.Spacing.xs) {
                filterChip(title: "전체", emoji: "✨", isSelected: selectedCategory == nil, tint: ClayTheme.accent) {
                    selectedCategory = nil
                }
                ForEach(AppCategory.allCases) { category in
                    filterChip(
                        title: category.title,
                        emoji: category.emoji,
                        isSelected: selectedCategory == category,
                        tint: category.tint
                    ) {
                        selectedCategory = selectedCategory == category ? nil : category
                    }
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 2)
        }
        .scrollIndicators(.hidden)
    }

    private func filterChip(
        title: String,
        emoji: String,
        isSelected: Bool,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { action() }
        } label: {
            HStack(spacing: 4) {
                Text(emoji)
                Text(title)
                    .font(ClayFont.callout())
            }
            .foregroundStyle(isSelected ? ClayTheme.textOnTint : ClayTheme.textSecondary)
            .padding(.horizontal, ClayTheme.Spacing.s)
            .padding(.vertical, ClayTheme.Spacing.xs + 1)
        }
        .buttonStyle(.plain)
        .background {
            let shape = RoundedRectangle(cornerRadius: ClayTheme.Radius.chip, style: .continuous)
            if isSelected {
                shape.fill(tint)
            } else {
                shape
                    .fill(ClayTheme.surfaceSunken)
                    .overlay { shape.strokeBorder(ClayTheme.separator, lineWidth: 1) }
            }
        }
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

#Preview("명언 모음") {
    QuoteBrowserView()
        .injecting(AppEnvironment.preview())
}

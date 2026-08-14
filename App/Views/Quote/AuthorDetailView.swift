import SwiftUI

/// 인물 상세: 생애·업적과 그 인물이 남긴 다른 명언.
struct AuthorDetailView: View {
    let authorID: String

    private let quoteService = QuoteService.shared

    private var author: Author { AuthorLibrary.author(id: authorID) }
    private var quotes: [Quote] { quoteService.quotes(byAuthor: authorID) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClayTheme.Spacing.l) {
                profileCard

                VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
                    SectionHeader("남긴 명언", subtitle: "\(quotes.count)개")

                    if quotes.isEmpty {
                        EmptyStateView(
                            symbol: "text.quote",
                            title: "등록된 명언이 없어요"
                        )
                        .clayCard()
                    } else {
                        ForEach(quotes) { quote in
                            VStack(alignment: .leading, spacing: ClayTheme.Spacing.xs) {
                                CategoryChip(category: quote.category, size: .small)
                                Text("\u{201C}\(quote.text)\u{201D}")
                                    .font(ClayFont.body())
                                    .foregroundStyle(ClayTheme.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(ClayTheme.Spacing.m)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .clayCard(cornerRadius: ClayTheme.Radius.control, elevation: 9)
                        }
                    }
                }
            }
            .padding(ClayTheme.Spacing.m)
            .padding(.bottom, ClayTheme.Spacing.xl)
        }
        .scrollIndicators(.hidden)
        .clayBackground()
        .navigationTitle(author.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var profileCard: some View {
        VStack(spacing: ClayTheme.Spacing.s) {
            AuthorPortrait(author: author, size: 100)

            Text(author.name)
                .font(ClayFont.title())
                .foregroundStyle(ClayTheme.textPrimary)

            if let korean = author.koreanName, korean != author.name {
                Text(korean)
                    .font(ClayFont.callout())
                    .foregroundStyle(ClayTheme.textSecondary)
            }

            if let lifespan = author.lifespanText {
                Text(lifespan)
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.textSecondary)
                    .monospacedDigit()
            }

            HStack(spacing: ClayTheme.Spacing.xs) {
                infoPill(author.occupation)
                infoPill(author.nationality)
            }

            Text(author.biography)
                .font(ClayFont.body())
                .foregroundStyle(ClayTheme.textPrimary)
                .multilineTextAlignment(.leading)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, ClayTheme.Spacing.xs)
        }
        .padding(ClayTheme.Spacing.l)
        .frame(maxWidth: .infinity)
        .clayCard(cornerRadius: ClayTheme.Radius.hero, elevation: 16)
    }

    private func infoPill(_ text: String) -> some View {
        Text(text)
            .font(ClayFont.caption())
            .foregroundStyle(ClayTheme.textSecondary)
            .padding(.horizontal, ClayTheme.Spacing.s)
            .padding(.vertical, 5)
            .claySunken(cornerRadius: ClayTheme.Radius.chip)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

#Preview("인물 상세") {
    NavigationStack {
        AuthorDetailView(authorID: "churchill")
    }
}

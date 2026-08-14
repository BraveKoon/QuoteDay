import SwiftUI

/// 명언 상세 화면. 알림 탭 / 위젯 탭 / 카드 탭이 모두 여기로 모인다.
struct QuoteDetailView: View {
    let quoteID: UUID

    @Environment(\.dismiss) private var dismiss
    private let quoteService = QuoteService.shared

    var body: some View {
        NavigationStack {
            Group {
                if let presentation = quoteService.presentation(id: quoteID) {
                    content(for: presentation)
                } else {
                    // 데이터가 갱신되어 사라진 명언을 가리키는 오래된 알림/위젯 링크.
                    EmptyStateView(
                        symbol: "questionmark.bubble",
                        title: "명언을 찾을 수 없어요",
                        message: "앱이 업데이트되면서 이 명언이 바뀌었을 수 있어요.",
                        actionTitle: "닫기"
                    ) { dismiss() }
                    .padding(ClayTheme.Spacing.l)
                }
            }
            .clayBackground()
            .navigationTitle("오늘의 명언")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    private func content(for presentation: QuotePresentation) -> some View {
        let author = presentation.author
        let quote = presentation.quote

        return ScrollView {
            VStack(spacing: ClayTheme.Spacing.l) {
                VStack(spacing: ClayTheme.Spacing.s) {
                    AuthorPortrait(author: author, size: 116)
                        .clayAppear()

                    Text(author.displayName)
                        .font(ClayFont.hero())
                        .foregroundStyle(ClayTheme.textPrimary)
                        .multilineTextAlignment(.center)

                    if let lifespan = author.lifespanText {
                        Text(lifespan)
                            .font(ClayFont.callout())
                            .foregroundStyle(ClayTheme.textSecondary)
                            .monospacedDigit()
                    }

                    Text("\(author.occupation) · \(author.nationality)")
                        .font(ClayFont.caption())
                        .foregroundStyle(ClayTheme.textSecondary)
                        .multilineTextAlignment(.center)

                    CategoryChip(category: quote.category)
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)

                // 명언 본문
                VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
                    Text("\u{201C}\(quote.text)\u{201D}")
                        .font(ClayFont.quote())
                        .foregroundStyle(ClayTheme.textPrimary)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)

                    if let original = quote.originalText {
                        Text(original)
                            .font(ClayFont.caption())
                            .foregroundStyle(ClayTheme.textSecondary)
                            .italic()
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // ZenQuotes 무료 이용 조건상 출처 표기가 필요하다.
                    if quote.isFromZenQuotes {
                        Divider().opacity(0.2)
                        Link(destination: RemoteQuoteStore.attributionURL) {
                            HStack(spacing: 4) {
                                Image(systemName: "link")
                                Text(RemoteQuoteStore.attribution)
                            }
                            .font(ClayFont.caption())
                            .foregroundStyle(ClayTheme.accent)
                        }
                    }
                }
                .padding(ClayTheme.Spacing.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .clayCard(cornerRadius: ClayTheme.Radius.hero, elevation: 16)
                .clayAppear(delay: 0.05)

                // 인물 소개
                VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
                    SectionHeader("인물 소개")
                    Text(author.biography)
                        .font(ClayFont.body())
                        .foregroundStyle(ClayTheme.textPrimary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    if !author.achievements.isEmpty {
                        Divider().opacity(0.2)
                        Text("주요 업적")
                            .font(ClayFont.caption())
                            .foregroundStyle(ClayTheme.textSecondary)
                        ForEach(Array(author.achievements.enumerated()), id: \.offset) { _, achievement in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "sparkle")
                                    .font(.caption2)
                                    .foregroundStyle(ClayTheme.accent)
                                    .padding(.top, 3)
                                Text(achievement)
                                    .font(ClayFont.callout())
                                    .foregroundStyle(ClayTheme.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    NavigationLink {
                        AuthorDetailView(authorID: author.id)
                    } label: {
                        Label("이 인물의 다른 명언 보기", systemImage: "chevron.right.circle.fill")
                            .font(ClayFont.headline())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, ClayTheme.Spacing.s + 2)
                            .foregroundStyle(.white)
                            .clayCard(
                                cornerRadius: ClayTheme.Radius.control,
                                tint: ClayTheme.accent,
                                elevation: 10
                            )
                    }
                    .padding(.top, ClayTheme.Spacing.xs)
                }
                .padding(ClayTheme.Spacing.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .clayCard()
                .clayAppear(delay: 0.1)

                ShareLink(item: presentation.shareText) {
                    Label("명언 공유하기", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .clayButton(.secondary, fullWidth: true)
                .clayAppear(delay: 0.15)
            }
            .padding(ClayTheme.Spacing.m)
            .padding(.bottom, ClayTheme.Spacing.xl)
        }
        .scrollIndicators(.hidden)
    }
}

#Preview("명언 상세") {
    QuoteDetailView(quoteID: QuoteService.shared.quoteOfTheDay().id)
        .injecting(AppEnvironment.preview())
}

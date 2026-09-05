import SwiftUI

/// 명언 상세 화면. 알림 탭 / 위젯 탭 / 카드 탭이 모두 여기로 모인다.
///
/// 무료와 Quote Plus 의 경계가 이 화면에 있다.
/// - 무료: 명언 본문, 인물 이름과 초상, 노트 쓰기, 카드 공유(워터마크 포함)
/// - Plus: 인물 프로필, 비하인드 스토리, 관련 저서·연관 인물
struct QuoteDetailView: View {
    let quoteID: UUID

    @Environment(PlusStore.self) private var plus
    @Environment(NoteStore.self) private var notes
    @Environment(\.dismiss) private var dismiss

    @State private var paywallFeature: PlusFeature?
    @State private var showsNoteEditor = false
    @State private var showsShareCard = false

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
            .sheet(item: $paywallFeature) { feature in
                PaywallView(highlighted: feature)
            }
        }
    }

    private func content(for presentation: QuotePresentation) -> some View {
        ScrollView {
            VStack(spacing: ClayTheme.Spacing.l) {
                header(for: presentation)
                quoteCard(for: presentation)
                behindStorySection(for: presentation)
                noteSection(for: presentation)
                authorProfileSection(for: presentation)
                relatedSection(for: presentation)
                shareSection(for: presentation)
            }
            .padding(ClayTheme.Spacing.m)
            .padding(.bottom, ClayTheme.Spacing.xl)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showsNoteEditor) {
            NoteEditorSheet(presentation: presentation)
        }
        .sheet(isPresented: $showsShareCard) {
            ShareCardSheet(presentation: presentation)
        }
    }

    // MARK: - 머리말 (무료)

    private func header(for presentation: QuotePresentation) -> some View {
        VStack(spacing: ClayTheme.Spacing.s) {
            AuthorPortrait(author: presentation.author, size: 116)
                .clayAppear()

            Text(presentation.author.displayName)
                .font(ClayFont.hero())
                .foregroundStyle(ClayTheme.textPrimary)
                .multilineTextAlignment(.center)

            CategoryChip(category: presentation.quote.category)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - 명언 본문 (무료)

    private func quoteCard(for presentation: QuotePresentation) -> some View {
        let quote = presentation.quote

        return VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
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
                ClayDivider()
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
        .clayCard(cornerRadius: ClayTheme.Radius.hero)
        .clayAppear(delay: 0.05)
    }

    // MARK: - 비하인드 스토리 (Plus)

    @ViewBuilder
    private func behindStorySection(for presentation: QuotePresentation) -> some View {
        if let story = BehindStoryLibrary.story(for: presentation.quote.slug) {
            if plus.isUnlocked(.behindStory) {
                VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
                    HStack {
                        SectionHeader("비하인드 스토리")
                        Spacer()
                        PlusBadge()
                    }

                    Text(story.occasion)
                        .font(ClayFont.callout())
                        .foregroundStyle(ClayTheme.accent)

                    Text(story.context)
                        .font(ClayFont.body())
                        .foregroundStyle(ClayTheme.textPrimary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    if let takeaway = story.takeaway {
                        ClayDivider()
                        Text(takeaway)
                            .font(ClayFont.callout())
                            .foregroundStyle(ClayTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text("출처 · \(story.source)")
                        .font(ClayFont.caption())
                        .foregroundStyle(ClayTheme.textSecondary)
                        .padding(.top, 2)
                }
                .padding(ClayTheme.Spacing.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .clayCard()
                .clayAppear(delay: 0.08)
            } else {
                PlusLockedPreview(
                    feature: .behindStory,
                    message: "\(story.occasion). 이 문장이 어떤 상황에서 나왔는지 읽어 보세요."
                ) {
                    paywallFeature = .behindStory
                } content: {
                    VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
                        Text(story.occasion)
                            .font(ClayFont.callout())
                            .foregroundStyle(ClayTheme.accent)
                        Text(story.context)
                            .font(ClayFont.body())
                            .foregroundStyle(ClayTheme.textPrimary)
                            .lineSpacing(4)
                    }
                }
                .clayAppear(delay: 0.08)
            }
        } else {
            // 배경이 아직 없는 명언. 잠금이 아니라 준비 상태를 알린다 —
            // 없는 콘텐츠로 페이월을 띄우면 그건 속이는 것이다.
            ComingSoonCard(title: "비하인드 스토리")
                .clayAppear(delay: 0.08)
        }
    }

    // MARK: - 노트 (무료)

    private func noteSection(for presentation: QuotePresentation) -> some View {
        let existing = notes.note(for: presentation.quote.slug)

        return VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
            SectionHeader("나의 노트")

            if let existing {
                Text(existing.text)
                    .font(ClayFont.body())
                    .foregroundStyle(ClayTheme.textPrimary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                Text("마지막 수정 \(Formatters.shortDateTime.string(from: existing.updatedAt))")
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.textSecondary)
            } else {
                Text("이 문장에서 떠오른 생각을 적어 두면 나중에 모아 볼 수 있어요.")
                    .font(ClayFont.callout())
                    .foregroundStyle(ClayTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                showsNoteEditor = true
            } label: {
                Label(existing == nil ? "노트 쓰기" : "노트 고치기", systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity)
            }
            .clayButton(.secondary, fullWidth: true)
            .padding(.top, ClayTheme.Spacing.xs)
        }
        .padding(ClayTheme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clayCard()
        .clayAppear(delay: 0.1)
    }

    // MARK: - 인물 프로필 (Plus)

    @ViewBuilder
    private func authorProfileSection(for presentation: QuotePresentation) -> some View {
        let author = presentation.author

        if plus.isUnlocked(.authorProfile) {
            VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
                HStack {
                    SectionHeader("인물 프로필")
                    Spacer()
                    PlusBadge()
                }

                if let lifespan = author.lifespanText {
                    profileRow("생몰", lifespan)
                }
                profileRow("활동", "\(author.occupation) · \(author.nationality)")
                if let era = author.era {
                    profileRow("시대", era)
                }

                ClayDivider()

                Text(author.biography)
                    .font(ClayFont.body())
                    .foregroundStyle(ClayTheme.textPrimary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                if !author.achievements.isEmpty {
                    ClayDivider()
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
            }
            .padding(ClayTheme.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .clayCard()
            .clayAppear(delay: 0.12)
        } else {
            PlusLockedPreview(
                feature: .authorProfile,
                message: "\(author.displayName)이(가) 어떤 삶을 살았고 무엇을 남겼는지 한 장에 정리해 드려요."
            ) {
                paywallFeature = .authorProfile
            } content: {
                VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
                    if let lifespan = author.lifespanText {
                        profileRow("생몰", lifespan)
                    }
                    profileRow("활동", "\(author.occupation) · \(author.nationality)")
                    Text(author.biography)
                        .font(ClayFont.body())
                        .foregroundStyle(ClayTheme.textPrimary)
                        .lineSpacing(4)
                }
            }
            .clayAppear(delay: 0.12)
        }
    }

    private func profileRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: ClayTheme.Spacing.s) {
            Text(label)
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
                .frame(width: 34, alignment: .leading)
            Text(value)
                .font(ClayFont.callout())
                .foregroundStyle(ClayTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    // MARK: - 관련 저서·연관 인물 (Plus)

    @ViewBuilder
    private func relatedSection(for presentation: QuotePresentation) -> some View {
        let author = presentation.author
        let siblings = quoteService.quotes(byAuthor: author.id).filter { $0.slug != presentation.quote.slug }

        if plus.isUnlocked(.relatedWorks) {
            VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
                HStack {
                    SectionHeader("이어서 보기")
                    Spacer()
                    PlusBadge()
                }

                if !author.notableWorks.isEmpty {
                    Text("관련 저서")
                        .font(ClayFont.caption())
                        .foregroundStyle(ClayTheme.textSecondary)
                    ForEach(Array(author.notableWorks.enumerated()), id: \.offset) { _, work in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "book.closed")
                                .font(.caption2)
                                .foregroundStyle(ClayTheme.accent)
                                .padding(.top, 3)
                            Text(work)
                                .font(ClayFont.callout())
                                .foregroundStyle(ClayTheme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    ClayDivider()
                }

                Text(siblings.isEmpty
                     ? "이 인물의 다른 명언은 아직 없어요."
                     : "이 인물의 다른 명언 \(siblings.count)편")
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.textSecondary)

                NavigationLink {
                    AuthorDetailView(authorID: author.id)
                } label: {
                    Label("인물 페이지 열기", systemImage: "chevron.right.circle.fill")
                        .font(ClayFont.headline())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ClayTheme.Spacing.s + 2)
                        .foregroundStyle(ClayTheme.textOnAccent)
                        .clayCard(
                            cornerRadius: ClayTheme.Radius.control,
                            tint: ClayTheme.accent
                        )
                }
                .padding(.top, ClayTheme.Spacing.xs)
            }
            .padding(ClayTheme.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .clayCard()
            .clayAppear(delay: 0.14)
        } else {
            PlusLockedPreview(
                feature: .relatedWorks,
                message: siblings.isEmpty
                    ? "\(author.displayName)의 저서를 함께 볼 수 있어요."
                    : "\(author.displayName)의 저서와 다른 명언 \(siblings.count)편으로 이어 볼 수 있어요.",
                previewHeight: 150
            ) {
                paywallFeature = .relatedWorks
            } content: {
                VStack(alignment: .leading, spacing: ClayTheme.Spacing.xs) {
                    ForEach(Array(author.notableWorks.prefix(3).enumerated()), id: \.offset) { _, work in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "book.closed")
                                .font(.caption2)
                                .foregroundStyle(ClayTheme.accent)
                                .padding(.top, 3)
                            Text(work)
                                .font(ClayFont.callout())
                                .foregroundStyle(ClayTheme.textPrimary)
                        }
                    }
                    ForEach(siblings.prefix(2)) { sibling in
                        Text("\u{201C}\(sibling.text)\u{201D}")
                            .font(ClayFont.callout())
                            .foregroundStyle(ClayTheme.textPrimary)
                            .lineLimit(2)
                    }
                }
            }
            .clayAppear(delay: 0.14)
        }
    }

    // MARK: - 공유 (무료)

    private func shareSection(for presentation: QuotePresentation) -> some View {
        VStack(spacing: ClayTheme.Spacing.s) {
            Button {
                showsShareCard = true
            } label: {
                Label("카드로 공유하기", systemImage: "photo.on.rectangle.angled")
                    .frame(maxWidth: .infinity)
            }
            .clayButton(.primary, fullWidth: true)

            ShareLink(item: presentation.shareText) {
                Label("글로 공유하기", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .clayButton(.secondary, fullWidth: true)
        }
        .clayAppear(delay: 0.16)
    }
}

#Preview("명언 상세") {
    QuoteDetailView(quoteID: QuoteService.shared.quoteOfTheDay().id)
        .injecting(AppEnvironment.preview())
}

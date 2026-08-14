import SwiftUI

/// 앱을 열면 바로 오늘의 명언이 보이는 메인 화면.
struct HomeView: View {
    @Environment(ScheduleStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(AppRouter.self) private var router

    @State private var editorTarget: ScheduleEditorTarget?

    /// 상태를 갖지 않는 뷰모델이라 매 렌더마다 새로 만들어도 비용이 없다.
    private var viewModel: HomeViewModel {
        HomeViewModel(store: store, settings: settings)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClayTheme.Spacing.l) {
                header
                    .clayAppear()

                quoteSection
                    .clayAppear(delay: 0.05)

                nextScheduleSection
                    .clayAppear(delay: 0.1)

                todaySection
                    .clayAppear(delay: 0.15)
            }
            .padding(.horizontal, ClayTheme.Spacing.m)
            .padding(.top, ClayTheme.Spacing.m)
            // 커스텀 탭 바에 가리지 않도록 여유를 둔다.
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
        .clayBackground()
        .sheet(item: $editorTarget) { target in
            ScheduleEditorView(target: target)
        }
    }

    // MARK: - 헤더

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.greeting())
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
            Text(viewModel.dateText())
                .font(ClayFont.hero())
                .foregroundStyle(ClayTheme.textPrimary)
                .minimumScaleFactor(0.8)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - 오늘의 명언

    private var quoteSection: some View {
        let presentation = viewModel.quoteOfTheDay()
        return VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
            QuoteCard(presentation: presentation, style: .hero) {
                router.showQuote(presentation.quote)
            }

            Button {
                router.showQuote(presentation.quote)
            } label: {
                Label("명언 상세보기", systemImage: "arrow.up.forward.circle.fill")
            }
            .clayButton(.primary, fullWidth: true)
        }
        // 날짜가 바뀌면 카드가 부드럽게 교체된다.
        .animation(.easeInOut(duration: 0.35), value: presentation.id)
    }

    // MARK: - 다음 일정

    @ViewBuilder
    private var nextScheduleSection: some View {
        // 1분마다 남은 시간을 다시 계산한다.
        TimelineView(.periodic(from: .now, by: 60)) { context in
            if let next = viewModel.nextSchedule(from: context.date) {
                VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
                    HStack {
                        Label("다음 일정", systemImage: "clock.fill")
                            .font(ClayFont.caption())
                            .foregroundStyle(ClayTheme.textSecondary)
                        Spacer()
                        if let countdown = Formatters.countdown(to: next.startDate, from: context.date) {
                            Text(countdown)
                                .font(ClayFont.headline())
                                .foregroundStyle(ClayTheme.accent)
                        }
                    }

                    HStack(spacing: ClayTheme.Spacing.s) {
                        CategoryChip(category: next.category, size: .small)
                        Text(next.displayTitle)
                            .font(ClayFont.headline())
                            .foregroundStyle(ClayTheme.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text(Formatters.time.string(from: next.startDate))
                            .font(ClayFont.callout())
                            .foregroundStyle(ClayTheme.textSecondary)
                    }

                    if next.isQuoteNotificationEnabled {
                        Divider().opacity(0.25)
                        let quote = viewModel.quote(for: next)
                        Button {
                            router.showQuote(quote.quote)
                        } label: {
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "bell.badge.fill")
                                    .font(.caption)
                                    .foregroundStyle(ClayTheme.accent)
                                Text("\u{201C}\(quote.quote.text)\u{201D}")
                                    .font(ClayFont.caption())
                                    .foregroundStyle(ClayTheme.textSecondary)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("이 일정에 예약된 명언: \(quote.quote.text)")
                    }
                }
                .padding(ClayTheme.Spacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .clayCard(cornerRadius: ClayTheme.Radius.card, elevation: 12)
            }
        }
    }

    // MARK: - 오늘의 일정

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
            SectionHeader("오늘의 일정", subtitle: subtitleText) {
                Button {
                    editorTarget = .create(date: .now)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                }
                .clayButton(.primary, cornerRadius: ClayTheme.Radius.tiny)
                .accessibilityLabel("일정 추가")
            }

            let schedules = viewModel.todaySchedules
            if schedules.isEmpty {
                EmptyStateView(
                    symbol: "calendar.badge.plus",
                    title: "오늘은 등록된 일정이 없어요",
                    message: "일정을 추가하면 그 시간에 어울리는 명언을 알림으로 보내 드려요.",
                    actionTitle: "일정 추가하기"
                ) {
                    editorTarget = .create(date: .now)
                }
                .clayCard()
            } else {
                ForEach(schedules) { item in
                    ScheduleRow(
                        item: item,
                        showsCountdown: item.isUpcoming,
                        onTap: { editorTarget = .edit(id: item.id) },
                        onDelete: { store.delete(item) },
                        onShuffleQuote: { store.shuffleQuote(for: item) }
                    )
                }
            }
        }
    }

    private var subtitleText: String {
        let count = viewModel.todaySchedules.count
        return count == 0 ? "일정 없음" : "\(count)개"
    }
}

#Preview("홈") {
    HomeView()
        .injecting(AppEnvironment.preview())
}

import SwiftUI

/// 월간 캘린더와 선택한 날짜의 일정 목록.
struct CalendarView: View {
    @Environment(ScheduleStore.self) private var store
    @Environment(CalendarService.self) private var calendarService
    @Environment(AppRouter.self) private var router

    @State private var viewModel = CalendarViewModel()
    @State private var editorTarget: ScheduleEditorTarget?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    var body: some View {
        ScrollView {
            VStack(spacing: ClayTheme.Spacing.m) {
                monthCard
                    .clayAppear()

                daySection
                    .clayAppear(delay: 0.05)

                systemCalendarSection
                    .clayAppear(delay: 0.1)
            }
            .padding(.horizontal, ClayTheme.Spacing.m)
            .padding(.top, ClayTheme.Spacing.m)
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
        .clayBackground()
        .sheet(item: $editorTarget) { target in
            ScheduleEditorView(target: target)
        }
        .onAppear(perform: syncWithRouter)
        .onChange(of: router.highlightedScheduleID) { _, _ in syncWithRouter() }
    }

    // MARK: - 월간 캘린더

    private var monthCard: some View {
        VStack(spacing: ClayTheme.Spacing.s) {
            HStack {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        viewModel.goToPreviousMonth()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                }
                .clayButton(.secondary, cornerRadius: ClayTheme.Radius.tiny)
                .accessibilityLabel("이전 달")

                Spacer()

                Text(viewModel.monthTitle)
                    .font(ClayFont.title())
                    .foregroundStyle(ClayTheme.textPrimary)
                    .contentTransition(.numericText())

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        viewModel.goToNextMonth()
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                }
                .clayButton(.secondary, cornerRadius: ClayTheme.Radius.tiny)
                .accessibilityLabel("다음 달")
            }

            HStack(spacing: 2) {
                ForEach(Array(viewModel.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(ClayFont.caption())
                        .foregroundStyle(ClayTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }

            let categoriesByDay = store.categoriesByDay(in: viewModel.displayedMonth)

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(viewModel.days) { day in
                    CalendarDayCell(
                        day: day,
                        dayNumber: viewModel.calendar.component(.day, from: day.date),
                        isSelected: viewModel.isSelected(day.date),
                        isToday: viewModel.isToday(day.date),
                        categories: categoriesByDay[viewModel.calendar.startOfDay(for: day.date)] ?? []
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            viewModel.select(day.date)
                        }
                    }
                }
            }

            if !viewModel.isShowingCurrentMonth {
                Button("오늘로 이동") {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        viewModel.goToToday()
                    }
                }
                .clayButton(.secondary)
                .padding(.top, ClayTheme.Spacing.xs)
            }
        }
        .padding(ClayTheme.Spacing.m)
        .clayCard(cornerRadius: ClayTheme.Radius.hero)
    }

    // MARK: - 선택한 날짜의 일정

    private var daySection: some View {
        let schedules = store.schedules(on: viewModel.selectedDate)

        return VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
            SectionHeader(
                Formatters.fullDate.string(from: viewModel.selectedDate),
                subtitle: schedules.isEmpty ? "일정 없음" : "\(schedules.count)개"
            ) {
                Button {
                    editorTarget = .create(date: viewModel.selectedDate)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                }
                .clayButton(.primary, cornerRadius: ClayTheme.Radius.tiny)
                .accessibilityLabel("이 날짜에 일정 추가")
            }

            if schedules.isEmpty {
                EmptyStateView(
                    symbol: "sparkles",
                    title: "이 날은 아직 비어 있어요",
                    message: "일정을 추가하면 카테고리에 맞는 명언이 함께 준비됩니다.",
                    actionTitle: "일정 추가하기"
                ) {
                    editorTarget = .create(date: viewModel.selectedDate)
                }
                .clayCard()
            } else {
                ForEach(schedules) { occurrence in
                    ScheduleRow(
                        occurrence: occurrence,
                        showsCountdown: occurrence.isUpcoming,
                        onTap: { editorTarget = .edit(id: occurrence.scheduleID) },
                        onDelete: { store.delete(occurrence.item) },
                        onShuffleQuote: { store.shuffleQuote(for: occurrence.item) }
                    )
                }
            }
        }
    }

    // MARK: - iOS 캘린더 연동 (선택 기능)

    @ViewBuilder
    private var systemCalendarSection: some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
            SectionHeader("iOS 캘린더", subtitle: "기기 캘린더의 일정을 함께 볼 수 있어요") {
                EmptyView()
            }

            if calendarService.canRead {
                let events = calendarService.systemEvents(on: viewModel.selectedDate)
                if events.isEmpty {
                    Text("이 날짜에는 iOS 캘린더 일정이 없어요.")
                        .font(ClayFont.callout())
                        .foregroundStyle(ClayTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(ClayTheme.Spacing.m)
                        .clayCard()
                } else {
                    ForEach(events) { event in
                        HStack(spacing: ClayTheme.Spacing.s) {
                            Image(systemName: "calendar")
                                .foregroundStyle(ClayTheme.textSecondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.title)
                                    .font(ClayFont.callout())
                                    .foregroundStyle(ClayTheme.textPrimary)
                                Text(Formatters.timeRange(event.start, event.end))
                                    .font(ClayFont.caption())
                                    .foregroundStyle(ClayTheme.textSecondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(ClayTheme.Spacing.s + 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .clayCard(cornerRadius: ClayTheme.Radius.control)
                    }
                }
            } else if calendarService.isDenied {
                EmptyStateView(
                    symbol: "lock.fill",
                    title: "캘린더 접근이 꺼져 있어요",
                    message: "설정 앱에서 캘린더 권한을 허용하면 기기 일정도 함께 볼 수 있어요. 허용하지 않아도 앱 일정은 그대로 사용할 수 있습니다."
                )
                .clayCard()
            } else {
                EmptyStateView(
                    symbol: "calendar.badge.clock",
                    title: "기기 캘린더와 함께 보기",
                    message: "허용하면 이 날짜의 iOS 캘린더 일정도 아래에 표시됩니다.",
                    actionTitle: "캘린더 불러오기"
                ) {
                    Task { await calendarService.requestFullAccess() }
                }
                .clayCard()
            }
        }
    }

    /// 알림/위젯에서 특정 일정으로 들어온 경우 그 날짜를 선택한다.
    private func syncWithRouter() {
        guard let id = router.highlightedScheduleID, let item = store.item(id: id) else { return }
        // 반복 일정은 첫 회차가 아니라 앞으로 올 회차의 날짜로 이동한다.
        let occurrence = item.nextOccurrence() ?? item.firstOccurrence
        viewModel.select(occurrence.start)
        editorTarget = .edit(id: id)
        router.highlightedScheduleID = nil
    }
}

#Preview("캘린더") {
    CalendarView()
        .injecting(AppEnvironment.preview())
}

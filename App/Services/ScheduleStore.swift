import Foundation
import SwiftData
import WidgetKit

/// 일정 CRUD 와 그에 따르는 부수 작업(알림 재예약, 위젯 스냅샷 갱신,
/// iOS 캘린더 미러링)을 한곳에서 처리한다.
///
/// 뷰와 뷰모델은 SwiftData 컨텍스트를 직접 만지지 않고 이 타입만 사용한다.
@MainActor
@Observable
final class ScheduleStore {
    private(set) var items: [ScheduleItem] = []
    /// 사용자에게 보여 줄 마지막 오류 메시지.
    var lastErrorMessage: String?

    private let context: ModelContext
    private let notifications: NotificationService
    private let calendarService: CalendarService
    private let settings: AppSettings
    private let snapshotStore: WidgetSnapshotStore
    private let calendar: Calendar

    init(
        context: ModelContext,
        notifications: NotificationService,
        calendarService: CalendarService,
        settings: AppSettings,
        snapshotStore: WidgetSnapshotStore = WidgetSnapshotStore(),
        calendar: Calendar = .current
    ) {
        self.context = context
        self.notifications = notifications
        self.calendarService = calendarService
        self.settings = settings
        self.snapshotStore = snapshotStore
        self.calendar = calendar
        reload()
    }

    // MARK: - 조회

    /// 저장소 전체를 다시 읽는다. 일정 수가 많지 않아 전체 로드가 가장 단순하고 안전하다.
    func reload() {
        let descriptor = FetchDescriptor<ScheduleItem>(
            sortBy: [SortDescriptor(\.startDate, order: .forward)]
        )
        do {
            items = try context.fetch(descriptor)
        } catch {
            items = []
            lastErrorMessage = "일정을 불러오지 못했습니다."
            AppLog.schedule.error("fetch 실패: \(error.localizedDescription, privacy: .public)")
        }
    }

    func item(id: UUID) -> ScheduleItem? {
        items.first { $0.id == id }
    }

    func schedules(on date: Date) -> [ScheduleItem] {
        items
            .filter { calendar.isDate($0.startDate, inSameDayAs: date) }
            .sorted { $0.startDate < $1.startDate }
    }

    var todaySchedules: [ScheduleItem] { schedules(on: .now) }

    /// 아직 시작하지 않은 가장 가까운 일정.
    func nextSchedule(after date: Date = .now) -> ScheduleItem? {
        items
            .filter { $0.startDate > date }
            .min { $0.startDate < $1.startDate }
    }

    /// 캘린더 화면의 날짜별 점 표시에 쓰는 색인.
    func categoriesByDay(in month: Date) -> [Date: [AppCategory]] {
        var result: [Date: [AppCategory]] = [:]
        for item in items where calendar.isDate(item.startDate, equalTo: month, toGranularity: .month) {
            let day = calendar.startOfDay(for: item.startDate)
            var categories = result[day] ?? []
            if !categories.contains(item.category) {
                categories.append(item.category)
            }
            result[day] = categories
        }
        return result
    }

    // MARK: - 생성 / 수정 / 삭제

    struct Draft {
        var title: String
        var startDate: Date
        var endDate: Date
        var category: AppCategory
        var memo: String
        var isQuoteNotificationEnabled: Bool
        var quoteSlug: String?
    }

    @discardableResult
    func create(_ draft: Draft) throws -> ScheduleItem {
        if let failure = ScheduleValidator.validate(
            title: draft.title,
            start: draft.startDate,
            end: draft.endDate
        ) {
            throw failure
        }

        let item = ScheduleItem(
            title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: draft.startDate,
            endDate: draft.endDate,
            category: draft.category,
            memo: draft.memo,
            isQuoteNotificationEnabled: draft.isQuoteNotificationEnabled,
            quoteSlug: draft.quoteSlug
        )
        context.insert(item)
        save()
        reload()

        Task { await applySideEffects(for: item, isNew: true) }
        return item
    }

    func update(_ item: ScheduleItem, with draft: Draft) throws {
        if let failure = ScheduleValidator.validate(
            title: draft.title,
            start: draft.startDate,
            end: draft.endDate
        ) {
            throw failure
        }

        item.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        item.startDate = draft.startDate
        item.endDate = max(draft.endDate, draft.startDate)
        item.category = draft.category
        item.memo = draft.memo
        item.isQuoteNotificationEnabled = draft.isQuoteNotificationEnabled
        item.quoteSlug = draft.quoteSlug
        item.updatedAt = .now

        save()
        reload()

        Task { await applySideEffects(for: item, isNew: false) }
    }

    func delete(_ item: ScheduleItem) {
        let id = item.id
        let exportedIdentifier = item.systemEventIdentifier

        notifications.cancel(scheduleID: id)
        context.delete(item)
        save()
        reload()

        if let exportedIdentifier {
            calendarService.removeExported(identifier: exportedIdentifier)
        }
        publishSnapshot()
    }

    func delete(ids: [UUID]) {
        for id in ids {
            if let item = item(id: id) { delete(item) }
        }
    }

    /// 일정에 연결된 명언을 다른 것으로 바꾼다(같은 카테고리 내에서 순환).
    func shuffleQuote(for item: ScheduleItem, service: QuoteService = .shared) {
        let pool = service.candidatePool(for: item.category)
        guard !pool.isEmpty else { return }
        let current = item.resolvedQuote(using: service)
        let currentIndex = pool.firstIndex { $0.slug == current.slug } ?? -1
        let next = pool[(currentIndex + 1) % pool.count]
        item.quoteSlug = next.slug
        item.updatedAt = .now
        save()
        Task { await notifications.schedule(for: item) }
    }

    // MARK: - 부수 작업

    private func applySideEffects(for item: ScheduleItem, isNew: Bool) async {
        await notifications.schedule(for: item)

        if settings.mirrorsToSystemCalendar {
            await mirrorToSystemCalendar(item, isNew: isNew)
        }
        publishSnapshot()
    }

    private func mirrorToSystemCalendar(_ item: ScheduleItem, isNew: Bool) async {
        let notes = item.memo.isEmpty ? nil : item.memo
        let identifier: String?
        if let existing = item.systemEventIdentifier, !isNew {
            identifier = await calendarService.updateExported(
                identifier: existing,
                title: "\(item.category.emoji) \(item.displayTitle)",
                start: item.startDate,
                end: item.endDate,
                notes: notes
            )
        } else {
            identifier = await calendarService.export(
                title: "\(item.category.emoji) \(item.displayTitle)",
                start: item.startDate,
                end: item.endDate,
                notes: notes
            )
        }

        if let identifier {
            item.systemEventIdentifier = identifier
            save()
        }
    }

    /// 위젯이 읽을 스냅샷을 갱신하고 타임라인을 다시 만들게 한다.
    func publishSnapshot() {
        // 위젯은 오늘/내일 정도만 보여 주므로 최근·근시일 일정만 담는다.
        let lowerBound = calendar.startOfDay(for: .now)
        let upperBound = calendar.date(byAdding: .day, value: 8, to: lowerBound) ?? lowerBound

        let relevant = items
            .filter { $0.startDate >= lowerBound && $0.startDate < upperBound }
            .sorted { $0.startDate < $1.startDate }
            .prefix(40)
            .map { $0.snapshot() }

        snapshotStore.save(WidgetSnapshot(generatedAt: .now, schedules: Array(relevant)))
        WidgetCenter.shared.reloadTimelines(ofKind: AppGroup.widgetKind)
    }

    /// 앱 시작 시 호출. 오래 실행하지 않아 사라진 알림을 복구한다.
    func refreshOnLaunch() async {
        reload()
        publishSnapshot()
        await notifications.refreshAuthorizationStatus()
        if notifications.isAuthorized {
            await notifications.rescheduleAll(items: items)
            if settings.isDailyQuoteEnabled {
                await notifications.scheduleDailyQuote(
                    hour: settings.dailyQuoteHour,
                    minute: settings.dailyQuoteMinute,
                    preferred: settings.preferredCategory
                )
            }
        }
    }

    private func save() {
        do {
            try context.save()
        } catch {
            lastErrorMessage = "일정을 저장하지 못했습니다."
            AppLog.schedule.error("save 실패: \(error.localizedDescription, privacy: .public)")
        }
    }
}

extension ScheduleStore.Draft {
    /// 새 일정의 기본값. 선택한 날짜의 다음 정시부터 1시간.
    static func makeNew(on date: Date, calendar: Calendar = .current) -> Self {
        let now = Date.now
        let base = calendar.isDateInToday(date) ? now : calendar.startOfDay(for: date).addingTimeInterval(9 * 3600)
        let rounded = calendar.date(
            bySetting: .minute,
            value: 0,
            of: base.addingTimeInterval(3600)
        ) ?? base.addingTimeInterval(3600)

        return Self(
            title: "",
            startDate: rounded,
            endDate: rounded.addingTimeInterval(3600),
            category: .study,
            memo: "",
            isQuoteNotificationEnabled: true,
            quoteSlug: nil
        )
    }

    init(item: ScheduleItem) {
        self.init(
            title: item.title,
            startDate: item.startDate,
            endDate: item.endDate,
            category: item.category,
            memo: item.memo,
            isQuoteNotificationEnabled: item.isQuoteNotificationEnabled,
            quoteSlug: item.quoteSlug
        )
    }
}

import Foundation
import SwiftData

/// 앱 내부에서 관리하는 일정.
///
/// SwiftData 모델이며 App Group 컨테이너에 저장된다.
@Model
final class ScheduleItem {
    /// 알림 식별자와 딥링크의 기준이 되는 값.
    @Attribute(.unique) var id: UUID
    var title: String
    var startDate: Date
    var endDate: Date
    /// `AppCategory.rawValue`. enum 을 직접 저장하지 않는 이유는
    /// 나중에 케이스가 사라져도 기존 데이터가 깨지지 않게 하기 위함이다.
    var categoryRaw: String
    var memo: String
    var isQuoteNotificationEnabled: Bool
    /// 이 일정에 배정된 명언. 비어 있으면 카테고리에서 결정적으로 계산한다.
    var quoteSlug: String?
    /// iOS 캘린더로 내보냈을 때의 EKEvent 식별자.
    var systemEventIdentifier: String?
    /// `RecurrenceFrequency.rawValue`. 반복하지 않는 일정은 "none".
    ///
    /// 기본값을 두어 반복 기능이 없던 버전에서 올라와도 마이그레이션이 필요 없다.
    var recurrenceRaw: String = RecurrenceFrequency.none.rawValue
    /// 반복 종료일(그날 포함). nil 이면 종료 없이 계속 반복한다.
    var recurrenceEndDate: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        startDate: Date,
        endDate: Date,
        category: AppCategory,
        memo: String = "",
        isQuoteNotificationEnabled: Bool = true,
        quoteSlug: String? = nil,
        systemEventIdentifier: String? = nil,
        recurrence: RecurrenceRule = .none,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        // 종료 시각이 시작보다 빠른 데이터가 저장되지 않도록 여기서 막는다.
        self.endDate = max(endDate, startDate)
        self.categoryRaw = category.rawValue
        self.memo = memo
        self.isQuoteNotificationEnabled = isQuoteNotificationEnabled
        self.quoteSlug = quoteSlug
        self.systemEventIdentifier = systemEventIdentifier
        self.recurrenceRaw = recurrence.frequency.rawValue
        self.recurrenceEndDate = recurrence.endDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension ScheduleItem {
    var category: AppCategory {
        get { AppCategory(storedValue: categoryRaw) }
        set { categoryRaw = newValue.rawValue }
    }

    var recurrence: RecurrenceRule {
        get {
            RecurrenceRule(
                frequency: RecurrenceFrequency(storedValue: recurrenceRaw),
                endDate: recurrenceEndDate
            )
        }
        set {
            recurrenceRaw = newValue.frequency.rawValue
            recurrenceEndDate = newValue.endDate
        }
    }

    var isRecurring: Bool { recurrence.isRepeating }

    /// 화면에 보여 줄 제목. 비어 있으면 카테고리 이름으로 대체한다.
    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? category.title : trimmed
    }

    var duration: TimeInterval { max(0, endDate.timeIntervalSince(startDate)) }

    var isAllDayLike: Bool { duration >= 60 * 60 * 23 }

    func occurs(on date: Date, calendar: Calendar = .current) -> Bool {
        occurrence(on: date, calendar: calendar) != nil
    }

    var isUpcoming: Bool { startDate > .now }

    /// 일정에 연결된 명언. 저장된 slug 가 없거나 유효하지 않으면
    /// 카테고리 + 일정 식별자로부터 결정적으로 계산한다.
    func resolvedQuote(using service: QuoteService = .shared) -> Quote {
        resolvedQuote(at: startDate, using: service)
    }

    /// 반복 회차별 명언. 명언을 고정해 두었으면 회차와 무관하게 그것을 쓴다.
    func resolvedQuote(at start: Date, using service: QuoteService = .shared) -> Quote {
        if let quoteSlug, let stored = service.quote(slug: quoteSlug) {
            return stored
        }
        return service.quote(forScheduleID: id, start: start, category: category)
    }

    func snapshot() -> ScheduleSnapshot {
        ScheduleSnapshot(
            id: id,
            title: displayTitle,
            start: startDate,
            end: endDate,
            category: category
        )
    }

    /// 알림 센터에 등록할 때 쓰는 식별자.
    /// 반복 회차는 이 값을 접두사로 삼아 뒤에 시작 시각을 덧붙인다.
    var notificationIdentifier: String { "schedule-\(id.uuidString)" }
}

// MARK: - 반복 회차

extension ScheduleItem {
    /// 저장된 시작 시각 그대로의 첫 회차.
    var firstOccurrence: ScheduleOccurrence {
        ScheduleOccurrence(item: self, start: startDate, end: endDate)
    }

    /// `lowerBound...upperBound` 구간에 들어오는 회차들. 반복하지 않으면 최대 1건.
    func occurrences(
        from lowerBound: Date,
        to upperBound: Date,
        limit: Int = 400,
        calendar: Calendar = .current
    ) -> [ScheduleOccurrence] {
        let length = duration
        return recurrence
            .occurrenceStarts(
                anchor: startDate,
                from: lowerBound,
                to: upperBound,
                limit: limit,
                calendar: calendar
            )
            .map { ScheduleOccurrence(item: self, start: $0, end: $0.addingTimeInterval(length)) }
    }

    /// 그날 시작하는 회차. 없으면 nil.
    func occurrence(on date: Date, calendar: Calendar = .current) -> ScheduleOccurrence? {
        let dayStart = calendar.startOfDay(for: date)
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return nil }
        return occurrences(
            from: dayStart,
            to: nextDay.addingTimeInterval(-1),
            limit: 1,
            calendar: calendar
        ).first
    }

    /// `date` 이후 가장 먼저 시작하는 회차.
    /// - Parameter horizonDays: 이 기간 안에서만 찾는다. 종료 없는 반복도 무한히 뒤지지 않게 한다.
    func nextOccurrence(
        after date: Date = .now,
        horizonDays: Int = 400,
        calendar: Calendar = .current
    ) -> ScheduleOccurrence? {
        guard let upperBound = calendar.date(byAdding: .day, value: horizonDays, to: date) else {
            return nil
        }
        return occurrences(
            from: date.addingTimeInterval(1),
            to: upperBound,
            limit: 1,
            calendar: calendar
        ).first
    }
}

/// 일정 저장 전에 검증하는 규칙. 뷰모델과 테스트가 공유한다.
enum ScheduleValidator {
    enum Failure: LocalizedError, Equatable {
        case emptyTitle
        case endBeforeStart
        case tooFarInPast
        case recurrenceEndBeforeStart

        var errorDescription: String? {
            switch self {
            case .emptyTitle: "일정 제목을 입력해 주세요."
            case .endBeforeStart: "종료 시간이 시작 시간보다 빠릅니다."
            case .tooFarInPast: "너무 과거의 날짜입니다. 다시 확인해 주세요."
            case .recurrenceEndBeforeStart: "반복 종료일이 시작 날짜보다 빠릅니다."
            }
        }
    }

    static func validate(
        title: String,
        start: Date,
        end: Date,
        recurrence: RecurrenceRule = .none,
        calendar: Calendar = .current
    ) -> Failure? {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .emptyTitle }
        if end < start { return .endBeforeStart }
        // 1900년 이전 등 명백히 잘못된 입력만 걸러 낸다. 과거 일정 기록 자체는 허용한다.
        if start.timeIntervalSince1970 < -2_208_988_800 { return .tooFarInPast }
        // 종료일은 날짜 단위라 첫 회차와 같은 날이면 통과시킨다.
        if
            recurrence.isRepeating,
            let repeatEnd = recurrence.endDate,
            calendar.startOfDay(for: repeatEnd) < calendar.startOfDay(for: start)
        {
            return .recurrenceEndBeforeStart
        }
        return nil
    }
}

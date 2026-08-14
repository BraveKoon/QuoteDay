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
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension ScheduleItem {
    var category: AppCategory {
        get { AppCategory(storedValue: categoryRaw) }
        set { categoryRaw = newValue.rawValue }
    }

    /// 화면에 보여 줄 제목. 비어 있으면 카테고리 이름으로 대체한다.
    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? category.title : trimmed
    }

    var duration: TimeInterval { max(0, endDate.timeIntervalSince(startDate)) }

    var isAllDayLike: Bool { duration >= 60 * 60 * 23 }

    func occurs(on date: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(startDate, inSameDayAs: date)
    }

    var isUpcoming: Bool { startDate > .now }

    /// 일정에 연결된 명언. 저장된 slug 가 없거나 유효하지 않으면
    /// 카테고리 + 일정 식별자로부터 결정적으로 계산한다.
    func resolvedQuote(using service: QuoteService = .shared) -> Quote {
        if let quoteSlug, let stored = service.quote(slug: quoteSlug) {
            return stored
        }
        return service.quote(forScheduleID: id, start: startDate, category: category)
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
    var notificationIdentifier: String { "schedule-\(id.uuidString)" }
}

/// 일정 저장 전에 검증하는 규칙. 뷰모델과 테스트가 공유한다.
enum ScheduleValidator {
    enum Failure: LocalizedError, Equatable {
        case emptyTitle
        case endBeforeStart
        case tooFarInPast

        var errorDescription: String? {
            switch self {
            case .emptyTitle: "일정 제목을 입력해 주세요."
            case .endBeforeStart: "종료 시간이 시작 시간보다 빠릅니다."
            case .tooFarInPast: "너무 과거의 날짜입니다. 다시 확인해 주세요."
            }
        }
    }

    static func validate(title: String, start: Date, end: Date) -> Failure? {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .emptyTitle }
        if end < start { return .endBeforeStart }
        // 1900년 이전 등 명백히 잘못된 입력만 걸러 낸다. 과거 일정 기록 자체는 허용한다.
        if start.timeIntervalSince1970 < -2_208_988_800 { return .tooFarInPast }
        return nil
    }
}

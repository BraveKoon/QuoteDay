import Foundation

/// 위젯이 읽어 가는 일정 요약 한 건.
public struct ScheduleSnapshot: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let start: Date
    public let end: Date
    public let categoryRaw: String

    public init(id: UUID, title: String, start: Date, end: Date, category: AppCategory) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.categoryRaw = category.rawValue
    }

    public var category: AppCategory { AppCategory(storedValue: categoryRaw) }
}

/// 앱 → 위젯으로 넘기는 데이터 묶음.
///
/// 위젯이 SwiftData 스토어를 직접 열지 않고 이 스냅샷만 읽도록 해서
/// 스토어 스키마 변경이나 마이그레이션 중에도 위젯이 깨지지 않게 했다.
/// 스냅샷이 아예 없어도 위젯은 "오늘의 명언"을 자체 계산할 수 있다.
public struct WidgetSnapshot: Codable, Hashable, Sendable {
    public var generatedAt: Date
    public var schedules: [ScheduleSnapshot]

    public init(generatedAt: Date = .now, schedules: [ScheduleSnapshot] = []) {
        self.generatedAt = generatedAt
        self.schedules = schedules
    }

    public static let empty = WidgetSnapshot(generatedAt: .distantPast, schedules: [])

    /// 지정한 날짜의 일정만 시간순으로.
    public func schedules(on date: Date, calendar: Calendar = .current) -> [ScheduleSnapshot] {
        schedules
            .filter { calendar.isDate($0.start, inSameDayAs: date) }
            .sorted { $0.start < $1.start }
    }

    /// `date` 이후 가장 먼저 시작하는 일정.
    public func nextSchedule(after date: Date = .now) -> ScheduleSnapshot? {
        schedules
            .filter { $0.start > date }
            .min { $0.start < $1.start }
    }
}

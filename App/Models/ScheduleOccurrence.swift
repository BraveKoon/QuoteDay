import Foundation

/// 반복 일정의 "한 회차".
///
/// 반복 일정은 회차마다 행을 만들지 않고 원본 한 건에서 계산해 낸다.
/// 화면·알림·위젯은 `ScheduleItem` 대신 이 값을 통해 일정을 다루기 때문에
/// 반복 여부와 상관없이 같은 코드로 처리된다.
struct ScheduleOccurrence: Identifiable, Hashable {
    /// 이 회차를 만들어 낸 원본 일정.
    let item: ScheduleItem
    let start: Date
    let end: Date

    init(item: ScheduleItem, start: Date, end: Date) {
        self.item = item
        self.start = start
        self.end = max(end, start)
    }

    /// 원본 식별자 + 시작 시각. 같은 일정의 다른 회차와 절대 겹치지 않는다.
    var id: String { "\(item.id.uuidString)@\(Int(start.timeIntervalSince1970))" }

    var scheduleID: UUID { item.id }
    var displayTitle: String { item.displayTitle }
    var category: AppCategory { item.category }
    var memo: String { item.memo }
    var isQuoteNotificationEnabled: Bool { item.isQuoteNotificationEnabled }
    var isRecurring: Bool { item.isRecurring }
    var duration: TimeInterval { end.timeIntervalSince(start) }
    var isUpcoming: Bool { start > .now }

    /// 이 회차에 배정된 명언.
    /// 명언을 고정해 두지 않았다면 회차마다 다른 명언이 붙는다.
    func resolvedQuote(using service: QuoteService = .shared) -> Quote {
        item.resolvedQuote(at: start, using: service)
    }

    func snapshot() -> ScheduleSnapshot {
        ScheduleSnapshot(
            id: item.id,
            title: displayTitle,
            start: start,
            end: end,
            category: category
        )
    }

    /// 알림 센터에 등록할 때 쓰는 식별자.
    /// 반복 회차는 뒤에 시작 시각을 붙여 서로 구분하고, 접두사는 원본과 공유해서
    /// 일정 하나에 딸린 알림을 한 번에 지울 수 있게 한다.
    var notificationIdentifier: String {
        isRecurring
            ? "\(item.notificationIdentifier)@\(Int(start.timeIntervalSince1970))"
            : item.notificationIdentifier
    }

    static func == (lhs: ScheduleOccurrence, rhs: ScheduleOccurrence) -> Bool {
        lhs.id == rhs.id && lhs.end == rhs.end
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

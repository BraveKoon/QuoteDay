import Foundation

/// 홈 화면이 필요로 하는 값을 모아 준다.
///
/// 저장소를 직접 참조하되 계산은 모두 순수 함수라서 뷰에서 분리해 테스트할 수 있다.
@MainActor
@Observable
final class HomeViewModel {
    private let store: ScheduleStore
    private let settings: AppSettings
    private let quoteService: QuoteService
    private let calendar: Calendar

    init(
        store: ScheduleStore,
        settings: AppSettings,
        quoteService: QuoteService = .shared,
        calendar: Calendar = .current
    ) {
        self.store = store
        self.settings = settings
        self.quoteService = quoteService
        self.calendar = calendar
    }

    // MARK: - 오늘의 명언

    /// ZenQuotes 사용이 켜져 있고 오늘 자 캐시가 있으면 그것을, 아니면 내장 명언을 쓴다.
    func quoteOfTheDay(for date: Date = .now) -> QuotePresentation {
        quoteService.todayPresentation(
            for: date,
            preferred: settings.preferredCategory,
            useRemote: settings.usesRemoteQuoteOfTheDay
        )
    }

    // MARK: - 날짜 / 인사

    func dateText(for date: Date = .now) -> String {
        Formatters.fullDate.string(from: date)
    }

    /// 시간대에 따른 인사말.
    func greeting(for date: Date = .now) -> String {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<11: return "좋은 아침이에요"
        case 11..<14: return "점심 무렵이에요"
        case 14..<18: return "오후를 보내고 있어요"
        case 18..<22: return "저녁이에요"
        default: return "늦은 밤이에요"
        }
    }

    // MARK: - 일정

    var todaySchedules: [ScheduleItem] {
        store.schedules(on: .now)
    }

    func nextSchedule(from date: Date = .now) -> ScheduleItem? {
        store.nextSchedule(after: date)
    }

    /// 다음 일정까지 남은 시간 문구. 없으면 nil.
    func countdownText(from date: Date = .now) -> String? {
        guard let next = nextSchedule(from: date) else { return nil }
        return Formatters.countdown(to: next.startDate, from: date)
    }

    /// 다음 일정에 배정된 명언(미리보기용).
    func quote(for item: ScheduleItem) -> QuotePresentation {
        quoteService.presentation(for: item.resolvedQuote(using: quoteService))
    }

    var hasAnySchedule: Bool { !store.items.isEmpty }
}

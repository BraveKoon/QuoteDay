import Foundation

/// 월간 캘린더 격자에 들어가는 하루.
struct CalendarDay: Identifiable, Hashable {
    let date: Date
    /// 앞뒤 달에서 채워 넣은 칸인지.
    let isInDisplayedMonth: Bool

    var id: Date { date }
}

/// 월간 캘린더의 날짜 계산과 선택 상태.
///
/// 저장소에 의존하지 않는 순수한 날짜 로직이라 단위 테스트로 검증한다.
@MainActor
@Observable
final class CalendarViewModel {
    private(set) var displayedMonth: Date
    var selectedDate: Date

    let calendar: Calendar

    init(referenceDate: Date = .now, calendar: Calendar = .current) {
        self.calendar = calendar
        self.selectedDate = calendar.startOfDay(for: referenceDate)
        self.displayedMonth = calendar.startOfMonth(for: referenceDate)
    }

    var monthTitle: String {
        Formatters.monthTitle.string(from: displayedMonth)
    }

    /// 로케일의 주 시작 요일에 맞춰 정렬된 요일 약어.
    var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let firstIndex = calendar.firstWeekday - 1
        guard firstIndex > 0, firstIndex < symbols.count else { return symbols }
        return Array(symbols[firstIndex...] + symbols[..<firstIndex])
    }

    /// 6주(42칸) 고정 격자. 칸 수가 달마다 바뀌면 레이아웃이 흔들리기 때문이다.
    var days: [CalendarDay] {
        let monthStart = displayedMonth
        let weekdayOfFirst = calendar.component(.weekday, from: monthStart)
        let leading = (weekdayOfFirst - calendar.firstWeekday + 7) % 7

        guard let gridStart = calendar.date(byAdding: .day, value: -leading, to: monthStart) else {
            return []
        }

        return (0..<42).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: gridStart) else {
                return nil
            }
            return CalendarDay(
                date: date,
                isInDisplayedMonth: calendar.isDate(date, equalTo: monthStart, toGranularity: .month)
            )
        }
    }

    func isSelected(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }

    func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    func select(_ date: Date) {
        selectedDate = calendar.startOfDay(for: date)
        // 앞뒤 달의 날짜를 누르면 그 달로 따라간다.
        if !calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month) {
            displayedMonth = calendar.startOfMonth(for: date)
        }
    }

    func goToPreviousMonth() {
        shiftMonth(by: -1)
    }

    func goToNextMonth() {
        shiftMonth(by: 1)
    }

    func goToToday() {
        let today = Date.now
        displayedMonth = calendar.startOfMonth(for: today)
        selectedDate = calendar.startOfDay(for: today)
    }

    var isShowingCurrentMonth: Bool {
        calendar.isDate(displayedMonth, equalTo: .now, toGranularity: .month)
    }

    private func shiftMonth(by value: Int) {
        guard let next = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        displayedMonth = calendar.startOfMonth(for: next)
    }
}

extension Calendar {
    /// 해당 날짜가 속한 달의 1일 0시.
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? startOfDay(for: date)
    }
}

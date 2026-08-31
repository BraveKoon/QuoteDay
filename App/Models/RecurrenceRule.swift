import Foundation

/// 일정 반복 주기.
///
/// `rawValue` 를 저장하므로 나중에 케이스가 바뀌어도 기존 데이터가 깨지지 않는다.
enum RecurrenceFrequency: String, CaseIterable, Identifiable, Sendable {
    case none
    case daily
    case weekday
    case weekly
    case biweekly
    case monthly
    case yearly

    var id: String { rawValue }

    /// 모르는 값이 들어오면 "반복 안 함" 으로 떨어뜨린다.
    init(storedValue: String?) {
        self = RecurrenceFrequency(rawValue: storedValue ?? "") ?? .none
    }

    var title: String {
        switch self {
        case .none: "반복 안 함"
        case .daily: "매일"
        case .weekday: "주중 매일"
        case .weekly: "매주"
        case .biweekly: "2주마다"
        case .monthly: "매월"
        case .yearly: "매년"
        }
    }

    /// 선택 버튼처럼 좁은 자리에 넣는 짧은 이름.
    var shortTitle: String {
        switch self {
        case .none: "안 함"
        case .daily: "매일"
        case .weekday: "주중"
        case .weekly: "매주"
        case .biweekly: "격주"
        case .monthly: "매월"
        case .yearly: "매년"
        }
    }
}

/// 일정 하나의 반복 규칙.
///
/// 반복 일정을 여러 행으로 복제해 저장하지 않고 이 규칙만 저장한 뒤,
/// 화면에 필요한 구간의 회차를 그때그때 계산한다.
/// 그래서 "매일 · 종료 없음" 같은 규칙도 저장 비용이 일정 한 건과 같다.
struct RecurrenceRule: Equatable, Hashable, Sendable {
    var frequency: RecurrenceFrequency
    /// 마지막 반복 날짜(그날 포함). nil 이면 종료 없이 계속 반복한다.
    var endDate: Date?

    static let none = RecurrenceRule(frequency: .none, endDate: nil)

    init(frequency: RecurrenceFrequency = .none, endDate: Date? = nil) {
        self.frequency = frequency
        // 반복하지 않는 일정에 종료일이 남아 있으면 혼란만 준다.
        self.endDate = frequency == .none ? nil : endDate
    }

    var isRepeating: Bool { frequency != .none }
}

// MARK: - 설명 문구

extension RecurrenceRule {
    /// "매주 화요일 · 3월 1일 (일)까지" 처럼 규칙을 한 줄로 설명한다.
    /// - Parameter anchor: 첫 회차(= 일정의 시작 시각).
    func summary(anchor: Date, calendar: Calendar = .current) -> String {
        guard isRepeating else { return RecurrenceFrequency.none.title }

        var text = frequency.title
        switch frequency {
        case .weekly, .biweekly:
            let symbols = calendar.standaloneWeekdaySymbols
            let index = calendar.component(.weekday, from: anchor) - 1
            if symbols.indices.contains(index) {
                text += " \(symbols[index])"
            }
        case .monthly:
            text += " \(calendar.component(.day, from: anchor))일"
        case .yearly:
            text += " \(calendar.component(.month, from: anchor))월 \(calendar.component(.day, from: anchor))일"
        case .none, .daily, .weekday:
            break
        }

        if let endDate {
            text += " · \(Formatters.dayAndWeekday.string(from: endDate))까지"
        }
        return text
    }
}

// MARK: - 회차 계산

extension RecurrenceRule {
    /// 반복이 끝나는 시각. 종료일이 있으면 그날의 끝, 없으면 nil.
    func repeatEnd(calendar: Calendar = .current) -> Date? {
        guard isRepeating, let endDate else { return nil }
        let dayStart = calendar.startOfDay(for: endDate)
        return calendar.date(byAdding: .day, value: 1, to: dayStart) ?? endDate
    }

    /// `anchor` 를 첫 회차로 삼아 `lowerBound...upperBound` 안에 들어오는 시작 시각들.
    ///
    /// 창(window)이 아무리 멀리 있어도 첫 후보 위치를 계산으로 건너뛰기 때문에
    /// 순회 비용은 저장된 일정의 나이가 아니라 창 크기에만 비례한다.
    ///
    /// - Parameter limit: 최대 개수. 1 을 주면 "다음 회차"만 값싸게 찾을 수 있다.
    func occurrenceStarts(
        anchor: Date,
        from lowerBound: Date,
        to upperBound: Date,
        limit: Int = 400,
        calendar: Calendar = .current
    ) -> [Date] {
        guard limit > 0, lowerBound <= upperBound, anchor <= upperBound else { return [] }

        let end = min(repeatEnd(calendar: calendar) ?? upperBound, upperBound)
        guard anchor <= end else { return [] }

        switch frequency {
        case .none:
            return anchor >= lowerBound ? [anchor] : []
        case .daily, .weekday:
            return dailyStarts(anchor: anchor, from: lowerBound, to: end, limit: limit, calendar: calendar)
        case .weekly:
            return steppedStarts(
                anchor: anchor, from: lowerBound, to: end, limit: limit,
                approximatePeriodDays: 7, calendar: calendar
            ) { index in
                calendar.date(byAdding: .day, value: index * 7, to: anchor)
            }
        case .biweekly:
            return steppedStarts(
                anchor: anchor, from: lowerBound, to: end, limit: limit,
                approximatePeriodDays: 14, calendar: calendar
            ) { index in
                calendar.date(byAdding: .day, value: index * 14, to: anchor)
            }
        case .monthly:
            // 31일에 시작한 일정은 짧은 달에서 그 달의 마지막 날로 당겨진다(Calendar 기본 동작).
            return steppedStarts(
                anchor: anchor, from: lowerBound, to: end, limit: limit,
                approximatePeriodDays: 31, calendar: calendar
            ) { index in
                calendar.date(byAdding: .month, value: index, to: anchor)
            }
        case .yearly:
            return steppedStarts(
                anchor: anchor, from: lowerBound, to: end, limit: limit,
                approximatePeriodDays: 366, calendar: calendar
            ) { index in
                calendar.date(byAdding: .year, value: index, to: anchor)
            }
        }
    }

    /// 매일 / 주중 매일: 창 안의 날짜를 하루씩 훑으며 같은 시각을 만든다.
    private func dailyStarts(
        anchor: Date,
        from lowerBound: Date,
        to end: Date,
        limit: Int,
        calendar: Calendar
    ) -> [Date] {
        let time = calendar.dateComponents([.hour, .minute, .second], from: anchor)
        let lastDay = calendar.startOfDay(for: end)
        var day = calendar.startOfDay(for: max(anchor, lowerBound))
        var result: [Date] = []

        while day <= lastDay, result.count < limit {
            if
                let candidate = Self.date(onDay: day, time: time, calendar: calendar),
                candidate >= anchor,
                candidate >= lowerBound,
                candidate <= end,
                frequency != .weekday || Self.isWeekday(candidate, calendar: calendar)
            {
                result.append(candidate)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    /// 매주 / 격주 / 매월 / 매년: `anchor` 로부터 n 번째 회차를 직접 만든다.
    ///
    /// 이전 회차가 아니라 항상 `anchor` 기준으로 계산해서
    /// 31일 → 28일처럼 한 번 당겨진 날짜가 그대로 굳지 않게 한다.
    private func steppedStarts(
        anchor: Date,
        from lowerBound: Date,
        to end: Date,
        limit: Int,
        approximatePeriodDays: Double,
        calendar: Calendar,
        candidate: (Int) -> Date?
    ) -> [Date] {
        var index = 0
        if lowerBound > anchor {
            // 주기를 넉넉하게 잡아 실제 회차보다 앞선 위치에서 시작한다(건너뛰지 않도록).
            let periods = lowerBound.timeIntervalSince(anchor) / (approximatePeriodDays * 86_400)
            index = max(0, min(periods, 1_000_000).rounded(.down).intValue - 1)
        }

        var result: [Date] = []
        var steps = 0
        while result.count < limit, steps < 10_000 {
            steps += 1
            guard let date = candidate(index) else { break }
            index += 1
            if date > end { break }
            if date < lowerBound || date < anchor { continue }
            result.append(date)
        }
        return result
    }

    /// 그날의 같은 시각. 자정 회차가 다음 날로 밀리지 않도록 날짜 성분을 직접 조립한다.
    private static func date(onDay day: Date, time: DateComponents, calendar: Calendar) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = time.hour ?? 0
        components.minute = time.minute ?? 0
        components.second = time.second ?? 0
        return calendar.date(from: components)
    }

    /// 토·일을 제외한 평일인지. (Gregorian 기준 1 = 일요일, 7 = 토요일)
    private static func isWeekday(_ date: Date, calendar: Calendar) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday != 1 && weekday != 7
    }
}

private extension Double {
    /// 계산으로 얻은 건너뛰기 횟수를 Int 로 안전하게 옮긴다.
    var intValue: Int {
        guard isFinite else { return 0 }
        return Int(self)
    }
}

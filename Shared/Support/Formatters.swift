import Foundation

/// 앱 전체에서 재사용하는 포매터.
///
/// `DateFormatter` 생성은 비싸므로 화면에서 매번 만들지 않는다.
enum Formatters {
    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("j:mm")
        return formatter
    }()

    static let fullDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("yMMMMEEEEd")
        return formatter
    }()

    static let monthTitle: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter
    }()

    static let dayAndWeekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("MMMd EEE")
        return formatter
    }()

    /// "8월 15일 오전 9:12" — 마지막 갱신 시각 표시용.
    static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("MMMd j:mm")
        return formatter
    }()

    static func timeRange(_ start: Date, _ end: Date) -> String {
        let startText = time.string(from: start)
        guard end > start else { return startText }
        return "\(startText) – \(time.string(from: end))"
    }

    /// "2시간 30분 후" 형태의 남은 시간. 이미 지난 시각이면 nil.
    static func countdown(to date: Date, from now: Date = .now) -> String? {
        let interval = date.timeIntervalSince(now)
        guard interval > 0 else { return nil }

        let minutes = Int(interval / 60)
        if minutes < 1 { return "곧 시작" }
        if minutes < 60 { return "\(minutes)분 후" }

        let hours = minutes / 60
        let remainder = minutes % 60
        if hours < 24 {
            return remainder == 0 ? "\(hours)시간 후" : "\(hours)시간 \(remainder)분 후"
        }
        let days = hours / 24
        return "\(days)일 후"
    }
}

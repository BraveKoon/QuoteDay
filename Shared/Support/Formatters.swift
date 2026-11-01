import Foundation

/// 앱 전체에서 재사용하는 포매터.
///
/// `DateFormatter` 생성은 비싸므로 화면에서 매번 만들지 않는다. 대신 **언어별로
/// 한 벌씩** 만들어 두고, `Localization.language` 가 바뀌면 다른 벌을 꺼낸다.
/// (설정에서 언어를 바꿨을 때 날짜 표기가 예전 언어로 남지 않게 하기 위해서다.)
enum Formatters {

    private static let lock = NSLock()
    private static var cache: [String: DateFormatter] = [:]

    private static func formatter(_ template: String, name: String) -> DateFormatter {
        let language = Localization.language
        let key = "\(name)|\(language.rawValue)"
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[key] { return cached }
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.setLocalizedDateFormatFromTemplate(template)
        cache[key] = formatter
        return formatter
    }

    static var time: DateFormatter { formatter("j:mm", name: "time") }

    static var fullDate: DateFormatter { formatter("yMMMMEEEEd", name: "fullDate") }

    static var monthTitle: DateFormatter { formatter("yMMMM", name: "monthTitle") }

    static var dayAndWeekday: DateFormatter { formatter("MMMd EEE", name: "dayAndWeekday") }

    /// "8월 15일 오전 9:12" — 마지막 갱신 시각 표시용.
    static var shortDateTime: DateFormatter { formatter("MMMd j:mm", name: "shortDateTime") }

    /// 파일 이름에 넣는 "20260904-1530". 로캘과 무관하게 같은 모양이어야 한다.
    static let fileStamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return formatter
    }()

    /// 월 이름만 ("8월" / "August" / "八月").
    static var monthName: DateFormatter { formatter("MMMM", name: "monthName") }

    /// 요일 이름 ("화요일" / "Tuesday" / "星期二").
    static var weekdayName: DateFormatter { formatter("EEEE", name: "weekdayName") }

    /// 릴리스 날짜 ("2026년 9월 9일" / "September 9, 2026").
    static var releaseDateFormatter: DateFormatter { formatter("yMMMMd", name: "releaseDate") }

    /// 문자열로 저장된 날짜(`"2026-09-09"`)를 앱 언어로 적는다. 해석 실패면 nil.
    static func releaseDate(_ date: String) -> String? {
        let parts = date.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3,
              let value = Calendar(identifier: .gregorian).date(
                  from: DateComponents(year: parts[0], month: parts[1], day: parts[2])
              )
        else { return nil }
        return releaseDateFormatter.string(from: value)
    }

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
        if minutes < 1 { return L("곧 시작") }
        if minutes < 60 { return L("%d분 후", minutes) }

        let hours = minutes / 60
        let remainder = minutes % 60
        if hours < 24 {
            return remainder == 0 ? L("%d시간 후", hours) : L("%d시간 %d분 후", hours, remainder)
        }
        let days = hours / 24
        return L("%d일 후", days)
    }
}

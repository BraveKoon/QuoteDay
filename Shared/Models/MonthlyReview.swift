import Foundation

/// 한 달치 기록을 되돌아보는 값.
///
/// 기록의 **대가**다. 이것이 없으면 기록은 그냥 숙제다. 매달 도착해서
/// "이번 달의 나"를 보여 주고, 이 앱에서 30일을 넘긴 사람에게만 보인다.
///
/// 순수 값 타입으로 두는 이유는 집계가 틀리기 쉬워서다 — 빈 달, 하루만 쓴 달,
/// 달의 경계에 걸친 글. 화면 없이 돌려 볼 수 있어야 한다.
public struct MonthlyReview: Equatable, Sendable {
    /// 이 회고가 다루는 달의 첫날.
    public let month: Date
    /// 글을 남긴 날 수. 글 편수가 아니다 — 하루에 세 편을 써도 하루다.
    public let recordedDays: Int
    public let noteCount: Int
    /// 이번 달 가장 자주 만난 인물.
    public let topAuthor: String?
    /// 이번 달 가장 많이 읽은 카테고리.
    public let topCategory: AppCategory?
    /// 이번 달 가장 많이 고른 기분.
    public let topMood: String?
    /// 가장 긴 글. 그달 마음이 가장 많이 움직였던 날이다.
    public let longestNote: ArchivedNote?
    public let firstNote: ArchivedNote?
    public let lastNote: ArchivedNote?

    /// 회고를 열려면 적어도 이만큼은 있어야 한다.
    ///
    /// **빈 회고는 안 만드는 것만 못하다.** 한 편 가지고 "이번 달의 나"를
    /// 보여 주면 그 화면이 사용자를 민망하게 만든다.
    public static let minimumNotes = 3

    public var isWorthShowing: Bool { noteCount >= Self.minimumNotes }

    public init(
        month: Date,
        recordedDays: Int,
        noteCount: Int,
        topAuthor: String?,
        topCategory: AppCategory?,
        topMood: String?,
        longestNote: ArchivedNote?,
        firstNote: ArchivedNote?,
        lastNote: ArchivedNote?
    ) {
        self.month = month
        self.recordedDays = recordedDays
        self.noteCount = noteCount
        self.topAuthor = topAuthor
        self.topCategory = topCategory
        self.topMood = topMood
        self.longestNote = longestNote
        self.firstNote = firstNote
        self.lastNote = lastNote
    }
}

public extension MonthlyReview {

    /// 한 달치 기록을 모아 회고를 만든다.
    ///
    /// - Parameters:
    ///   - notes: 기록 전부. 이 함수가 그달 것만 골라낸다.
    ///   - month: 그 달 안의 아무 날.
    ///   - categoryForSlug: 명언의 카테고리를 찾아 주는 함수. 주입받는 이유는
    ///     이 타입이 명언 라이브러리를 몰라도 테스트할 수 있어야 하기 때문이다.
    static func make(
        from notes: [ArchivedNote],
        month: Date,
        calendar: Calendar = .current,
        categoryForSlug: (String) -> AppCategory? = { _ in nil }
    ) -> MonthlyReview {
        let start = startOfMonth(month, calendar: calendar)
        let inMonth = notes
            .filter { note in
                guard let day = Date.fromDayKey(note.dayKey, calendar: calendar) else { return false }
                return calendar.isDate(day, equalTo: start, toGranularity: .month)
            }
            .sorted { $0.dayKey < $1.dayKey }

        return MonthlyReview(
            month: start,
            recordedDays: Set(inMonth.map(\.dayKey)).count,
            noteCount: inMonth.count,
            topAuthor: mostCommon(inMonth.map(\.authorName)),
            // AppCategory 는 Comparable 이 아니다. rawValue 로 세고 되돌린다.
            topCategory: mostCommon(inMonth.compactMap { categoryForSlug($0.quoteSlug)?.rawValue })
                .flatMap(AppCategory.init(rawValue:)),
            topMood: mostCommon(inMonth.compactMap(\.mood)),
            // 글자 수로 센다. 줄바꿈이 많은 글이 이기면 안 된다.
            longestNote: inMonth.max { trimmedCount($0.text) < trimmedCount($1.text) },
            firstNote: inMonth.first,
            lastNote: inMonth.last
        )
    }

    /// 지난달. 매월 1일에 보여 줄 대상이다.
    static func previousMonth(from date: Date = .now, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .month, value: -1, to: startOfMonth(date, calendar: calendar))
            ?? date
    }

    static func startOfMonth(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    /// "이번 달, 12일 동안 18편을 남겼어요"
    var headline: String {
        "\(recordedDays)일 동안 \(noteCount)편을 남겼어요"
    }

    // MARK: - 셈

    private static func trimmedCount(_ text: String) -> Int {
        text.trimmingCharacters(in: .whitespacesAndNewlines).count
    }

    /// 가장 자주 나온 값. 같은 수가 여럿이면 nil 이 아니라 **하나를 고른다** —
    /// 사전 순으로 앞선 것. 돌릴 때마다 답이 달라지면 회고가 아니다.
    private static func mostCommon<T: Hashable & Comparable>(_ values: [T]) -> T? {
        guard !values.isEmpty else { return nil }
        let counts = values.reduce(into: [T: Int]()) { $0[$1, default: 0] += 1 }
        return counts
            .sorted { left, right in
                left.value == right.value ? left.key < right.key : left.value > right.value
            }
            .first?
            .key
    }
}

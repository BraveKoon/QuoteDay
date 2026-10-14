import Foundation

/// 기록을 **날짜로** 들여다보는 질의들.
///
/// `NoteStore` 가 읽고 쓰는 일을 한다면, 여기는 "언제의 글인가"를 묻는 곳이다.
/// 순수 함수 중심으로 두어 저장소 없이 돌려 볼 수 있게 한다.
enum JournalRepository {

    /// "그때의 나" 후보를 찾는 간격. 먼 쪽부터 본다.
    ///
    /// 1년 전 글이 1개월 전 글보다 훨씬 크게 와닿는다. 가까운 것부터 찾으면
    /// 먼 글은 영영 안 보인다.
    static let throwbackMonths = [12, 6, 3, 1]

    /// 오늘 보여 줄 "그때의 나".
    ///
    /// **없으면 nil 을 준다. 빈 카드로 자리를 채우지 않는다.** 아무것도 없는
    /// 상자를 매일 보여 주면 화면만 길어지고 아무 말도 하지 않는다.
    static func throwback(
        in notes: [ArchivedNote],
        on date: Date = .now,
        calendar: Calendar = .current
    ) -> Throwback? {
        let today = date.dayKey(calendar: calendar)

        for months in throwbackMonths {
            guard
                let past = calendar.date(byAdding: .month, value: -months, to: date)
            else { continue }
            let key = past.dayKey(calendar: calendar)
            // 오늘 쓴 글이 "그때의 나"로 올라오면 안 된다.
            guard key != today else { continue }
            if let note = notes.first(where: { $0.dayKey == key }) {
                return Throwback(note: note, monthsAgo: months)
            }
        }

        // 딱 맞는 날이 없으면 가장 오래된 글을 하나 보여 준다. 다만 **한 달은
        // 지난 것**이어야 한다. 어제 쓴 글을 "그때의 나"라고 부르면 우습다.
        guard
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: date)
        else { return nil }
        let cutoff = monthAgo.dayKey(calendar: calendar)
        guard let oldest = notes.filter({ $0.dayKey <= cutoff }).min(by: { $0.dayKey < $1.dayKey })
        else { return nil }

        let months = calendar.dateComponents(
            [.month],
            from: Date.fromDayKey(oldest.dayKey, calendar: calendar) ?? date,
            to: date
        ).month ?? 1
        return Throwback(note: oldest, monthsAgo: max(months, 1))
    }

    /// 되돌아볼 수 있는 달 목록. 최근 달이 앞에 온다.
    static func reviewableMonths(
        in notes: [ArchivedNote],
        calendar: Calendar = .current
    ) -> [Date] {
        let months = notes.compactMap { note -> Date? in
            guard let day = Date.fromDayKey(note.dayKey, calendar: calendar) else { return nil }
            return MonthlyReview.startOfMonth(day, calendar: calendar)
        }
        return Array(Set(months)).sorted(by: >)
    }
}

/// 과거의 한 편과, 얼마나 지났는지.
struct Throwback: Equatable {
    let note: ArchivedNote
    let monthsAgo: Int

    /// "1년 전 오늘, 당신은 이렇게 적었어요"
    var headline: String {
        if monthsAgo >= 12 {
            let years = monthsAgo / 12
            return "\(years)년 전 오늘, 이렇게 적었어요"
        }
        return "\(monthsAgo)개월 전 오늘, 이렇게 적었어요"
    }
}

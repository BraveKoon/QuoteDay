import Foundation

/// 랭킹 시즌. **1·4·7·10월 1일**에 새로 시작한다.
///
/// ## 왜 리셋하는가
///
/// 랭킹 점수는 모드·단계마다의 **최고 기록**을 더한 값이다. 리셋이 없으면
/// 한 번 올려 둔 점수가 영원히 남아서, 먼저 시작한 사람이 계속 위에 있고
/// 나중에 온 사람은 따라잡을 길이 없다. 석 달마다 모두가 0 에서 다시 시작한다.
///
/// ## 무엇이 리셋되고 무엇이 남는가
///
///     리셋된다   이번 시즌 기록(랭킹 점수의 근거), 서버의 점수·분포 레코드
///     남는다     통산 기록 — 지금까지의 최고 점수와 푼 판 수
///
/// 사람이 쌓아 온 것을 지우지는 않는다. 경쟁만 다시 시작한다.
///
/// ## 서버에서
///
/// 레코드 이름에 시즌을 넣는다. 그래서 새 시즌이 시작되면 **읽는 곳이
/// 통째로 바뀐다** — 지우는 작업도, 옮기는 작업도 필요 없다.
///
///     ChallengePlayerScore   "score|2026Q1|<사용자 레코드 이름>"
///     ChallengeRankBucket    "rank-bucket|2026Q1|<구간 번호>"
///
/// 지난 시즌 레코드는 그대로 남지만 아무도 읽지 않는다.
public struct RankSeason: Hashable, Sendable {
    public let year: Int
    /// 1 부터 4 까지.
    public let quarter: Int

    public init(year: Int, quarter: Int) {
        self.year = year
        self.quarter = min(4, max(1, quarter))
    }

    /// 시즌 하나의 길이(개월).
    public static let months = 3

    /// 지금 진행 중인 시즌.
    public static func current(_ date: Date = .now, calendar: Calendar = .current) -> RankSeason {
        let parts = calendar.dateComponents([.year, .month], from: date)
        let year = parts.year ?? 1
        let month = parts.month ?? 1
        return RankSeason(year: year, quarter: (month - 1) / months + 1)
    }

    /// 저장과 레코드 이름에 쓰는 값. 사람이 읽어도 알아볼 수 있게 둔다.
    public var id: String { "\(year)Q\(quarter)" }

    /// 화면에 쓰는 이름.
    public var title: String { "\(year)년 \(quarter)분기" }

    /// 이 시즌이 시작한 달(1·4·7·10).
    public var startMonth: Int { (quarter - 1) * Self.months + 1 }

    /// 이 시즌이 시작한 날의 0시.
    public func startDate(calendar: Calendar = .current) -> Date? {
        calendar.date(from: DateComponents(year: year, month: startMonth, day: 1))
    }

    /// 다음 시즌.
    public var next: RankSeason {
        quarter == 4 ? RankSeason(year: year + 1, quarter: 1) : RankSeason(year: year, quarter: quarter + 1)
    }

    /// 이 시즌이 끝나는 순간 = 다음 시즌이 시작하는 순간.
    public func endDate(calendar: Calendar = .current) -> Date? {
        next.startDate(calendar: calendar)
    }

    /// 리셋까지 남은 날. 오늘이 마지막 날이면 0 이다.
    public func daysRemaining(from date: Date = .now, calendar: Calendar = .current) -> Int {
        guard let end = endDate(calendar: calendar) else { return 0 }
        let today = calendar.startOfDay(for: date)
        let last = calendar.startOfDay(for: end)
        return max(0, calendar.dateComponents([.day], from: today, to: last).day ?? 0)
    }

    /// 리셋 안내 한 줄.
    public func resetNotice(from date: Date = .now, calendar: Calendar = .current) -> String {
        let start = next.startMonth
        switch daysRemaining(from: date, calendar: calendar) {
        case 0: return "곧 리셋돼요. \(start)월 1일에 처음부터 다시 시작합니다."
        case 1: return "내일 \(start)월 1일에 리셋돼요."
        case let days: return "\(start)월 1일에 리셋돼요. \(days)일 남았어요."
        }
    }
}

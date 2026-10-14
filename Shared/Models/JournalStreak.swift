import Foundation

/// 연속 기록.
///
/// 리텐션을 가장 크게 움직이는 장치이면서, **설계를 틀리면 역효과**가 나는
/// 장치이기도 하다. 스트릭이 끊긴 날이 그대로 이탈일이 되는 앱이 무수히 많다.
/// 그래서 여기에는 규칙이 셋 있다.
///
/// 하나. 기준은 "방문"이 아니라 "기록"이다. 방문 스트릭은 허수이고 사용자도 안다.
///
/// 둘. 매주 유예를 하나씩 준다. 하루 빠져도 끊기지 않는다. 이 하나가
/// "망했으니 그만"을 막는다.
///
/// 셋. **누적은 절대 줄지 않는다.** 실패를 보여 주지 않는 지표를 항상 하나 둔다.
/// "3일 연속이 끝났어요"가 아니라 "지금까지 12번 기록했어요"라고 말할 수 있어야 한다.
public struct JournalStreak: Codable, Equatable, Sendable {
    /// 지금 이어지고 있는 날 수.
    public var current: Int
    /// 가장 길었던 기록.
    public var longest: Int
    /// 기록을 남긴 날이 모두 며칠인지. **어떤 경우에도 줄지 않는다.**
    public var totalDays: Int
    /// 마지막으로 기록한 날(`yyyy-MM-dd`). 빈 문자열이면 아직 없다.
    public var lastRecordedDay: String
    /// 남은 유예.
    public var freezesLeft: Int
    /// 유예를 마지막으로 받은 주(`2026-W42`).
    public var lastFreezeWeek: String
    /// 마지막 기록이 유예를 써서 이어진 것인지. 안내 한 줄에 쓴다.
    public var usedFreezeOnLastRecord: Bool

    public static let maximumFreezes = 2

    public init(
        current: Int = 0,
        longest: Int = 0,
        totalDays: Int = 0,
        lastRecordedDay: String = "",
        freezesLeft: Int = 1,
        lastFreezeWeek: String = "",
        usedFreezeOnLastRecord: Bool = false
    ) {
        self.current = current
        self.longest = longest
        self.totalDays = totalDays
        self.lastRecordedDay = lastRecordedDay
        self.freezesLeft = freezesLeft
        self.lastFreezeWeek = lastFreezeWeek
        self.usedFreezeOnLastRecord = usedFreezeOnLastRecord
    }

    public var hasEverRecorded: Bool { totalDays > 0 }
}

/// 연속 기록을 셈하는 규칙. 전부 순수 함수다 — 날짜 경계는 버그가 가장 잘 나는
/// 자리라서, 화면이나 저장소 없이 돌려 볼 수 있어야 한다.
public enum JournalStreakRules {

    /// `2026-W42`. 유예를 주 단위로 주기 위한 열쇠.
    public static func weekKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return String(format: "%04d-W%02d", parts.yearForWeekOfYear ?? 0, parts.weekOfYear ?? 0)
    }

    /// 주가 바뀌었으면 유예를 하나 준다. 상한을 넘기지 않는다.
    ///
    /// 몇 주를 쉬었든 한 번에 하나만 준다. 밀린 만큼 몰아 주면 유예가 쌓여서
    /// 연속 기록이라는 말이 뜻을 잃는다.
    public static func granting(
        _ streak: JournalStreak,
        on date: Date,
        calendar: Calendar = .current
    ) -> JournalStreak {
        let week = weekKey(for: date, calendar: calendar)
        guard streak.lastFreezeWeek != week else { return streak }

        var updated = streak
        updated.lastFreezeWeek = week
        // 첫 실행에서는 주만 적어 두고 더 주지 않는다. 기본값으로 이미 하나 있다.
        if !streak.lastFreezeWeek.isEmpty {
            updated.freezesLeft = min(streak.freezesLeft + 1, JournalStreak.maximumFreezes)
        }
        return updated
    }

    /// 그날 기록을 남겼다고 알린다.
    ///
    /// 같은 날 두 번 불러도 한 번만 센다 — 하루에 글을 세 편 써도 하루다.
    public static func recording(
        _ streak: JournalStreak,
        on date: Date,
        calendar: Calendar = .current
    ) -> JournalStreak {
        var updated = granting(streak, on: date, calendar: calendar)
        let today = date.dayKey(calendar: calendar)

        guard updated.lastRecordedDay != today else { return updated }

        let gap = daysBetween(updated.lastRecordedDay, and: today, calendar: calendar)

        switch gap {
        case .some(1):
            updated.current += 1
            updated.usedFreezeOnLastRecord = false
        case .some(let missed) where missed > 1:
            // 빠진 날은 `missed - 1` 일이다. 유예가 그만큼 있으면 이어 간다.
            let skipped = missed - 1
            if skipped <= updated.freezesLeft {
                updated.freezesLeft -= skipped
                updated.current += 1
                updated.usedFreezeOnLastRecord = true
            } else {
                updated.current = 1
                updated.usedFreezeOnLastRecord = false
            }
        default:
            // 첫 기록이거나, 날짜를 거꾸로 되돌린 경우(기기 시계 조작).
            updated.current = max(updated.current, 1)
            if updated.lastRecordedDay.isEmpty { updated.current = 1 }
            updated.usedFreezeOnLastRecord = false
        }

        updated.totalDays += 1
        updated.longest = max(updated.longest, updated.current)
        // 거꾸로 간 날짜로 마지막 기록일을 덮지 않는다. 덮으면 그 다음 날의
        // 간격이 엉켜서 멀쩡한 연속 기록이 끊긴다.
        if updated.lastRecordedDay.isEmpty || today > updated.lastRecordedDay {
            updated.lastRecordedDay = today
        }
        return updated
    }

    /// 오늘까지 보고 연속이 이미 끊겼는지 반영한다.
    ///
    /// 기록할 때만 셈하면, 사흘 쉬고 앱을 연 사람에게 화면이 여전히
    /// "5일째"라고 말한다. 보여 주기 전에 한 번 맞춘다.
    public static func settled(
        _ streak: JournalStreak,
        on date: Date,
        calendar: Calendar = .current
    ) -> JournalStreak {
        var updated = granting(streak, on: date, calendar: calendar)
        guard !updated.lastRecordedDay.isEmpty else { return updated }

        let today = date.dayKey(calendar: calendar)
        guard let gap = daysBetween(updated.lastRecordedDay, and: today, calendar: calendar),
              gap > 1
        else { return updated }

        // 아직 유예로 메울 수 있으면 끊긴 것이 아니다. 유예는 기록할 때 쓴다.
        if gap - 1 > updated.freezesLeft {
            updated.current = 0
            updated.usedFreezeOnLastRecord = false
        }
        return updated
    }

    /// `from` 에서 `to` 까지 며칠인지. 둘 중 하나가 비었거나 이상하면 nil.
    static func daysBetween(_ from: String, and to: String, calendar: Calendar) -> Int? {
        guard
            let start = Date.fromDayKey(from, calendar: calendar),
            let end = Date.fromDayKey(to, calendar: calendar)
        else { return nil }
        return calendar.dateComponents([.day], from: start, to: end).day
    }
}

public extension JournalStreak {
    /// 홈에 작게 들어가는 한 줄. **크게 쓰지 않는다** — 압박이 아니라 배경이어야 한다.
    var homeText: String {
        guard hasEverRecorded else { return "" }
        if current > 0 {
            return "\(current)일째 · 지금까지 \(totalDays)번"
        }
        // 끊겼을 때 "3일 연속이 끝났어요"라고 말하지 않는다. 줄지 않는 쪽을 보여 준다.
        return "지금까지 \(totalDays)번 기록했어요"
    }

    /// 유예를 써서 이어진 날에만 보여 주는 안내.
    var freezeNote: String? {
        guard usedFreezeOnLastRecord else { return nil }
        return "하루 쉬었지만 유예로 이어졌어요. 남은 유예 \(freezesLeft)개"
    }
}

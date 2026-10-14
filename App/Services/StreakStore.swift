import Foundation
import SwiftUI

/// 연속 기록을 담아 두는 곳.
///
/// SwiftData 가 아니라 `UserDefaults` 에 JSON 한 덩어리로 넣는다. `ChallengeStore`
/// 와 같은 이유다 — 저장할 것이 숫자 몇 개뿐인데 스키마를 늘리면 마이그레이션만
/// 떠안는다. 셈하는 규칙은 전부 `JournalStreakRules`(순수 함수)에 있고,
/// 이 타입은 읽고 쓰는 일만 한다.
@MainActor
@Observable
final class StreakStore {
    private(set) var streak: JournalStreak

    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = AppGroup.defaults, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
        self.streak = Self.load(from: defaults)
    }

    /// 화면에 보여 주기 전에 오늘 기준으로 맞춘다.
    ///
    /// 사흘 쉬고 앱을 연 사람에게 "5일째"라고 말하지 않기 위해서다.
    func refresh(on date: Date = .now) {
        let settled = JournalStreakRules.settled(streak, on: date, calendar: calendar)
        guard settled != streak else { return }
        streak = settled
        save()
    }

    /// 그날 기록을 남겼다. 같은 날 여러 번 불러도 하루로 센다.
    func recordEntry(on date: Date = .now) {
        let updated = JournalStreakRules.recording(streak, on: date, calendar: calendar)
        guard updated != streak else { return }
        streak = updated
        save()
    }

    /// 그날 기록이 모두 지워졌을 때 되돌린다.
    ///
    /// 되돌리는 것은 **오늘의 연속 기록뿐**이고 누적은 건드리지 않는다.
    /// 누적이 줄어드는 지표는 이 앱에 두지 않는다.
    func undoToday(on date: Date = .now) {
        let today = date.dayKey(calendar: calendar)
        guard streak.lastRecordedDay == today else { return }
        var updated = streak
        updated.current = max(updated.current - 1, 0)
        updated.lastRecordedDay = ""
        streak = updated
        save()
    }

    // MARK: - 저장

    private func save() {
        do {
            defaults.set(try JSONEncoder().encode(streak), forKey: SharedDefaultsKey.journalStreak)
        } catch {
            AppLog.notes.error("연속 기록 저장 실패: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func load(from defaults: UserDefaults) -> JournalStreak {
        guard
            let data = defaults.data(forKey: SharedDefaultsKey.journalStreak),
            let decoded = try? JSONDecoder().decode(JournalStreak.self, from: data)
        else { return JournalStreak() }
        return decoded
    }
}

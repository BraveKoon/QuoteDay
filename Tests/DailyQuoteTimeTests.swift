import XCTest
@testable import QuoteDay

/// 매일의 명언 알림 시각이 `DatePicker` 와 어긋나지 않는지 확인한다.
///
/// 설정의 시각은 시·분 두 숫자로 저장하는데 피커는 `Date` 를 주고받는다.
/// 그 사이를 잇는 다리가 값을 잃거나 이상한 날짜 위에 올려 두면, 피커가
/// 바꾼 값이 되돌아간다. 실제로 오전/오후만 바꾸면 되돌아가는 버그가 있었다.
@MainActor
final class DailyQuoteTimeTests: XCTestCase {

    private func makeSettings(name: String = #function) -> AppSettings {
        let suite = "test.dailyQuoteTime.\(name)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        return AppSettings(defaults: defaults)
    }

    /// 피커에 넘기는 `Date` 는 **오늘** 위에 있어야 한다.
    ///
    /// 예전에는 시·분만 담아 만들어서 서기 1년으로 떨어졌다. 그 시절에는
    /// 표준시가 없어 분 단위로 떨어지지 않는 지방 평균시를 쓰고, 그런 날짜
    /// 위에서는 피커의 오전/오후 전환이 흔들린다.
    func testPickerTimeSitsOnToday() {
        let settings = makeSettings()
        settings.dailyQuoteHour = 19
        settings.dailyQuoteMinute = 30

        let calendar = Calendar.current
        let expected = calendar.dateComponents([.year, .month, .day], from: .now)
        let actual = calendar.dateComponents([.year, .month, .day], from: settings.dailyQuoteTime)

        XCTAssertEqual(actual.year, expected.year, "피커 시각이 오늘이 아닌 날짜 위에 있습니다.")
        XCTAssertEqual(actual.month, expected.month)
        XCTAssertEqual(actual.day, expected.day)
    }

    /// 넣은 시각이 그대로 나와야 한다. 어긋나면 피커가 되돌아간다.
    func testEveryTimeOfDayRoundTrips() {
        let settings = makeSettings()
        let calendar = Calendar.current

        for hour in 0..<24 {
            for minute in [0, 1, 30, 59] {
                settings.dailyQuoteHour = hour
                settings.dailyQuoteMinute = minute

                let parts = calendar.dateComponents([.hour, .minute], from: settings.dailyQuoteTime)
                XCTAssertEqual(parts.hour, hour, "\(hour):\(minute) 의 시가 달라졌습니다.")
                XCTAssertEqual(parts.minute, minute, "\(hour):\(minute) 의 분이 달라졌습니다.")
            }
        }
    }

    /// 보고된 증상 그대로: 오후 7:30 에서 **오전/오후만** 바꾼다.
    ///
    /// 시나 분을 같이 건드리면 통과했기 때문에, 사용자는
    /// "오후 7:30 → 오후 6:30 → 오전 7:30" 으로 돌아가야 했다.
    func testSwitchingOnlyBetweenMorningAndAfternoonSticks() {
        let settings = makeSettings()
        settings.dailyQuoteHour = 19
        settings.dailyQuoteMinute = 30

        let calendar = Calendar.current
        // 피커가 오전으로 넘길 때 하는 일 — 열두 시간을 뺀다.
        let morning = settings.dailyQuoteTime.addingTimeInterval(-12 * 60 * 60)
        settings.dailyQuoteTime = morning

        XCTAssertEqual(settings.dailyQuoteHour, 7, "오전으로 바꾼 것이 저장되지 않았습니다.")
        XCTAssertEqual(settings.dailyQuoteMinute, 30)

        let readBack = calendar.dateComponents([.hour, .minute], from: settings.dailyQuoteTime)
        XCTAssertEqual(readBack.hour, 7, "저장은 됐지만 피커가 다시 오후를 보여 줍니다.")
        XCTAssertEqual(readBack.minute, 30)
    }

    /// 반대 방향도 본다.
    func testSwitchingFromMorningToAfternoonSticks() {
        let settings = makeSettings()
        settings.dailyQuoteHour = 7
        settings.dailyQuoteMinute = 30

        let afternoon = settings.dailyQuoteTime.addingTimeInterval(12 * 60 * 60)
        settings.dailyQuoteTime = afternoon

        XCTAssertEqual(settings.dailyQuoteHour, 19)
        XCTAssertEqual(settings.dailyQuoteMinute, 30)
    }

    /// 자정과 정오는 오전/오후가 뒤집히는 경계라 따로 본다.
    func testMidnightAndNoon() {
        let settings = makeSettings()
        let calendar = Calendar.current

        for (hour, expected) in [(0, 0), (12, 12)] {
            settings.dailyQuoteHour = hour
            settings.dailyQuoteMinute = 0
            let parts = calendar.dateComponents([.hour, .minute], from: settings.dailyQuoteTime)
            XCTAssertEqual(parts.hour, expected, "\(hour)시가 달라졌습니다.")
            XCTAssertEqual(parts.minute, 0)
        }
    }
}

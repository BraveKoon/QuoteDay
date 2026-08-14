import Foundation
import OSLog

/// 앱 타겟과 위젯 익스텐션이 공유하는 상수.
///
/// App Group 을 다른 이름으로 쓰려면 이 값과 두 개의 `.entitlements`,
/// 그리고 `project.yml` 의 값만 바꾸면 된다.
public enum AppGroup {
    public static let identifier = "group.com.quoteday.app"
    /// 홈 화면 위젯 (Small / Medium / Large).
    public static let widgetKind = "QuoteDayQuoteWidget"
    /// 잠금화면 · 대기 화면 위젯 (accessory 패밀리).
    public static let lockScreenWidgetKind = "QuoteDayLockScreenWidget"
    /// 일정이 바뀌었을 때 함께 갱신해야 하는 위젯 종류.
    public static let allWidgetKinds = [widgetKind, lockScreenWidgetKind]

    /// App Group 이 아직 프로비저닝되지 않았으면 `standard` 로 자연스럽게 내려간다.
    /// (개발 초기에 팀 설정 없이도 앱이 동작하도록.)
    public static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }

    public static var isConfigured: Bool {
        UserDefaults(suiteName: identifier) != nil
    }
}

public enum AppLog {
    public static let subsystem = "com.quoteday.app"
    public static let quotes = Logger(subsystem: subsystem, category: "quotes")
    public static let schedule = Logger(subsystem: subsystem, category: "schedule")
    public static let notifications = Logger(subsystem: subsystem, category: "notifications")
    public static let calendar = Logger(subsystem: subsystem, category: "calendar")
    public static let widget = Logger(subsystem: subsystem, category: "widget")
}

/// `UserDefaults` 에 저장되는 모든 키. 앱과 위젯이 같은 정의를 본다.
public enum SharedDefaultsKey {
    public static let widgetSnapshot = "widget.snapshot.v1"
    public static let dailyQuoteEnabled = "settings.dailyQuote.enabled"
    public static let dailyQuoteHour = "settings.dailyQuote.hour"
    public static let dailyQuoteMinute = "settings.dailyQuote.minute"
    public static let preferredCategory = "settings.preferredCategory"
    public static let appearance = "settings.appearance"
    public static let hasRequestedNotifications = "settings.hasRequestedNotifications"
    public static let mirrorToSystemCalendar = "settings.mirrorToSystemCalendar"
    public static let remoteQuoteEnabled = "settings.remoteQuote.enabled"
    public static let remoteQuote = "remoteQuote.cache.v1"
    public static let remoteQuoteLastAttempt = "remoteQuote.lastAttempt"
    public static let remoteQuoteLastError = "remoteQuote.lastError"
}

/// 위젯 스냅샷의 읽기/쓰기 담당.
///
/// 쓰기는 앱에서만, 읽기는 양쪽에서 한다. 실패해도 예외를 던지지 않고
/// 빈 스냅샷으로 대체한다 — 위젯은 어떤 경우에도 화면을 그려야 한다.
/// `UserDefaults` 는 스레드 안전하지만 SDK 에서 아직 `Sendable` 로 표시되어 있지 않아
/// `@unchecked` 로 명시한다.
public struct WidgetSnapshotStore: @unchecked Sendable {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
    }

    public func load() -> WidgetSnapshot {
        guard let data = defaults.data(forKey: SharedDefaultsKey.widgetSnapshot) else {
            return .empty
        }
        do {
            return try JSONDecoder.quoteDay.decode(WidgetSnapshot.self, from: data)
        } catch {
            AppLog.widget.error("스냅샷 디코딩 실패: \(error.localizedDescription, privacy: .public)")
            return .empty
        }
    }

    public func save(_ snapshot: WidgetSnapshot) {
        do {
            let data = try JSONEncoder.quoteDay.encode(snapshot)
            defaults.set(data, forKey: SharedDefaultsKey.widgetSnapshot)
        } catch {
            AppLog.widget.error("스냅샷 인코딩 실패: \(error.localizedDescription, privacy: .public)")
        }
    }
}

public extension JSONEncoder {
    static let quoteDay: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

public extension JSONDecoder {
    static let quoteDay: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

import SwiftUI

/// 사용자 설정. App Group `UserDefaults` 에 저장되어 위젯에서도 읽을 수 있다.
///
/// `@Observable` 은 `didSet` 같은 프로퍼티 옵저버와 함께 쓸 수 없으므로,
/// 저장이 필요한 값은 `@ObservationIgnored` 백업 저장소 + 계산 프로퍼티로 만들고
/// 관찰 등록(`access` / `withMutation`)을 직접 호출한다. Observation 프레임워크가
/// 계산 프로퍼티를 위해 공식적으로 안내하는 방식이다.
@MainActor
@Observable
final class AppSettings {
    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark

        var id: String { rawValue }

        var title: String {
            switch self {
            case .system: "시스템"
            case .light: "라이트"
            case .dark: "다크"
            }
        }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: nil
            case .light: .light
            case .dark: .dark
            }
        }
    }

    @ObservationIgnored private let defaults: UserDefaults

    @ObservationIgnored private var storedDailyQuoteEnabled: Bool
    @ObservationIgnored private var storedDailyQuoteHour: Int
    @ObservationIgnored private var storedDailyQuoteMinute: Int
    @ObservationIgnored private var storedPreferredCategory: AppCategory?
    @ObservationIgnored private var storedAppearance: Appearance
    @ObservationIgnored private var storedMirrorsToSystemCalendar: Bool
    @ObservationIgnored private var storedUsesRemoteQuote: Bool
    @ObservationIgnored private var storedTranslatesRemoteQuote: Bool
    @ObservationIgnored private var storedShareCardTheme: String
    @ObservationIgnored private var storedShareCardColor: String?

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
        self.storedDailyQuoteEnabled = defaults.bool(forKey: SharedDefaultsKey.dailyQuoteEnabled)
        // `integer(forKey:)` 는 값이 없을 때 0을 주므로 object 로 존재 여부를 확인한다.
        self.storedDailyQuoteHour = defaults.object(forKey: SharedDefaultsKey.dailyQuoteHour) as? Int ?? 8
        self.storedDailyQuoteMinute = defaults.object(forKey: SharedDefaultsKey.dailyQuoteMinute) as? Int ?? 0
        self.storedPreferredCategory = defaults.string(forKey: SharedDefaultsKey.preferredCategory)
            .flatMap(AppCategory.init(rawValue:))
        self.storedAppearance = Appearance(rawValue: defaults.string(forKey: SharedDefaultsKey.appearance) ?? "")
            ?? .system
        self.storedMirrorsToSystemCalendar = defaults.bool(forKey: SharedDefaultsKey.mirrorToSystemCalendar)
        // 값이 없으면 켜 둔 상태로 시작한다.
        self.storedUsesRemoteQuote = defaults.object(forKey: SharedDefaultsKey.remoteQuoteEnabled) as? Bool ?? true
        self.storedTranslatesRemoteQuote =
            defaults.object(forKey: SharedDefaultsKey.remoteQuoteTranslate) as? Bool ?? true
        self.storedShareCardTheme = defaults.string(forKey: SharedDefaultsKey.shareCardTheme) ?? ShareCardTheme.paper.rawValue
        self.storedShareCardColor = defaults.string(forKey: SharedDefaultsKey.shareCardColor)
    }

    /// 공유 카드에서 마지막으로 고른 배경색. nil 이면 카드가 QuoteDay 보라로 시작한다.
    /// 값은 검증하지 않는다 — 읽는 쪽에서 `Color(hexString:)` 이 nil 로 떨어뜨린다.
    var shareCardColorHex: String? {
        get {
            access(keyPath: \.shareCardColorHex)
            return storedShareCardColor
        }
        set {
            withMutation(keyPath: \.shareCardColorHex) {
                storedShareCardColor = newValue
                if let newValue {
                    defaults.set(newValue, forKey: SharedDefaultsKey.shareCardColor)
                } else {
                    defaults.removeObject(forKey: SharedDefaultsKey.shareCardColor)
                }
            }
        }
    }

    /// 공유 카드에서 마지막으로 고른 테마의 `rawValue`.
    /// 값 자체는 검증하지 않는다 — 읽는 쪽에서 `ShareCardTheme(storedValue:)` 로 떨어뜨린다.
    var shareCardTheme: String {
        get {
            access(keyPath: \.shareCardTheme)
            return storedShareCardTheme
        }
        set {
            withMutation(keyPath: \.shareCardTheme) {
                storedShareCardTheme = newValue
                defaults.set(newValue, forKey: SharedDefaultsKey.shareCardTheme)
            }
        }
    }

    var isDailyQuoteEnabled: Bool {
        get {
            access(keyPath: \.isDailyQuoteEnabled)
            return storedDailyQuoteEnabled
        }
        set {
            withMutation(keyPath: \.isDailyQuoteEnabled) {
                storedDailyQuoteEnabled = newValue
                defaults.set(newValue, forKey: SharedDefaultsKey.dailyQuoteEnabled)
            }
        }
    }

    var dailyQuoteHour: Int {
        get {
            access(keyPath: \.dailyQuoteHour)
            return storedDailyQuoteHour
        }
        set {
            let clamped = min(max(newValue, 0), 23)
            withMutation(keyPath: \.dailyQuoteHour) {
                storedDailyQuoteHour = clamped
                defaults.set(clamped, forKey: SharedDefaultsKey.dailyQuoteHour)
            }
        }
    }

    var dailyQuoteMinute: Int {
        get {
            access(keyPath: \.dailyQuoteMinute)
            return storedDailyQuoteMinute
        }
        set {
            let clamped = min(max(newValue, 0), 59)
            withMutation(keyPath: \.dailyQuoteMinute) {
                storedDailyQuoteMinute = clamped
                defaults.set(clamped, forKey: SharedDefaultsKey.dailyQuoteMinute)
            }
        }
    }

    /// 오늘의 명언을 특정 카테고리에서만 뽑고 싶을 때. nil 이면 전체에서 고른다.
    var preferredCategory: AppCategory? {
        get {
            access(keyPath: \.preferredCategory)
            return storedPreferredCategory
        }
        set {
            withMutation(keyPath: \.preferredCategory) {
                storedPreferredCategory = newValue
                if let newValue {
                    defaults.set(newValue.rawValue, forKey: SharedDefaultsKey.preferredCategory)
                } else {
                    defaults.removeObject(forKey: SharedDefaultsKey.preferredCategory)
                }
            }
        }
    }

    var appearance: Appearance {
        get {
            access(keyPath: \.appearance)
            return storedAppearance
        }
        set {
            withMutation(keyPath: \.appearance) {
                storedAppearance = newValue
                defaults.set(newValue.rawValue, forKey: SharedDefaultsKey.appearance)
            }
        }
    }

    /// 새 일정을 iOS 기본 캘린더에도 추가할지.
    var mirrorsToSystemCalendar: Bool {
        get {
            access(keyPath: \.mirrorsToSystemCalendar)
            return storedMirrorsToSystemCalendar
        }
        set {
            withMutation(keyPath: \.mirrorsToSystemCalendar) {
                storedMirrorsToSystemCalendar = newValue
                defaults.set(newValue, forKey: SharedDefaultsKey.mirrorToSystemCalendar)
            }
        }
    }

    /// 오늘의 명언을 ZenQuotes `/today` 에서 받아올지.
    ///
    /// 위젯도 App Group 을 통해 같은 값을 읽는다. 꺼 두면 앱은 완전히
    /// 오프라인으로 동작하며 내장 명언만 사용한다.
    var usesRemoteQuoteOfTheDay: Bool {
        get {
            access(keyPath: \.usesRemoteQuoteOfTheDay)
            return storedUsesRemoteQuote
        }
        set {
            withMutation(keyPath: \.usesRemoteQuoteOfTheDay) {
                storedUsesRemoteQuote = newValue
                defaults.set(newValue, forKey: SharedDefaultsKey.remoteQuoteEnabled)
            }
        }
    }

    /// 영어로 오는 오늘의 명언을 기기에서 한국어로 옮길지.
    ///
    /// 기계 번역이라 잠언은 어색해질 수 있어서 끌 수 있게 두었다.
    /// 켜 두어도 영어 원문은 번역문 아래에 그대로 남는다.
    var translatesRemoteQuote: Bool {
        get {
            access(keyPath: \.translatesRemoteQuote)
            return storedTranslatesRemoteQuote
        }
        set {
            withMutation(keyPath: \.translatesRemoteQuote) {
                storedTranslatesRemoteQuote = newValue
                defaults.set(newValue, forKey: SharedDefaultsKey.remoteQuoteTranslate)
            }
        }
    }

    /// 매일의 명언 알림 시각을 `DatePicker` 와 주고받기 위한 브리지.
    var dailyQuoteTime: Date {
        get {
            var components = DateComponents()
            components.hour = dailyQuoteHour
            components.minute = dailyQuoteMinute
            return Calendar.current.date(from: components) ?? Date.now
        }
        set {
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            dailyQuoteHour = components.hour ?? 8
            dailyQuoteMinute = components.minute ?? 0
        }
    }
}

import Foundation

/// 앱·위젯이 함께 쓰는 문구 사전.
///
/// 두 종류의 문자열을 같은 `Localizable.strings` 에서 찾는다.
///
/// 1. **화면 문구** — `Text("설정")` 처럼 소스에 박힌 한국어가 곧 키다.
///    SwiftUI 가 루트의 `\.locale` 을 보고 `en.lproj` / `zh-Hans.lproj` / `zh-Hant.lproj` 에서
///    같은 키를 찾아 준다. 그래서 뷰 코드는 한국어 그대로 두면 된다.
/// 2. **데이터 문구** — 명언 본문, 인물 소개처럼 모델에서 꺼내는 글.
///    `Text(String)` 은 번역되지 않으므로 `L(...)` 이 직접 찾아 준다.
///
/// 사전에 없는 키는 **한국어 원문을 그대로** 돌려준다. 번역이 빠진 항목이
/// 있어도 화면이 비거나 키 이름이 드러나지 않는다.
public enum Localization {

    /// 번역 사전이 들어 있는 `.lproj` 이름. (한국어는 원본이라 파일이 없다.)
    static let tableName = "Localizable"

    private static let lock = NSLock()
    private static var storedLanguage: AppLanguage = .korean
    private static var bundleCache: [AppLanguage: Bundle?] = [:]

    // MARK: - 현재 언어

    /// 지금 앱이 그리는 언어.
    ///
    /// 앱은 `AppSettings` 가, 위젯은 타임라인을 만들 때 `activate(_:)` 로 맞춘다.
    public static var language: AppLanguage {
        lock.lock()
        defer { lock.unlock() }
        return storedLanguage
    }

    /// 그리는 언어를 바꾼다. 화면을 다시 그리는 일은 부르는 쪽이 한다.
    public static func activate(_ language: AppLanguage) {
        lock.lock()
        storedLanguage = language
        lock.unlock()
    }

    /// 저장된 언어를 읽어 바로 적용한다. (위젯처럼 앱 상태가 없는 곳에서 쓴다.)
    @discardableResult
    public static func activateStored(in defaults: UserDefaults = AppGroup.defaults) -> AppLanguage {
        let language = AppLanguage.stored(in: defaults)
        activate(language)
        return language
    }

    // MARK: - 조회

    /// 키에 해당하는 문구. 없으면 키(=한국어 원문)를 그대로 돌려준다.
    public static func string(_ key: String, language: AppLanguage? = nil) -> String {
        let language = language ?? self.language
        guard let bundle = bundle(for: language) else { return key }
        return bundle.localizedString(forKey: key, value: key, table: tableName)
    }

    /// 번역이 준비되어 있는지. (값이 키와 같으면 없는 것으로 본다.)
    public static func hasTranslation(_ key: String, language: AppLanguage? = nil) -> Bool {
        let language = language ?? self.language
        guard language.usesTranslationTable else { return true }
        guard let bundle = bundle(for: language) else { return false }
        let value = bundle.localizedString(forKey: key, value: key, table: tableName)
        return value != key
    }

    /// 서식 있는 문구. 사전 값에 `%d` 같은 자리표시자를 넣어 둔다.
    ///
    /// 번역이 없으면 키(=한국어 원문)로 서식을 맞춘다.
    public static func format(_ key: String, language: AppLanguage? = nil, arguments: [CVarArg]) -> String {
        let pattern = string(key, language: language)
        guard !arguments.isEmpty else { return pattern }
        return String(format: pattern, arguments: arguments)
    }

    // MARK: - 번들

    /// 언어별 `.lproj` 번들. 없으면 nil 이고, 그러면 한국어 원문이 쓰인다.
    static func bundle(for language: AppLanguage) -> Bundle? {
        guard language.usesTranslationTable else { return nil }

        lock.lock()
        if let cached = bundleCache[language] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let bundle = loadBundle(for: language)

        lock.lock()
        bundleCache[language] = bundle
        lock.unlock()
        return bundle
    }

    private static func loadBundle(for language: AppLanguage) -> Bundle? {
        // 앱과 위젯은 각자의 번들이 주인공이다. 테스트에서는 호스트 앱 번들이 잡힌다.
        for candidate in [Bundle.main, Bundle(for: BundleToken.self)] {
            if let path = candidate.path(forResource: language.rawValue, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return nil
    }

    /// `Bundle(for:)` 에 넘길 클래스. (테스트·위젯에서 번들을 찾지 못할 때의 폴백)
    private final class BundleToken {}

    /// 테스트에서 언어를 되돌리기 위한 훅.
    static func resetForTesting() {
        activate(.korean)
        lock.lock()
        bundleCache.removeAll()
        lock.unlock()
    }
}

/// 화면 문구를 **문자열로** 꺼낼 때 쓰는 짧은 이름.
///
/// `Text(...)` 안의 문자열 리터럴은 SwiftUI 가 알아서 번역하므로 이 함수가
/// 필요 없다. 이 함수는 모델(카테고리 이름, 반복 규칙 요약 등)이나
/// `String` 을 받는 컴포넌트에 넘길 때 쓴다.
public func L(_ key: String) -> String {
    Localization.string(key)
}

/// 자리표시자가 있는 문구. 예: `L("%d분 후", minutes)`
public func L(_ key: String, _ arguments: CVarArg...) -> String {
    Localization.format(key, language: nil, arguments: arguments)
}

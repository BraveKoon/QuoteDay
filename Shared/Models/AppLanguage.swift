import Foundation

/// 앱 안에서 고르는 표시 언어.
///
/// 시스템 언어를 그대로 따르지 않고 **앱 안에서** 바꾼다. 값은 App Group
/// `UserDefaults` 에 저장되어 앱과 위젯이 같은 언어로 그려진다.
///
/// 언어를 바꾸면 재시작 없이 바로 반영된다. 화면 문구는 `.lproj` 의
/// `Localizable.strings` 를 SwiftUI 가 고르고(루트의 `\.locale`),
/// 명언·인물 같은 데이터는 `Localization` 이 직접 찾는다.
public enum AppLanguage: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case korean = "ko"
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"

    public var id: String { rawValue }

    /// 그 언어를 그 언어로 적은 이름. 언어를 고르는 화면에서 쓴다.
    /// (처음 보는 사람도 자기 언어를 찾을 수 있어야 한다.)
    public var nativeName: String {
        switch self {
        case .korean: "한국어"
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        }
    }

    /// 언어 선택 목록에서 이름 아래에 붙는 영문 표기.
    public var englishName: String {
        switch self {
        case .korean: "Korean"
        case .english: "English"
        case .simplifiedChinese: "Simplified Chinese"
        case .traditionalChinese: "Traditional Chinese"
        }
    }

    /// 날짜·숫자 포매터에 넘기는 로캘.
    public var locale: Locale { Locale(identifier: rawValue) }

    /// 언어를 나타내는 짧은 표식. 목록의 왼쪽 배지에 쓴다.
    public var badge: String {
        switch self {
        case .korean: "가"
        case .english: "A"
        case .simplifiedChinese: "简"
        case .traditionalChinese: "繁"
        }
    }

    /// 명언·인물 데이터가 번역되어 있는 언어인지.
    /// (한국어는 원본 데이터 자체라 번역 표를 찾지 않는다.)
    public var usesTranslationTable: Bool { self != .korean }

    // MARK: - 저장

    /// 기기에 저장된 언어. 없으면 시스템 언어에서 고른다.
    public static func stored(in defaults: UserDefaults = AppGroup.defaults) -> AppLanguage {
        if let raw = defaults.string(forKey: SharedDefaultsKey.language),
           let value = AppLanguage(rawValue: raw) {
            return value
        }
        return systemDefault
    }

    /// 시스템 언어가 영어·중국어면 그쪽으로 시작한다.
    ///
    /// 최초 실행에서 언어를 고르는 화면이 나오지만, 그 전에 이미 그려지는
    /// 화면(위젯 등)이 어색하지 않도록 여기서도 한 번 맞춘다.
    ///
    /// 테스트에서는 항상 한국어다. 테스트가 특정 문장을 그대로 비교하기
    /// 때문이고(예: 인물의 한국어 이름), 시뮬레이터 언어에 따라 결과가
    /// 달라지면 안 되기 때문이다.
    public static var systemDefault: AppLanguage {
        guard !isRunningTests else { return .korean }
        for identifier in Locale.preferredLanguages {
            let lowercased = identifier.lowercased()
            if lowercased.hasPrefix("zh") {
                // 번체를 쓰는 지역(대만·홍콩·마카오)만 번체로 시작한다.
                // 나머지 중국어권은 간체가 기본이다.
                let traditionalRegions = ["hant", "tw", "hk", "mo"]
                return traditionalRegions.contains(where: lowercased.contains)
                    ? .traditionalChinese
                    : .simplifiedChinese
            }
            if lowercased.hasPrefix("en") { return .english }
            if lowercased.hasPrefix("ko") { return .korean }
        }
        return .korean
    }

    /// 지금이 단위 테스트 실행 중인지. (`XCTestCase` 가 로드되어 있는지로 본다.)
    static var isRunningTests: Bool {
        NSClassFromString("XCTestCase") != nil
    }

    /// 저장된 값을 갱신한다. 없는 값이면 키를 지운다.
    public func store(in defaults: UserDefaults = AppGroup.defaults) {
        defaults.set(rawValue, forKey: SharedDefaultsKey.language)
    }
}

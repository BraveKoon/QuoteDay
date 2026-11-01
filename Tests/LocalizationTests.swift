import XCTest
@testable import QuoteDay

/// 언어 전환·번역 사전·첫 실행 안내(계정·닉네임) 검증.
///
/// 여기서 확인하는 핵심은 두 가지다.
///
/// 1. 설정에서 언어를 바꿨을 때 **화면 문구와 데이터(명언·인물)가 함께** 바뀌는지
/// 2. 번역이 빠진 문구가 있어도 화면이 비거나 키가 드러나지 않는지
///    (한국어 원문으로 자연스럽게 되돌아가야 한다)
@MainActor
final class LocalizationTests: XCTestCase {

    override func tearDown() {
        Localization.resetForTesting()
        super.tearDown()
    }

    private func makeDefaults(_ name: String = #function) -> UserDefaults {
        let suite = "test.localization.\(name)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    // MARK: - 사전

    /// 번역 파일이 실제로 번들에 들어 있는지.
    ///
    /// 이 검사가 없으면 `.lproj` 가 빌드에서 빠져도 아무 오류 없이 한국어만
    /// 보이게 된다 — 이번 기능에서 가장 조용히 실패할 수 있는 지점이다.
    func testTranslationBundlesAreInTheApp() {
        XCTAssertNotNil(Localization.bundle(for: .english), "en.lproj / Localizable.strings 가 번들에 없습니다.")
        XCTAssertNotNil(Localization.bundle(for: .simplifiedChinese), "zh-Hans.lproj / Localizable.strings 가 번들에 없습니다.")
        XCTAssertNotNil(Localization.bundle(for: .traditionalChinese), "zh-Hant.lproj / Localizable.strings 가 번들에 없습니다.")
    }

    func testKoreanFallsBackToTheSourceText() {
        Localization.activate(.korean)
        XCTAssertEqual(L("설정"), "설정")
        XCTAssertEqual(L("%d분 후", 3), "3분 후")
    }

    func testScreenTextIsTranslated() {
        Localization.activate(.english)
        XCTAssertEqual(L("설정"), "Settings")
        XCTAssertEqual(L("홈"), "Home")

        Localization.activate(.simplifiedChinese)
        XCTAssertEqual(L("설정"), "设置")
        XCTAssertEqual(L("홈"), "首页")

        Localization.activate(.traditionalChinese)
        XCTAssertEqual(L("설정"), "設定", "번체는 글자만 바뀌는 것이 아니라 대만 어휘를 따라야 합니다.")
        XCTAssertEqual(L("홈"), "首頁")
    }

    /// 사전에 없는 문구는 한국어 그대로. (키 이름이 화면에 드러나면 안 된다.)
    /// 번체 사전은 간체 사전에서 만들어지므로, 글자만 바뀌고 빠진 문구가 없어야 한다.
    func testTraditionalMirrorsSimplified() {
        Localization.activate(.traditionalChinese)
        XCTAssertEqual(L("%@ 돌아보기", "11月"), "回顧 11月")
        XCTAssertEqual(L("설정"), "設定")
        XCTAssertEqual(L("언어"), "語言")
    }

    func testUnknownTextStaysKorean() {
        Localization.activate(.english)
        let unknown = "이 문장은 일부러 사전에 넣지 않았다"
        XCTAssertEqual(L(unknown), unknown)
    }

    func testPlaceholdersSurviveTranslation() {
        Localization.activate(.english)
        XCTAssertEqual(L("카테고리 %@", "Work"), "Category: Work")
    }

    // MARK: - 데이터

    func testQuotesFollowTheLanguage() {
        Localization.activate(.english)
        let english = QuoteLibrary.shared.quote(slug: "jobs-love-what-you-do")
        XCTAssertNotNil(english)
        XCTAssertTrue(
            english?.text.lowercased().contains("love what you do") ?? false,
            "영어 명언이 번역되지 않았습니다: \(english?.text ?? "nil")"
        )

        Localization.activate(.simplifiedChinese)
        let chinese = QuoteLibrary.shared.quote(slug: "jobs-love-what-you-do")
        XCTAssertEqual(chinese?.text, "做出伟大工作的唯一方法，就是热爱你所做的事。")

        Localization.activate(.traditionalChinese)
        let traditional = QuoteLibrary.shared.quote(slug: "jobs-love-what-you-do")
        XCTAssertEqual(traditional?.text, "做出偉大工作的唯一方法，就是熱愛你所做的事。")

        Localization.activate(.korean)
        let korean = QuoteLibrary.shared.quote(slug: "jobs-love-what-you-do")
        XCTAssertTrue(korean?.text.contains("자신이 하는 일을 사랑") ?? false)
    }

    /// 언어가 바뀌어도 명언의 정체성(slug·id)은 그대로다.
    /// 하트·노트·딥링크가 언어와 무관하게 이어져야 한다.
    func testQuoteIdentityDoesNotChangeWithLanguage() {
        Localization.activate(.korean)
        let korean = QuoteLibrary.shared.quote(slug: "churchill-courage-to-continue")
        Localization.activate(.english)
        let english = QuoteLibrary.shared.quote(slug: "churchill-courage-to-continue")
        XCTAssertEqual(korean?.id, english?.id)
        XCTAssertEqual(korean?.authorID, english?.authorID)
        XCTAssertEqual(korean?.category, english?.category)
    }

    func testAuthorProfileFollowsTheLanguage() {
        Localization.activate(.korean)
        XCTAssertEqual(AuthorLibrary.author(id: "churchill").displayName, "윈스턴 처칠")

        Localization.activate(.english)
        XCTAssertEqual(AuthorLibrary.author(id: "churchill").displayName, "Winston Churchill")

        Localization.activate(.simplifiedChinese)
        XCTAssertEqual(AuthorLibrary.author(id: "churchill").displayName, "温斯顿·丘吉尔")

        Localization.activate(.traditionalChinese)
        // 번체는 OpenCC 가 간체에서 만든 값이다. `丘` 는 번체에서도 `丘` 로 남는다.
        XCTAssertEqual(AuthorLibrary.author(id: "churchill").displayName, "溫斯頓·丘吉爾")
    }

    /// 번역이 아직 없는 소개글은 한국어로 남는다. (화면이 비지 않는다)
    func testUntranslatedBiographyFallsBackToKorean() {
        Localization.activate(.english)
        XCTAssertFalse(AuthorLibrary.author(id: "churchill").biography.isEmpty)
    }

    /// 명언 목록 전체가 같은 언어로 나오는지 — 한 편씩 섞이면 목록이 어색해진다.
    ///
    /// 번역이 빠진 명언은 한국어 원문이 그대로 보인다. 그런 항목이 하나라도
    /// 있으면 영어·중국어 화면에 한국어 문장이 섞인다는 뜻이다.
    func testEveryQuoteIsTranslated() {
        for language in [AppLanguage.english, .simplifiedChinese, .traditionalChinese] {
            Localization.activate(language)
            let quotes = QuoteLibrary.shared.quotes
            XCTAssertEqual(quotes.count, QuoteSeed.all.count)

            let leftover = quotes.filter { quote in
                quote.text.range(of: "[가-힣]", options: .regularExpression) != nil
            }
            XCTAssertTrue(
                leftover.isEmpty,
                "\(language.rawValue) 번역이 없는 명언 \(leftover.count)편: \(leftover.prefix(3).map(\.slug))"
            )

            // 인물 이름·직업·국적도 같은 언어여야 한다.
            let authors = AuthorLibrary.all.filter { author in
                let localized = author.localized(in: language)
                return localized.name.range(of: "[가-힣]", options: .regularExpression) != nil
                    || localized.occupation.range(of: "[가-힣]", options: .regularExpression) != nil
                    || localized.nationality.range(of: "[가-힣]", options: .regularExpression) != nil
            }
            XCTAssertTrue(
                authors.isEmpty,
                "\(language.rawValue) 번역이 없는 인물 \(authors.count)명: \(authors.prefix(3).map(\.id))"
            )
        }
    }

    /// 인사말은 이름과 인사말을 이어 붙인 한 문장이다. 언어마다 어순이 달라서
    /// 문장을 통째로 번역한다. (영어는 "민지님, 좋은 아침이에요" 가 아니라
    /// "Minji, Good morning" 이어야 한다.)
    func testGreetingSentenceFollowsTheLanguage() {
        Localization.activate(.korean)
        XCTAssertEqual(L("%@님, %@", "민지", L("좋은 아침이에요")), "민지님, 좋은 아침이에요")

        Localization.activate(.english)
        XCTAssertEqual(L("%@님, %@", "Minji", L("좋은 아침이에요")), "Minji, Good morning")

        Localization.activate(.simplifiedChinese)
        XCTAssertEqual(L("%@님, %@", "敏智", L("좋은 아침이에요")), "敏智，早上好")
    }

    /// 반복 일정 요약의 요일 이름도 앱 언어를 따른다.
    /// (`Calendar` 의 기호를 그대로 쓰면 중국어 화면에 한국어 요일이 남는다.)
    func testRecurrenceSummaryFollowsTheLanguage() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        // 2026-11-03 은 화요일이다.
        let anchor = calendar.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: 9)) ?? .now
        let rule = RecurrenceRule(frequency: .weekly)

        Localization.activate(.korean)
        XCTAssertEqual(rule.summary(anchor: anchor, calendar: calendar), "매주 화요일")

        Localization.activate(.english)
        XCTAssertEqual(rule.summary(anchor: anchor, calendar: calendar), "Every week on Tuesday")

        Localization.activate(.simplifiedChinese)
        XCTAssertEqual(rule.summary(anchor: anchor, calendar: calendar), "每周 星期二")
    }

    // MARK: - 설정

    func testLanguageSettingIsPersistedAndApplied() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.language, .korean)

        settings.language = .simplifiedChinese
        XCTAssertEqual(AppLanguage.stored(in: defaults), .simplifiedChinese)
        XCTAssertEqual(Localization.language, .simplifiedChinese)
        XCTAssertEqual(settings.language.locale.identifier, "zh-Hans")

        // 저장된 값을 새로 읽어도 같은 언어여야 한다. (앱을 다시 켠 상황)
        let reopened = AppSettings(defaults: defaults)
        XCTAssertEqual(reopened.language, .simplifiedChinese)
        reopened.language = .korean
    }

    func testStoredLanguageFallsBackForUnknownValues() {
        let defaults = makeDefaults()
        defaults.set("이제는-없는-언어", forKey: SharedDefaultsKey.language)
        XCTAssertEqual(AppLanguage.stored(in: defaults), .korean)
    }
}

/// 첫 실행 안내에서 만드는 계정·닉네임 상태.
@MainActor
final class ProfileStoreTests: XCTestCase {

    private func makeDefaults(_ name: String = #function) -> UserDefaults {
        let suite = "test.profile.\(name)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    func testOnboardingStartsUnfinished() {
        let store = ProfileStore(defaults: makeDefaults())
        XCTAssertFalse(store.hasCompletedOnboarding)
        XCTAssertNil(store.provider)
        XCTAssertEqual(store.nickname, "")
    }

    func testGuestCanFinishWithNickname() {
        let defaults = makeDefaults()
        let store = ProfileStore(defaults: defaults)
        store.continueAsGuest()
        store.finishOnboarding(nickname: "  민지  ")

        XCTAssertEqual(store.provider, .guest)
        XCTAssertEqual(store.nickname, "민지", "앞뒤 공백은 지워야 합니다.")
        XCTAssertTrue(store.hasCompletedOnboarding)

        // 앱을 다시 켠 상황
        let reopened = ProfileStore(defaults: defaults)
        XCTAssertTrue(reopened.hasCompletedOnboarding)
        XCTAssertEqual(reopened.nickname, "민지")
        XCTAssertEqual(reopened.provider, .guest)
    }

    func testNicknameIsTrimmedAndLimited() {
        let store = ProfileStore(defaults: makeDefaults())
        store.nickname = String(repeating: "가", count: 40)
        XCTAssertEqual(store.nickname.count, ProfileStore.nicknameLimit)
        XCTAssertTrue(ProfileStore.isValid(nickname: "가"))
        XCTAssertFalse(ProfileStore.isValid(nickname: "   "))
        XCTAssertEqual(ProfileStore.cleaned("  가 나  "), "가 나")
    }

    func testAppleSignInIsRemembered() {
        let store = ProfileStore(defaults: makeDefaults())
        store.applyAppleCredential(AppleSignIn.Credential(
            userIdentifier: "001234.abcdef",
            displayName: "민지 김",
            email: "minji@example.com"
        ))
        XCTAssertTrue(store.isSignedInWithApple)
        XCTAssertEqual(store.appleUserIdentifier, "001234.abcdef")
        XCTAssertEqual(store.appleEmail, "minji@example.com")
        XCTAssertEqual(store.appleDisplayName, "민지 김")
    }

    /// 애플은 이름을 **최초 1회만** 준다. 두 번째 로그인에서 nil 이 와도
    /// 저장해 둔 이름을 지우면 안 된다.
    func testSecondAppleSignInKeepsTheStoredName() {
        let store = ProfileStore(defaults: makeDefaults())
        store.applyAppleCredential(AppleSignIn.Credential(
            userIdentifier: "001234.abcdef",
            displayName: "민지 김",
            email: "minji@example.com"
        ))
        store.applyAppleCredential(AppleSignIn.Credential(
            userIdentifier: "001234.abcdef",
            displayName: nil,
            email: nil
        ))
        XCTAssertEqual(store.appleDisplayName, "민지 김")
        XCTAssertEqual(store.appleEmail, "minji@example.com")
    }

    func testSignOutReturnsToTheWelcomeScreen() {
        let defaults = makeDefaults()
        let store = ProfileStore(defaults: defaults)
        store.continueAsGuest()
        store.finishOnboarding(nickname: "민지")
        store.signOut()

        XCTAssertFalse(store.hasCompletedOnboarding)
        XCTAssertNil(store.provider)
        XCTAssertEqual(store.nickname, "")

        let reopened = ProfileStore(defaults: defaults)
        XCTAssertFalse(reopened.hasCompletedOnboarding)
    }
}

/// 언어를 바꿨을 때 날짜 표기가 따라가는지.
@MainActor
final class FormatterLanguageTests: XCTestCase {

    override func tearDown() {
        Localization.resetForTesting()
        super.tearDown()
    }

    func testDateFormatterFollowsTheAppLanguage() {
        // 기준 시각을 고정한다. `.now` 를 두 번 읽으면 그 사이 흐른 시간만큼
        // 분이 깎여 "1시간 29분" 이 나온다 — 러너가 느리면 실패하는 테스트였다.
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let target = now.addingTimeInterval(60 * 90)

        Localization.activate(.korean)
        XCTAssertEqual(Formatters.countdown(to: target, from: now), "1시간 30분 후")

        Localization.activate(.english)
        XCTAssertEqual(Formatters.countdown(to: target, from: now), "in 1 hr 30 min")

        Localization.activate(.simplifiedChinese)
        XCTAssertEqual(Formatters.countdown(to: target, from: now), "1 小时 30 分钟后")

        Localization.activate(.traditionalChinese)
        XCTAssertEqual(Formatters.countdown(to: target, from: now), "1 小時 30 分鐘後")
    }

    func testFullDateUsesTheAppLanguage() {
        Localization.activate(.english)
        let english = Formatters.fullDate.string(from: Date(timeIntervalSince1970: 1_800_000_000))
        XCTAssertTrue(english.contains("2027") || english.contains("2026"), english)
        Localization.activate(.korean)
        let korean = Formatters.fullDate.string(from: Date(timeIntervalSince1970: 1_800_000_000))
        XCTAssertNotEqual(korean, english)
    }
}

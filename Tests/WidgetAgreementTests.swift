import XCTest
@testable import QuoteDay

/// 앱과 위젯이 **같은 문장**을 고르는지 확인한다.
///
/// 둘은 서로 다른 프로세스에서 각자 계산한다. 규칙이 한쪽에만 있으면 어긋나도
/// 아무 데서도 오류가 나지 않는다 — 홈 화면의 위젯과 앱을 열었을 때의 문장이
/// 조용히 달라질 뿐이다. 실제로 그렇게 어긋났고, 이 파일이 그것을 막는다.
final class WidgetAgreementTests: XCTestCase {

    private let service = QuoteService.shared
    private let date = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeRemoteStore(name: String = #function) -> RemoteQuoteStore {
        let suite = "test.widgetAgreement.remote.\(name)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        return RemoteQuoteStore(defaults: defaults)
    }

    private func makeSettingsDefaults(name: String = #function) -> UserDefaults {
        let suite = "test.widgetAgreement.settings.\(name)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    // MARK: - 카테고리 해석

    /// 위젯에서 따로 고르지 않았으면 앱 설정을 따른다.
    func testWidgetFollowsTheAppSettingWhenNothingIsChosen() {
        let defaults = makeSettingsDefaults()
        defaults.set(AppCategory.growth.rawValue, forKey: SharedDefaultsKey.preferredCategory)

        let resolved = DailyQuoteSelection.resolvedCategory(widgetChoice: nil, defaults: defaults)
        XCTAssertEqual(resolved, .growth)
    }

    /// 위젯에서 일부러 골랐으면 그쪽이 이긴다. "이 위젯만 다르게"가 가능해야 한다.
    func testWidgetChoiceWinsOverTheAppSetting() {
        let defaults = makeSettingsDefaults()
        defaults.set(AppCategory.growth.rawValue, forKey: SharedDefaultsKey.preferredCategory)

        let resolved = DailyQuoteSelection.resolvedCategory(widgetChoice: .meal, defaults: defaults)
        XCTAssertEqual(resolved, .meal)
    }

    func testNoSettingAnywhereMeansTheWholePool() {
        let defaults = makeSettingsDefaults()
        XCTAssertNil(DailyQuoteSelection.resolvedCategory(widgetChoice: nil, defaults: defaults))
    }

    /// 저장된 값이 깨졌거나 모르는 카테고리여도 죽지 않는다.
    func testBrokenStoredCategoryFallsBackToTheWholePool() {
        let defaults = makeSettingsDefaults()
        defaults.set("이제는-없는-카테고리", forKey: SharedDefaultsKey.preferredCategory)
        XCTAssertNil(DailyQuoteSelection.preferredCategory(defaults: defaults))
    }

    // MARK: - 카테고리와 원격 명언

    /// 카테고리를 고른 사람에게 원격 명언(카테고리가 없다)을 내보내면
    /// 고른 설정이 조용히 무시된다.
    func testChosenCategoryWinsOverTheRemoteQuote() {
        let remote = makeRemoteStore()
        remote.save(RemoteQuote(text: "From the API.", authorName: "Someone", dayKey: date.dayKey()))

        let presentation = service.todayPresentation(
            for: date,
            preferred: .exercise,
            useRemote: true,
            remote: remote
        )

        XCTAssertFalse(presentation.quote.isFromZenQuotes)
        XCTAssertEqual(
            presentation.quote.slug,
            service.quoteOfTheDay(for: date, preferred: .exercise).slug,
            "고른 카테고리가 지켜지지 않았습니다."
        )
    }

    /// 카테고리를 고르지 않았을 때는 예전처럼 원격 명언을 쓴다.
    func testRemoteQuoteIsStillUsedWithoutACategory() {
        let remote = makeRemoteStore()
        remote.save(RemoteQuote(text: "From the API.", authorName: "Someone", dayKey: date.dayKey()))

        let presentation = service.todayPresentation(
            for: date,
            preferred: nil,
            useRemote: true,
            remote: remote
        )
        XCTAssertEqual(presentation.quote.text, "From the API.")
    }

    // MARK: - 두 화면이 같은 문장인지

    /// 앱 화면과 위젯이 밟는 경로를 그대로 재현해 결과를 맞춰 본다.
    private func appQuote(
        preferred: AppCategory?,
        useRemote: Bool,
        remote: RemoteQuoteStore
    ) -> Quote {
        // App/ViewModels/HomeViewModel.quoteOfTheDay 와 같은 호출이다.
        service.todayPresentation(
            for: date,
            preferred: preferred,
            useRemote: useRemote,
            remote: remote
        ).quote
    }

    private func widgetQuote(
        widgetChoice: AppCategory?,
        settings: UserDefaults,
        useRemote: Bool,
        remote: RemoteQuoteStore
    ) -> Quote {
        // Widget/QuoteWidget.QuoteTimelineProvider.makeEntry 와 같은 호출이다.
        let category = DailyQuoteSelection.resolvedCategory(
            widgetChoice: widgetChoice,
            defaults: settings
        )
        return service.todayPresentation(
            for: date,
            preferred: category,
            useRemote: useRemote,
            remote: remote
        ).quote
    }

    func testAppAndWidgetAgreeForEveryPreferredCategory() {
        let categories: [AppCategory?] = [nil] + AppCategory.selectableForQuotes.map { Optional($0) }
        for category in categories {
            for useRemote in [true, false] {
                let remote = makeRemoteStore(name: "agree")
                remote.save(
                    RemoteQuote(text: "From the API.", authorName: "Someone", dayKey: date.dayKey())
                )
                let settings = makeSettingsDefaults(name: "agree")
                if let category {
                    settings.set(category.rawValue, forKey: SharedDefaultsKey.preferredCategory)
                }

                let app = appQuote(preferred: category, useRemote: useRemote, remote: remote)
                let widget = widgetQuote(
                    widgetChoice: nil,
                    settings: settings,
                    useRemote: useRemote,
                    remote: remote
                )

                XCTAssertEqual(
                    app.slug,
                    widget.slug,
                    "카테고리 \(category?.rawValue ?? "전체"), 원격 \(useRemote) 에서 앱과 위젯이 다른 명언을 보여 줍니다."
                )
            }
        }
    }

    /// 자정을 넘기면 두 곳 모두 새 문장으로 넘어가야 한다.
    func testAppAndWidgetAgreeAcrossMidnight() {
        let remote = makeRemoteStore()
        let settings = makeSettingsDefaults()
        let calendar = Calendar.current
        let today = date
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today

        for moment in [today, tomorrow] {
            let app = service.todayPresentation(
                for: moment,
                preferred: nil,
                useRemote: false,
                remote: remote
            ).quote
            let category = DailyQuoteSelection.resolvedCategory(widgetChoice: nil, defaults: settings)
            let widget = service.todayPresentation(
                for: moment,
                preferred: category,
                useRemote: false,
                remote: remote
            ).quote
            XCTAssertEqual(app.slug, widget.slug)
        }
    }
}

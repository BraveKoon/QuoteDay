import Foundation
import SwiftUI

/// 탭 선택과 딥링크 목적지를 관리한다.
///
/// 위젯 탭과 알림 탭은 모두 `DeepLink` 로 정규화된 뒤 이곳을 거쳐 화면으로 이어진다.
@MainActor
@Observable
final class AppRouter {
    enum Tab: String, CaseIterable, Identifiable {
        case home, calendar, quotes, challenge, settings

        var id: String { rawValue }

        /// 탭 이름. 지금 앱 언어로 찾는다.
        ///
        /// **다시 그려야 하는 뷰는 이것을 쓰지 말고 `title(in:)` 에 `settings.language` 를
        /// 넘긴다.** 이 값은 전역 `Localization.language` 를 읽을 뿐이라 SwiftUI 가 그
        /// 변화를 알지 못한다.
        var title: String { title(in: Localization.language) }

        /// 주어진 언어의 탭 이름.
        ///
        /// 언어를 **인자로** 받는 이유: 탭바가 `L("홈")` 처럼 전역 상태를 읽는 문자열을
        /// 그리면, 언어를 바꿔도 뷰가 자기 의존성을 모르니 다시 그려지지 않는다. 설정에서
        /// English 로 바꿔도 탭바는 한국어 그대로고, 탭을 눌러 선택이 바뀌어야 비로소
        /// 바뀌었다. 호출하는 뷰가 `settings.language` 를 넘기면 그 값을 관찰하게 된다.
        func title(in language: AppLanguage) -> String {
            switch self {
            case .home: L("홈", language: language)
            case .calendar: L("캘린더", language: language)
            case .quotes: L("명언", language: language)
            case .challenge: L("챌린지", language: language)
            case .settings: L("설정", language: language)
            }
        }

        var symbol: String {
            switch self {
            case .home: "house.fill"
            case .calendar: "calendar"
            case .quotes: "quote.bubble.fill"
            case .challenge: "trophy.fill"
            case .settings: "gearshape.fill"
            }
        }
    }

    var selectedTab: Tab = .home
    /// 전체 화면으로 띄울 명언 상세.
    var presentedQuoteID: UUID?
    /// 캘린더 탭에서 선택된 날짜.
    var selectedDate: Date = .now
    /// 캘린더 탭에서 열어 줄 일정.
    var highlightedScheduleID: UUID?
    /// 홈의 기록 입력칸을 펼친 채로 열어야 하는지. 홈 카드가 읽고 되돌린다.
    var wantsTodayCompose = false

    private let quoteService: QuoteService

    init(quoteService: QuoteService = .shared) {
        self.quoteService = quoteService
    }

    // MARK: - 딥링크

    func handle(url: URL) {
        guard let link = DeepLink(url: url) else {
            AppLog.widget.debug("알 수 없는 딥링크: \(url.absoluteString, privacy: .public)")
            return
        }
        handle(link)
    }

    func handle(_ link: DeepLink) {
        switch link {
        case .quote(let id):
            // 존재하지 않는 명언 ID 면 홈으로만 이동하고 상세는 띄우지 않는다.
            // (내장 명언과 ZenQuotes 캐시를 모두 확인한다)
            if quoteService.presentation(id: id) != nil {
                presentedQuoteID = id
            } else {
                AppLog.quotes.debug("존재하지 않는 명언 딥링크: \(id.uuidString, privacy: .public)")
            }
            selectedTab = .home
        case .schedule(let id):
            highlightedScheduleID = id
            selectedTab = .calendar
        case .today:
            selectedTab = .home
        case .composeToday:
            selectedTab = .home
            wantsTodayCompose = true
        }
    }

    /// 알림 payload 처리. 딥링크 문자열이 없으면 quoteID 로 폴백한다.
    func handleNotification(userInfo: [AnyHashable: Any]) {
        if let raw = userInfo[NotificationPayloadKey.deepLink] as? String,
           let url = URL(string: raw) {
            handle(url: url)
            return
        }
        if let raw = userInfo[NotificationPayloadKey.quoteID] as? String,
           let id = UUID(uuidString: raw) {
            handle(.quote(id))
            return
        }
        handle(.today)
    }

    func showQuote(_ quote: Quote) {
        presentedQuoteID = quote.id
    }

    func dismissQuote() {
        presentedQuoteID = nil
    }
}

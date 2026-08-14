import Foundation
import SwiftUI

/// 탭 선택과 딥링크 목적지를 관리한다.
///
/// 위젯 탭과 알림 탭은 모두 `DeepLink` 로 정규화된 뒤 이곳을 거쳐 화면으로 이어진다.
@MainActor
@Observable
final class AppRouter {
    enum Tab: String, CaseIterable, Identifiable {
        case home, calendar, quotes, settings

        var id: String { rawValue }

        var title: String {
            switch self {
            case .home: "홈"
            case .calendar: "캘린더"
            case .quotes: "명언"
            case .settings: "설정"
            }
        }

        var symbol: String {
            switch self {
            case .home: "house.fill"
            case .calendar: "calendar"
            case .quotes: "quote.bubble.fill"
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

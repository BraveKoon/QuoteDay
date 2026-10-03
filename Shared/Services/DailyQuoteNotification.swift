import Foundation
import UserNotifications

/// "오늘의 명언" 알림의 본문을 만드는 곳. 앱과 위젯이 **같은 문장**을 쓰게 한다.
///
/// 알림은 앞으로 2주치를 미리 예약한다. 반복 트리거로는 본문을 매일 바꿀 수
/// 없기 때문이다. 그런데 원격 명언(ZenQuotes)은 그날이 되어야 받아 올 수 있다.
/// 그래서 예약하는 시점에는 내장 명언이 들어가고, 나중에 원격 명언이 도착하면
/// 알림과 위젯이 서로 다른 문장을 보여 준다.
///
/// 받아 오는 쪽이 앱이면 앱이 다시 예약하면 된다. 문제는 **위젯도 혼자 받아
/// 온다**는 점이다. 아침에 앱을 열지 않는 사람에게는 위젯만 새 문장을 알고
/// 알림은 옛 문장을 그대로 들고 울린다. 둘은 잠금 화면에 나란히 보이므로
/// 어긋나면 바로 눈에 띈다.
public enum DailyQuoteNotification {
    public static let identifierPrefix = "daily-quote-"

    public static func identifier(for date: Date, calendar: Calendar = .current) -> String {
        "\(identifierPrefix)\(date.dayKey(calendar: calendar))"
    }

    public static func content(for presentation: QuotePresentation) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "☀️ 오늘의 명언"
        content.body = presentation.shareText
        content.sound = .default
        content.userInfo = [
            NotificationPayloadKey.deepLink: DeepLink.quote(presentation.id).url.absoluteString,
            NotificationPayloadKey.quoteID: presentation.id.uuidString
        ]
        return content
    }

    /// 아직 울리지 않은 **오늘 자** 알림의 본문을 지금 문장으로 다시 쓴다.
    ///
    /// 위젯이 원격 명언을 새로 받아 온 뒤에 부른다.
    ///
    /// 없는 알림을 새로 만들지는 않는다. 예약은 앱의 몫이고, 위젯이 끼어들어
    /// 만들기 시작하면 사용자가 꺼 둔 알림이 되살아날 수 있다. 이미 예약된
    /// 것의 본문만 고쳐 쓴다.
    ///
    /// - Returns: 실제로 고쳐 썼으면 `true`.
    @discardableResult
    public static func rewriteToday(
        now: Date = .now,
        defaults: UserDefaults = AppGroup.defaults,
        quoteService: QuoteService = .shared,
        remote: RemoteQuoteStore = .shared,
        calendar: Calendar = .current,
        center: UNUserNotificationCenter = .current()
    ) async -> Bool {
        guard defaults.bool(forKey: SharedDefaultsKey.dailyQuoteEnabled) else { return false }

        let identifier = identifier(for: now, calendar: calendar)
        let pending = await center.pendingNotificationRequests()
        guard
            let existing = pending.first(where: { $0.identifier == identifier }),
            let trigger = existing.trigger as? UNCalendarNotificationTrigger
        else { return false }

        let presentation = quoteService.todayPresentation(
            for: now,
            preferred: DailyQuoteSelection.preferredCategory(defaults: defaults),
            useRemote: remote.isEnabled,
            remote: remote
        )
        // 같은 문장이면 건드리지 않는다. 지웠다 다시 넣는 사이에 알림이 울 수도 있다.
        guard presentation.shareText != existing.content.body else { return false }

        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content(for: presentation),
            trigger: UNCalendarNotificationTrigger(
                dateMatching: trigger.dateComponents,
                repeats: false
            )
        )
        do {
            try await center.add(request)
            return true
        } catch {
            AppLog.notifications.error(
                "오늘의 명언 알림 다시 쓰기 실패: \(error.localizedDescription, privacy: .public)"
            )
            return false
        }
    }
}

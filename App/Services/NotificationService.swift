import Foundation
import UserNotifications

/// 일정 명언 알림과 매일의 명언 알림을 관리한다.
///
/// 권한은 앱 시작 시점이 아니라 사용자가 알림 기능을 켜는 순간에만 요청한다.
/// 권한이 거부되어도 예약 시도는 조용히 실패할 뿐 앱 동작에는 영향이 없다.
@MainActor
@Observable
final class NotificationService {
    /// 마지막으로 확인한 권한 상태.
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    /// 권한 요청이 진행 중인지.
    private(set) var isRequestingAuthorization = false

    private let center: UNUserNotificationCenter
    private let quoteService: QuoteService
    private let calendar: Calendar

    /// 매일의 명언은 반복 트리거 대신 하루치씩 미리 예약한다.
    /// 반복 트리거는 본문을 바꿀 수 없어 "매일 다른 명언"을 만들 수 없기 때문이다.
    static let dailyQuoteHorizonDays = 14
    /// iOS 는 앱당 64개의 대기 알림만 유지한다. 일정 알림은 가까운 순서로 잘라 낸다.
    static let maxScheduledItemNotifications = 40

    private static let dailyQuotePrefix = "daily-quote-"

    init(
        center: UNUserNotificationCenter = .current(),
        quoteService: QuoteService = .shared,
        calendar: Calendar = .current
    ) {
        self.center = center
        self.quoteService = quoteService
        self.calendar = calendar
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    var isDenied: Bool { authorizationStatus == .denied }

    // MARK: - 권한

    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// 사용자가 알림 기능을 켤 때 호출한다.
    /// - Returns: 알림을 보낼 수 있는 상태이면 `true`.
    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        await refreshAuthorizationStatus()
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            break
        @unknown default:
            break
        }

        isRequestingAuthorization = true
        defer { isRequestingAuthorization = false }

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthorizationStatus()
            AppGroup.defaults.set(true, forKey: SharedDefaultsKey.hasRequestedNotifications)
            return granted
        } catch {
            AppLog.notifications.error("알림 권한 요청 실패: \(error.localizedDescription, privacy: .public)")
            await refreshAuthorizationStatus()
            return false
        }
    }

    // MARK: - 일정 알림

    /// 일정 하나에 대한 명언 알림을 예약한다. 이미 있으면 교체한다.
    func schedule(for item: ScheduleItem) async {
        cancel(scheduleID: item.id)

        guard item.isQuoteNotificationEnabled else { return }
        guard item.startDate > .now else {
            AppLog.notifications.debug("과거 일정이라 알림을 예약하지 않습니다: \(item.displayTitle, privacy: .public)")
            return
        }
        guard await requestAuthorizationIfNeeded() else { return }

        let quote = item.resolvedQuote(using: quoteService)
        let author = quoteService.author(for: quote)
        let category = item.category

        let content = UNMutableNotificationContent()
        content.title = "\(category.emoji) \(category.notificationLead)"
        content.subtitle = item.displayTitle
        content.body = "\u{201C}\(quote.text)\u{201D}\n— \(author.displayName)"
        content.sound = .default
        content.userInfo = [
            NotificationPayloadKey.deepLink: DeepLink.quote(quote.id).url.absoluteString,
            NotificationPayloadKey.quoteID: quote.id.uuidString,
            NotificationPayloadKey.scheduleID: item.id.uuidString,
            NotificationPayloadKey.category: category.rawValue
        ]

        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: item.startDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: item.notificationIdentifier,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            AppLog.notifications.debug("알림 예약: \(item.displayTitle, privacy: .public)")
        } catch {
            AppLog.notifications.error("알림 예약 실패: \(error.localizedDescription, privacy: .public)")
        }
    }

    func cancel(scheduleID: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: ["schedule-\(scheduleID.uuidString)"])
    }

    /// 저장된 일정 전체를 기준으로 대기 알림을 다시 만든다.
    ///
    /// 앱을 오랫동안 실행하지 않아 예약이 사라졌거나, 설정이 바뀐 뒤에 호출한다.
    func rescheduleAll(items: [ScheduleItem]) async {
        let identifiers = items.map(\.notificationIdentifier)
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        let upcoming = items
            .filter { $0.isQuoteNotificationEnabled && $0.startDate > .now }
            .sorted { $0.startDate < $1.startDate }
            .prefix(Self.maxScheduledItemNotifications)

        guard !upcoming.isEmpty else { return }
        guard await requestAuthorizationIfNeeded() else { return }

        for item in upcoming {
            await schedule(for: item)
        }
    }

    // MARK: - 매일의 명언

    /// 오늘부터 `dailyQuoteHorizonDays` 일치의 "오늘의 명언" 알림을 예약한다.
    func scheduleDailyQuote(hour: Int, minute: Int, preferred category: AppCategory?) async {
        cancelDailyQuote()
        guard await requestAuthorizationIfNeeded() else { return }

        let now = Date.now
        for offset in 0..<Self.dailyQuoteHorizonDays {
            guard
                let day = calendar.date(byAdding: .day, value: offset, to: now),
                var components = dateComponents(for: day, hour: hour, minute: minute),
                let fireDate = calendar.date(from: components),
                fireDate > now
            else { continue }
            components.second = 0

            let quote = quoteService.quoteOfTheDay(for: fireDate, preferred: category)
            let author = quoteService.author(for: quote)

            let content = UNMutableNotificationContent()
            content.title = "☀️ 오늘의 명언"
            content.body = "\u{201C}\(quote.text)\u{201D}\n— \(author.displayName)"
            content.sound = .default
            content.userInfo = [
                NotificationPayloadKey.deepLink: DeepLink.quote(quote.id).url.absoluteString,
                NotificationPayloadKey.quoteID: quote.id.uuidString
            ]

            let request = UNNotificationRequest(
                identifier: "\(Self.dailyQuotePrefix)\(fireDate.dayKey(calendar: calendar))",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )

            do {
                try await center.add(request)
            } catch {
                AppLog.notifications.error("매일의 명언 예약 실패: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func cancelDailyQuote() {
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(Self.dailyQuotePrefix) }
            guard !ids.isEmpty else { return }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    private func dateComponents(for day: Date, hour: Int, minute: Int) -> DateComponents? {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = min(max(hour, 0), 23)
        components.minute = min(max(minute, 0), 59)
        return components
    }

    // MARK: - 진단

    func pendingNotificationCount() async -> Int {
        await center.pendingNotificationRequests().count
    }

    func removeAllPending() {
        center.removeAllPendingNotificationRequests()
    }
}

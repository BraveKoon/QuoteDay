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
    /// 반복 일정 하나가 가져갈 수 있는 대기 알림 수. 한 일정이 예산을 다 쓰지 않게 한다.
    static let maxNotificationsPerSchedule = 8
    /// 반복 회차를 미리 예약해 두는 기간. 앱을 열 때마다 다시 채운다.
    static let scheduleHorizonDays = 60

    private static let dailyQuotePrefix = "daily-quote-"
    private static let schedulePrefix = "schedule-"

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

    /// 일정 하나의 명언 알림을 예약한다. 이미 있으면 교체한다.
    ///
    /// 반복 일정이면 `scheduleHorizonDays` 안의 회차를
    /// `maxNotificationsPerSchedule` 개까지 미리 예약한다.
    /// 반복 트리거를 쓰지 않는 이유는 회차마다 다른 명언을 담기 위해서다.
    func schedule(for item: ScheduleItem) async {
        await cancelAll(scheduleID: item.id)

        guard item.isQuoteNotificationEnabled else { return }

        let occurrences = upcomingOccurrences(for: item)
        guard !occurrences.isEmpty else {
            AppLog.notifications.debug("예약할 회차가 없어 건너뜁니다: \(item.displayTitle, privacy: .public)")
            return
        }
        guard await requestAuthorizationIfNeeded() else { return }

        for occurrence in occurrences {
            await add(occurrence)
        }
    }

    /// 지금부터 예약 기간 안에 남아 있는 회차.
    private func upcomingOccurrences(for item: ScheduleItem, from date: Date = .now) -> [ScheduleOccurrence] {
        guard let horizon = calendar.date(byAdding: .day, value: Self.scheduleHorizonDays, to: date) else {
            return []
        }
        return item.occurrences(
            from: date.addingTimeInterval(1),
            to: horizon,
            limit: Self.maxNotificationsPerSchedule,
            calendar: calendar
        )
    }

    /// 회차 하나를 알림 센터에 등록한다.
    private func add(_ occurrence: ScheduleOccurrence) async {
        let quote = occurrence.resolvedQuote(using: quoteService)
        let author = quoteService.author(for: quote)
        let category = occurrence.category

        let content = UNMutableNotificationContent()
        content.title = "\(category.emoji) \(category.notificationLead)"
        content.subtitle = occurrence.displayTitle
        content.body = "\u{201C}\(quote.text)\u{201D}\n— \(author.displayName)"
        content.sound = .default
        content.userInfo = [
            NotificationPayloadKey.deepLink: DeepLink.quote(quote.id).url.absoluteString,
            NotificationPayloadKey.quoteID: quote.id.uuidString,
            NotificationPayloadKey.scheduleID: occurrence.scheduleID.uuidString,
            NotificationPayloadKey.category: category.rawValue
        ]

        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: occurrence.start
        )
        let request = UNNotificationRequest(
            identifier: occurrence.notificationIdentifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )

        do {
            try await center.add(request)
            AppLog.notifications.debug("알림 예약: \(occurrence.displayTitle, privacy: .public)")
        } catch {
            AppLog.notifications.error("알림 예약 실패: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 일정 하나에 딸린 알림을 모두 지운다(반복 회차 포함).
    func cancel(scheduleID: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: ["\(Self.schedulePrefix)\(scheduleID.uuidString)"])
        Task { await cancelAll(scheduleID: scheduleID) }
    }

    /// 같은 일정의 회차 알림까지 지운 뒤에 돌아온다.
    /// 새로 예약하기 직전에는 이 쪽을 써야 방금 만든 알림이 지워지지 않는다.
    private func cancelAll(scheduleID: UUID) async {
        let prefix = "\(Self.schedulePrefix)\(scheduleID.uuidString)"
        let identifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }
        guard !identifiers.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    /// 저장된 일정 전체를 기준으로 대기 알림을 다시 만든다.
    ///
    /// 앱을 오랫동안 실행하지 않아 예약이 사라졌거나, 설정이 바뀐 뒤에 호출한다.
    /// 반복 일정이 있으면 회차가 금방 64개 제한에 닿기 때문에
    /// 전체를 시간순으로 모아 가까운 것부터 예산만큼만 채운다.
    func rescheduleAll(items: [ScheduleItem]) async {
        await cancelAllScheduleNotifications()

        let now = Date.now
        guard let horizon = calendar.date(byAdding: .day, value: Self.scheduleHorizonDays, to: now) else {
            return
        }

        let upcoming = items
            .filter(\.isQuoteNotificationEnabled)
            .flatMap {
                $0.occurrences(
                    from: now.addingTimeInterval(1),
                    to: horizon,
                    limit: Self.maxNotificationsPerSchedule,
                    calendar: calendar
                )
            }
            .sorted { $0.start < $1.start }
            .prefix(Self.maxScheduledItemNotifications)

        guard !upcoming.isEmpty else { return }
        guard await requestAuthorizationIfNeeded() else { return }

        for occurrence in upcoming {
            await add(occurrence)
        }
    }

    /// 일정에서 만들어진 대기 알림 전체를 지운다.
    private func cancelAllScheduleNotifications() async {
        let identifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.schedulePrefix) }
        guard !identifiers.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
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

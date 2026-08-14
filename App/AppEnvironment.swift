import Foundation
import SwiftData
import SwiftUI
import UserNotifications

/// 앱이 살아 있는 동안 유지되는 객체 그래프.
///
/// 뷰는 필요한 서비스만 `@Environment` 로 꺼내 쓴다. 한곳에서 생성하기 때문에
/// 프리뷰나 테스트에서 인메모리 컨테이너로 통째로 갈아 끼우기 쉽다.
@MainActor
@Observable
final class AppEnvironment {
    let container: ModelContainer
    let settings: AppSettings
    let notifications: NotificationService
    let calendarService: CalendarService
    let router: AppRouter
    let scheduleStore: ScheduleStore
    let quoteService: QuoteService

    /// `UNUserNotificationCenter` 는 delegate 를 약하게 붙잡으므로 여기서 소유한다.
    private let notificationDelegate: NotificationDelegate

    init(container: ModelContainer = Persistence.shared, defaults: UserDefaults = AppGroup.defaults) {
        self.container = container
        let settings = AppSettings(defaults: defaults)
        let notifications = NotificationService()
        let calendarService = CalendarService()
        let router = AppRouter()

        self.settings = settings
        self.notifications = notifications
        self.calendarService = calendarService
        self.router = router
        self.quoteService = .shared
        self.scheduleStore = ScheduleStore(
            context: container.mainContext,
            notifications: notifications,
            calendarService: calendarService,
            settings: settings
        )

        self.notificationDelegate = NotificationDelegate(router: router)
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    /// 앱이 활성화될 때마다 호출한다.
    func refresh() async {
        await scheduleStore.refreshOnLaunch()
        calendarService.refreshAuthorizationStatus()
    }

    /// 프리뷰/테스트용 인메모리 환경.
    static func preview() -> AppEnvironment {
        let container = (try? Persistence.makeInMemoryContainer()) ?? Persistence.shared
        let environment = AppEnvironment(
            container: container,
            defaults: UserDefaults(suiteName: "preview.quoteday") ?? .standard
        )
        environment.seedPreviewData()
        return environment
    }

    private func seedPreviewData() {
        guard scheduleStore.items.isEmpty else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let samples: [(String, Int, AppCategory)] = [
            ("수학 공부", 18, .study),
            ("팀 회의", 10, .work),
            ("저녁 식사", 19, .meal),
            ("러닝 5km", 7, .exercise)
        ]
        for (title, hour, category) in samples {
            let start = calendar.date(byAdding: .hour, value: hour, to: today) ?? today
            _ = try? scheduleStore.create(
                ScheduleStore.Draft(
                    title: title,
                    startDate: start,
                    endDate: start.addingTimeInterval(3600),
                    category: category,
                    memo: "",
                    isQuoteNotificationEnabled: true,
                    quoteSlug: nil
                )
            )
        }
    }
}

/// 알림 표시/탭 처리를 라우터로 넘긴다.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let router: AppRouter

    init(router: AppRouter) {
        self.router = router
        super.init()
    }

    /// 앱이 화면에 떠 있을 때도 배너를 보여 준다.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    /// 알림을 탭했을 때 명언 상세로 이동한다.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        await MainActor.run {
            router.handleNotification(userInfo: userInfo)
        }
    }
}

// MARK: - Environment 주입

extension View {
    /// `@Observable` 서비스들을 한 번에 환경에 넣는다.
    ///
    /// 뷰에서는 `@Environment(ScheduleStore.self)` 처럼 필요한 것만 꺼내 쓴다.
    @MainActor
    func injecting(_ environment: AppEnvironment) -> some View {
        self
            .environment(environment)
            .environment(environment.router)
            .environment(environment.settings)
            .environment(environment.notifications)
            .environment(environment.calendarService)
            .environment(environment.scheduleStore)
            .modelContainer(environment.container)
    }
}

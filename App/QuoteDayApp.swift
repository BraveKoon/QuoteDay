import SwiftUI

@main
struct QuoteDayApp: App {
    @State private var appEnvironment: AppEnvironment
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // SwiftUI 는 App 초기화를 메인 스레드에서 수행한다.
        _appEnvironment = State(initialValue: MainActor.assumeIsolated { AppEnvironment() })
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .injecting(appEnvironment)
                .preferredColorScheme(appEnvironment.settings.appearance.colorScheme)
                .tint(ClayTheme.accent)
                // 위젯 탭 → 딥링크
                .onOpenURL { url in
                    appEnvironment.router.handle(url: url)
                }
                .task {
                    await appEnvironment.refresh()
                }
                .onChange(of: scenePhase) { _, phase in
                    // 백그라운드에서 시간이 흐른 뒤 돌아오면 알림/위젯 상태를 다시 맞춘다.
                    guard phase == .active else { return }
                    Task { await appEnvironment.refresh() }
                }
        }
    }
}

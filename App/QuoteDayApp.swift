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
            Group {
                // 첫 실행 안내(로그인 → 언어 → 닉네임)를 끝내기 전에는
                // 탭 화면을 아예 그리지 않는다.
                if appEnvironment.profile.hasCompletedOnboarding {
                    RootTabView()
                } else {
                    OnboardingView()
                }
            }
            .injecting(appEnvironment)
            // 앱이 그리는 언어. 화면 문구(.lproj)는 이 값으로 고른다.
            // 명언·인물 데이터는 `Localization` 이 같은 값을 보고 찾는다.
            .environment(\.locale, appEnvironment.settings.language.locale)
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

import SwiftUI
import UIKit

/// 설정 화면. 클레이 스타일을 유지하기 위해 `Form` 대신 카드로 구성한다.
struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(NotificationService.self) private var notifications
    @Environment(CalendarService.self) private var calendarService
    @Environment(ScheduleStore.self) private var store
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(PlusStore.self) private var plus
    @Environment(NoteStore.self) private var notes

    @State private var pendingNotificationCount = 0
    @State private var isRefreshingRemoteQuote = false
    /// 캐시 상태를 다시 읽게 만드는 트리거.
    @State private var remoteQuoteRefreshToken = 0
    @State private var showsPaywall = false

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            ScrollView {
            VStack(spacing: ClayTheme.Spacing.m) {
                header

                plusCard
                notesCard
                notificationCard(settings: settings)
                remoteQuoteCard(settings: settings)
                dailyQuoteCard(settings: settings)
                preferredCategoryCard(settings: settings)
                appearanceCard(settings: settings)
                calendarCard(settings: settings)
                widgetGuideCard
                supportCard
                aboutCard
            }
            .padding(.horizontal, ClayTheme.Spacing.m)
            .padding(.top, ClayTheme.Spacing.m)
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
        .clayBackground()
        .sheet(isPresented: $showsPaywall) {
            PaywallView()
        }
        .task {
            await notifications.refreshAuthorizationStatus()
            pendingNotificationCount = await notifications.pendingNotificationCount()
        }
        // 이 화면은 자체 "설정" 헤더를 쓰므로 내비게이션 바를 감춘다.
        // 밀어 올린 화면(노트 모아 보기)은 각자 바를 갖는다.
        .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        Text("설정")
            .font(ClayFont.hero())
            .foregroundStyle(ClayTheme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Quote Plus

    private var plusCard: some View {
        card(title: "Quote Plus", symbol: "book.pages") {
            VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
                if plus.isPlus {
                    HStack(spacing: ClayTheme.Spacing.xs) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(ClayTheme.accent)
                        Text("사용 중")
                            .font(ClayFont.callout())
                            .foregroundStyle(ClayTheme.textPrimary)
                        Spacer()
                        if plus.isDebugUnlocked && !plus.hasEntitlement {
                            Text("테스트 모드")
                                .font(ClayFont.caption())
                                .foregroundStyle(ClayTheme.textSecondary)
                        }
                    }
                    Text("인물 프로필, 비하인드 스토리, 노트 PDF 내보내기, 프리미엄 카드 테마를 모두 쓸 수 있어요.")
                        .font(ClayFont.caption())
                        .foregroundStyle(ClayTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("명언 뒤의 이야기와 인물 프로필을 열고, 노트를 PDF 로 내보낼 수 있어요.")
                        .font(ClayFont.callout())
                        .foregroundStyle(ClayTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("광고는 앞으로도 넣지 않습니다.")
                        .font(ClayFont.caption())
                        .foregroundStyle(ClayTheme.textSecondary)

                    Button("Quote Plus 알아보기") { showsPaywall = true }
                        .clayButton(.primary, fullWidth: true)
                        .padding(.top, ClayTheme.Spacing.xs)
                }

                Button("구매 복원") {
                    Task { await plus.restore() }
                }
                .clayButton(.secondary, fullWidth: true)

                #if DEBUG
                // 결제 없이 Plus 화면을 확인하기 위한 스위치.
                // DEBUG 빌드에만 존재하므로 배포본에는 나타나지 않는다.
                ClayDivider().padding(.vertical, 2)
                Toggle(isOn: Binding(
                    get: { plus.isDebugUnlocked },
                    set: { plus.isDebugUnlocked = $0 }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("테스트용 Plus 잠금 해제")
                            .font(ClayFont.callout())
                            .foregroundStyle(ClayTheme.textPrimary)
                        Text("개발 빌드 전용. 결제 없이 유료 화면을 확인합니다.")
                            .font(ClayFont.caption())
                            .foregroundStyle(ClayTheme.textSecondary)
                    }
                }
                .tint(ClayTheme.accent)
                #endif
            }
        }
    }

    // MARK: - 노트

    private var notesCard: some View {
        card(title: "나의 노트", symbol: "square.and.pencil") {
            VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
                Text(notes.isEmpty
                     ? "명언 상세에서 노트를 쓰면 여기 모입니다."
                     : "지금까지 \(notes.notes.count)편의 명언에 생각을 남겼어요.")
                    .font(ClayFont.callout())
                    .foregroundStyle(ClayTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                NavigationLink {
                    NotesListView()
                } label: {
                    Label("노트 모아 보기", systemImage: "chevron.right")
                        .font(ClayFont.headline())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ClayTheme.Spacing.s + 2)
                        .foregroundStyle(ClayTheme.textPrimary)
                        .clayCard(cornerRadius: ClayTheme.Radius.control)
                }
            }
        }
    }

    // MARK: - 후원

    private var supportCard: some View {
        card(title: "개발자 후원하기", symbol: "cup.and.saucer.fill") {
            VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
                Text("광고 없는 쾌적한 앱을 만들기 위해 노력 중입니다.\n커피 한 잔으로 응원해 주세요!")
                    .font(ClayFont.callout())
                    .foregroundStyle(ClayTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("후원은 순수한 응원이에요. Quote Plus 기능이 열리지는 않습니다.")
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(SupportLink.all) { link in
                    Link(destination: link.url) {
                        HStack(spacing: ClayTheme.Spacing.s) {
                            Image(systemName: link.symbol)
                                .frame(width: 20)
                            Text(link.title)
                                .font(ClayFont.headline())
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                        .foregroundStyle(ClayTheme.textPrimary)
                        .padding(.vertical, ClayTheme.Spacing.s + 2)
                        .padding(.horizontal, ClayTheme.Spacing.s)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .clayCard(cornerRadius: ClayTheme.Radius.control)
                    }
                    .accessibilityLabel("\(link.title) 열기")
                }
            }
        }
    }

    // MARK: - 알림

    private func notificationCard(settings: AppSettings) -> some View {
        card(title: "알림", symbol: "bell.fill") {
            VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
                HStack {
                    Text("알림 권한")
                        .font(ClayFont.callout())
                        .foregroundStyle(ClayTheme.textPrimary)
                    Spacer()
                    Text(authorizationText)
                        .font(ClayFont.caption())
                        .foregroundStyle(notifications.isAuthorized ? ClayTheme.accent : ClayTheme.danger)
                }

                if notifications.isDenied {
                    Button("설정 앱에서 알림 켜기") { openSystemSettings() }
                        .clayButton(.secondary, fullWidth: true)
                } else if !notifications.isAuthorized {
                    Button("알림 허용하기") {
                        Task { await notifications.requestAuthorizationIfNeeded() }
                    }
                    .clayButton(.primary, fullWidth: true)
                }

                ClayDivider()

                HStack {
                    Text("예약된 알림")
                        .font(ClayFont.callout())
                        .foregroundStyle(ClayTheme.textPrimary)
                    Spacer()
                    Text("\(pendingNotificationCount)건")
                        .font(ClayFont.caption())
                        .foregroundStyle(ClayTheme.textSecondary)
                        .monospacedDigit()
                }

                Button("알림 다시 예약") {
                    Task {
                        await store.refreshOnLaunch()
                        pendingNotificationCount = await notifications.pendingNotificationCount()
                    }
                }
                .clayButton(.secondary, fullWidth: true)
            }
        }
    }

    private var authorizationText: String {
        switch notifications.authorizationStatus {
        case .authorized, .provisional, .ephemeral: "허용됨"
        case .denied: "거부됨"
        case .notDetermined: "미설정"
        @unknown default: "알 수 없음"
        }
    }

    // MARK: - ZenQuotes

    private func remoteQuoteCard(settings: AppSettings) -> some View {
        @Bindable var settings = settings

        return card(title: "오늘의 명언 소스", symbol: "antenna.radiowaves.left.and.right") {
            VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
                Toggle(isOn: $settings.usesRemoteQuoteOfTheDay) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ZenQuotes 사용")
                            .font(ClayFont.headline())
                            .foregroundStyle(ClayTheme.textPrimary)
                        Text("매일 ZenQuotes 의 오늘의 명언을 받아옵니다. 꺼 두면 앱에 내장된 한국어 명언만 사용합니다.")
                            .font(ClayFont.caption())
                            .foregroundStyle(ClayTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(ClayTheme.accent)
                .onChange(of: settings.usesRemoteQuoteOfTheDay) { _, isOn in
                    guard isOn else {
                        remoteQuoteRefreshToken += 1
                        return
                    }
                    Task { await refreshRemoteQuote(force: false) }
                }

                if settings.usesRemoteQuoteOfTheDay {
                    ClayDivider()

                    // remoteQuoteRefreshToken 을 참조해 갱신 후 다시 계산되게 한다.
                    let _ = remoteQuoteRefreshToken
                    let store = RemoteQuoteStore.shared

                    if let presentation = store.presentation() {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\u{201C}\(presentation.quote.text)\u{201D}")
                                .font(ClayFont.callout())
                                .foregroundStyle(ClayTheme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineLimit(3)
                            Text("— \(presentation.author.displayName)")
                                .font(ClayFont.caption())
                                .foregroundStyle(ClayTheme.textSecondary)
                        }
                    } else {
                        Text("아직 오늘의 명언을 받아오지 못했어요. 내장 명언을 보여 주는 중입니다.")
                            .font(ClayFont.caption())
                            .foregroundStyle(ClayTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let error = store.lastErrorMessage {
                        Text(error)
                            .font(ClayFont.caption())
                            .foregroundStyle(ClayTheme.danger)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let attempt = store.lastAttemptDate {
                        Text("마지막 확인 \(Formatters.shortDateTime.string(from: attempt))")
                            .font(ClayFont.caption())
                            .foregroundStyle(ClayTheme.textSecondary)
                    }

                    Button {
                        Task { await refreshRemoteQuote(force: true) }
                    } label: {
                        if isRefreshingRemoteQuote {
                            ProgressView()
                        } else {
                            Label("지금 새로고침", systemImage: "arrow.clockwise")
                        }
                    }
                    .clayButton(.secondary, fullWidth: true)
                    .disabled(isRefreshingRemoteQuote)

                    Link(destination: RemoteQuoteStore.attributionURL) {
                        Text(RemoteQuoteStore.attribution)
                            .font(ClayFont.caption())
                            .foregroundStyle(ClayTheme.accent)
                            .underline()
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    private func refreshRemoteQuote(force: Bool) async {
        isRefreshingRemoteQuote = true
        await appEnvironment.refreshRemoteQuote(force: force)
        isRefreshingRemoteQuote = false
        remoteQuoteRefreshToken += 1
    }

    // MARK: - 매일의 명언

    private func dailyQuoteCard(settings: AppSettings) -> some View {
        @Bindable var settings = settings

        return card(title: "매일의 명언", symbol: "sun.max.fill") {
            VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
                Toggle("매일 정해진 시간에 받기", isOn: $settings.isDailyQuoteEnabled)
                    .font(ClayFont.callout())
                    .foregroundStyle(ClayTheme.textPrimary)
                    .tint(ClayTheme.accent)
                    .onChange(of: settings.isDailyQuoteEnabled) { _, isOn in
                        Task { await applyDailyQuoteSetting(isOn: isOn) }
                    }

                if settings.isDailyQuoteEnabled {
                    DatePicker(
                        "알림 시각",
                        selection: $settings.dailyQuoteTime,
                        displayedComponents: .hourAndMinute
                    )
                    .font(ClayFont.callout())
                    .foregroundStyle(ClayTheme.textPrimary)
                    .tint(ClayTheme.accent)
                    .onChange(of: settings.dailyQuoteTime) { _, _ in
                        Task { await applyDailyQuoteSetting(isOn: true) }
                    }

                    Text("앞으로 \(NotificationService.dailyQuoteHorizonDays)일치를 미리 예약합니다. 앱을 열 때마다 자동으로 갱신돼요.")
                        .font(ClayFont.caption())
                        .foregroundStyle(ClayTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func applyDailyQuoteSetting(isOn: Bool) async {
        guard isOn else {
            notifications.cancelDailyQuote()
            pendingNotificationCount = await notifications.pendingNotificationCount()
            return
        }
        await notifications.scheduleDailyQuote(
            hour: settings.dailyQuoteHour,
            minute: settings.dailyQuoteMinute,
            preferred: settings.preferredCategory
        )
        pendingNotificationCount = await notifications.pendingNotificationCount()
    }

    // MARK: - 기본 명언 카테고리

    private func preferredCategoryCard(settings: AppSettings) -> some View {
        @Bindable var settings = settings

        return card(title: "기본 명언 카테고리", symbol: "square.grid.2x2.fill") {
            VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
                Text("오늘의 명언을 특정 카테고리에서만 고릅니다.")
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.textSecondary)

                CategoryPicker(
                    selection: Binding(
                        get: { settings.preferredCategory ?? .etc },
                        set: { newValue in
                            // 같은 항목을 다시 누르면 해제한다.
                            settings.preferredCategory = (settings.preferredCategory == newValue) ? nil : newValue
                            Task { await refreshDailyQuoteIfNeeded() }
                        }
                    ),
                    categories: AppCategory.selectableForQuotes
                )

                if settings.preferredCategory != nil {
                    Button("전체 카테고리로 되돌리기") {
                        settings.preferredCategory = nil
                        Task { await refreshDailyQuoteIfNeeded() }
                    }
                    .clayButton(.secondary, fullWidth: true)
                }
            }
        }
    }

    private func refreshDailyQuoteIfNeeded() async {
        guard settings.isDailyQuoteEnabled else { return }
        await applyDailyQuoteSetting(isOn: true)
    }

    // MARK: - 화면

    private func appearanceCard(settings: AppSettings) -> some View {
        @Bindable var settings = settings

        return card(title: "화면 모드", symbol: "circle.lefthalf.filled") {
            Picker("화면 모드", selection: $settings.appearance) {
                ForEach(AppSettings.Appearance.allCases) { appearance in
                    Text(appearance.title).tag(appearance)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - 캘린더

    private func calendarCard(settings: AppSettings) -> some View {
        @Bindable var settings = settings

        return card(title: "iOS 캘린더", symbol: "calendar") {
            VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
                Toggle("새 일정을 iOS 캘린더에도 추가", isOn: $settings.mirrorsToSystemCalendar)
                    .font(ClayFont.callout())
                    .foregroundStyle(ClayTheme.textPrimary)
                    .tint(ClayTheme.accent)
                    .onChange(of: settings.mirrorsToSystemCalendar) { _, isOn in
                        guard isOn else { return }
                        Task {
                            let granted = await calendarService.requestWriteAccess()
                            if !granted { settings.mirrorsToSystemCalendar = false }
                        }
                    }

                Text(calendarStatusText)
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if calendarService.isDenied {
                    Button("설정 앱에서 캘린더 권한 열기") { openSystemSettings() }
                        .clayButton(.secondary, fullWidth: true)
                }
            }
        }
    }

    private var calendarStatusText: String {
        switch calendarService.authorizationStatus {
        case .fullAccess: "전체 접근이 허용되어 기기 일정도 함께 볼 수 있어요."
        case .writeOnly: "쓰기 권한만 허용되어 있어요. 일정을 내보낼 수는 있지만 불러올 수는 없습니다."
        case .denied, .restricted: "캘린더 접근이 거부되어 있어요. 앱 내부 일정 기능은 그대로 사용할 수 있습니다."
        default: "아직 권한을 요청하지 않았어요."
        }
    }

    // MARK: - 위젯 / 정보

    private var widgetGuideCard: some View {
        card(title: "위젯 추가하기", symbol: "square.grid.2x2") {
            VStack(alignment: .leading, spacing: ClayTheme.Spacing.xs) {
                Text("홈 화면")
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.textSecondary)
                guideRow("1", "홈 화면을 길게 누릅니다.")
                guideRow("2", "왼쪽 위 + 버튼을 누릅니다.")
                guideRow("3", "\u{2018}QuoteDay\u{2019}를 검색해 원하는 크기를 추가합니다.")
                Text("작게: 오늘의 명언 / 보통: 명언과 인물 / 크게: 명언과 오늘의 일정")
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                ClayDivider().padding(.vertical, 2)

                Text("잠금화면")
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.textSecondary)
                guideRow("1", "잠금화면을 길게 누르고 \u{2018}사용자화\u{2019}를 누릅니다.")
                guideRow("2", "\u{2018}잠금 화면\u{2019}을 고른 뒤 시계 아래 영역을 누릅니다.")
                guideRow("3", "\u{2018}QuoteDay\u{2019}를 찾아 추가합니다.")
                Text("한 줄: 다음 일정 / 원형: 일정 시각 / 사각형: 명언과 인물. 같은 위젯이 대기 화면(StandBy)에도 표시됩니다.")
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                ClayDivider().padding(.vertical, 2)
                if !AppGroup.isConfigured {
                    Text("App Group 이 설정되지 않아 위젯에서 일정이 보이지 않을 수 있어요.")
                        .font(ClayFont.caption())
                        .foregroundStyle(ClayTheme.danger)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func guideRow(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: ClayTheme.Spacing.xs) {
            Text(number)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(ClayTheme.accent))
            Text(text)
                .font(ClayFont.callout())
                .foregroundStyle(ClayTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var aboutCard: some View {
        card(title: "앱 정보", symbol: "info.circle.fill") {
            VStack(alignment: .leading, spacing: ClayTheme.Spacing.xs) {
                infoRow("이름", "QuoteDay")
                infoRow("버전", appVersion)
                infoRow("수록 명언", "\(QuoteService.shared.quoteCount)개")
                infoRow("수록 인물", "\(AuthorLibrary.all.count)명")
                Text("모든 명언과 인물 정보는 앱에 내장되어 있어 네트워크 없이도 동작합니다.")
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(ClayFont.callout())
                .foregroundStyle(ClayTheme.textSecondary)
            Spacer()
            Text(value)
                .font(ClayFont.callout())
                .foregroundStyle(ClayTheme.textPrimary)
        }
    }

    // MARK: - 공통 카드

    private func card(
        title: String,
        symbol: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
            Label(title, systemImage: symbol)
                .font(ClayFont.headline())
                .foregroundStyle(ClayTheme.textPrimary)
            content()
        }
        .padding(ClayTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clayCard()
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview("설정") {
    SettingsView()
        .injecting(AppEnvironment.preview())
}

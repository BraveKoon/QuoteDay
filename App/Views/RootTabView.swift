import SwiftUI

/// 앱의 최상위 화면. 클레이 스타일 탭 바와 명언 상세 오버레이를 담당한다.
struct RootTabView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var router = router

        ZStack(alignment: .bottom) {
            Color.clear.clayBackground()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            ClayTabBar(selection: $router.selectedTab)
                .padding(.horizontal, ClayTheme.Spacing.m)
                .padding(.bottom, ClayTheme.Spacing.xs)
        }
        .sheet(item: Binding(
            get: { router.presentedQuoteID.map(QuoteIdentifier.init(id:)) },
            set: { router.presentedQuoteID = $0?.id }
        )) { identifier in
            QuoteDetailView(quoteID: identifier.id)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch router.selectedTab {
        case .home:
            HomeView().transition(screenTransition)
        case .calendar:
            CalendarView().transition(screenTransition)
        case .quotes:
            QuoteBrowserView().transition(screenTransition)
        case .settings:
            SettingsView().transition(screenTransition)
        }
    }

    private var screenTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.97)),
            removal: .opacity
        )
    }
}

/// `sheet(item:)` 에 넘기기 위한 UUID 래퍼.
private struct QuoteIdentifier: Identifiable, Hashable {
    let id: UUID
}

// MARK: - 탭 바

struct ClayTabBar: View {
    @Binding var selection: AppRouter.Tab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var indicator

    var body: some View {
        HStack(spacing: ClayTheme.Spacing.xs) {
            ForEach(AppRouter.Tab.allCases) { tab in
                Button {
                    guard tab != selection else { return }
                    if reduceMotion {
                        selection = tab
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            selection = tab
                        }
                    }
                } label: {
                    tabLabel(tab)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(tab == selection ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(ClayTheme.Spacing.xs)
        .clayCard(cornerRadius: ClayTheme.Radius.card, elevation: 16)
        .padding(.horizontal, ClayTheme.Spacing.xs)
    }

    @ViewBuilder
    private func tabLabel(_ tab: AppRouter.Tab) -> some View {
        let isSelected = tab == selection

        VStack(spacing: 3) {
            Image(systemName: tab.symbol)
                .font(.system(size: 17, weight: .semibold))
            Text(tab.title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(isSelected ? Color.white : ClayTheme.textSecondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, ClayTheme.Spacing.s - 2)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: ClayTheme.Radius.control, style: .continuous)
                    .fill(ClayTheme.accent)
                    .matchedGeometryEffect(id: "tab-indicator", in: indicator)
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    RootTabView()
        .injecting(AppEnvironment.preview())
}

import SwiftUI

/// 데이터가 없거나 권한이 없을 때 보여 주는 빈 상태.
///
/// 오류 상황에서도 화면이 비어 보이지 않도록 앱 전체에서 이 컴포넌트를 재사용한다.
struct EmptyStateView: View {
    let symbol: String
    let title: String
    var message: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: ClayTheme.Spacing.s) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(ClayTheme.accent)
                .padding(ClayTheme.Spacing.m)
                .clayCard(cornerRadius: ClayTheme.Radius.control, elevation: 8)

            Text(title)
                .font(ClayFont.headline())
                .foregroundStyle(ClayTheme.textPrimary)
                .multilineTextAlignment(.center)

            if let message {
                Text(message)
                    .font(ClayFont.callout())
                    .foregroundStyle(ClayTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .clayButton(.primary)
                    .padding(.top, ClayTheme.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ClayTheme.Spacing.l)
        .padding(.horizontal, ClayTheme.Spacing.m)
        .accessibilityElement(children: .combine)
    }
}

/// 섹션 제목. 오른쪽에 버튼 등을 붙일 수 있다.
struct SectionHeader<Trailing: View>: View {
    private let title: String
    private let subtitle: String?
    private let trailing: Trailing

    init(_ title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ClayFont.title())
                    .foregroundStyle(ClayTheme.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(ClayFont.caption())
                        .foregroundStyle(ClayTheme.textSecondary)
                }
            }
            Spacer(minLength: ClayTheme.Spacing.s)
            trailing
        }
        .accessibilityAddTraits(.isHeader)
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: String, subtitle: String? = nil) {
        self.init(title, subtitle: subtitle) { EmptyView() }
    }
}

#Preview("빈 상태") {
    VStack(spacing: ClayTheme.Spacing.l) {
        SectionHeader("오늘의 일정", subtitle: "2개")
        EmptyStateView(
            symbol: "calendar.badge.plus",
            title: "오늘은 등록된 일정이 없어요",
            message: "일정을 추가하면 시간에 맞춰 어울리는 명언을 보내 드려요.",
            actionTitle: "일정 추가"
        ) {}
        .clayCard()
    }
    .padding(ClayTheme.Spacing.l)
    .clayBackground()
}

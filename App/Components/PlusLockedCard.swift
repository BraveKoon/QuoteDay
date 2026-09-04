import SwiftUI

/// Quote Plus 잠금 안내 카드.
///
/// 내용을 흐릿하게 덮어 보여 주는 방식은 쓰지 않는다. 읽으려 애쓰게 만드는 대신
/// 무엇이 들어 있는지 문장으로 알려 주고, 열지 말지는 사용자가 정하게 한다.
struct PlusLockedCard: View {
    let feature: PlusFeature
    /// 이 명언에 실제로 배경 콘텐츠가 있는지 등, 상황에 맞는 한 줄.
    var message: String?
    let onUnlock: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
            HStack(spacing: ClayTheme.Spacing.xs) {
                Image(systemName: "lock.fill")
                    .font(.caption)
                Text("Quote Plus")
                    .font(ClayFont.caption())
            }
            .foregroundStyle(ClayTheme.accent)

            Text(feature.title)
                .font(ClayFont.headline())
                .foregroundStyle(ClayTheme.textPrimary)

            Text(message ?? feature.detail)
                .font(ClayFont.callout())
                .foregroundStyle(ClayTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Quote Plus 알아보기", action: onUnlock)
                .clayButton(.primary, fullWidth: true)
                .padding(.top, ClayTheme.Spacing.xs)
        }
        .padding(ClayTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clayCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(feature.title), Quote Plus 필요")
        .accessibilityHint("두 번 탭하면 Quote Plus 안내를 엽니다.")
    }
}

/// 이미 열려 있는 Plus 구획 위에 붙이는 작은 표식.
struct PlusBadge: View {
    var body: some View {
        Text("PLUS")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(ClayTheme.textOnAccent)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(ClayTheme.accent)
            )
            .accessibilityLabel("Quote Plus 전용")
    }
}

#Preview("잠금 카드") {
    VStack(spacing: ClayTheme.Spacing.m) {
        PlusLockedCard(feature: .behindStory) {}
        PlusLockedCard(
            feature: .authorProfile,
            message: "윈스턴 처칠이 어떤 시대를 살았는지 함께 읽어 보세요."
        ) {}
        PlusBadge()
    }
    .padding(ClayTheme.Spacing.m)
    .clayBackground()
}

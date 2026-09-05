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

/// 잠긴 콘텐츠를 흐리게 깔고 그 위에 안내를 얹는 컨테이너.
///
/// 흐린 글자는 **읽으라고 두는 것이 아니라** 분량과 결이 있다는 신호다.
/// 그래서 세 가지를 함께 지킨다.
/// - `allowsHitTesting(false)` — 흐린 내용은 눌리지 않는다.
/// - `accessibilityHidden(true)` — VoiceOver 가 읽어 버리면 잠금이 무의미하다.
/// - 투명도 줄이기(`accessibilityReduceTransparency`)를 켠 사용자에게는
///   흐림 대신 단색 면을 깐다. 흐림은 그 설정을 켠 이유 자체이기 때문이다.
struct PlusLockedPreview<Content: View>: View {
    let feature: PlusFeature
    var message: String?
    /// 미리 보여 줄 높이. 이 높이만큼만 잘라서 깐다.
    var previewHeight: CGFloat = 190
    let onUnlock: () -> Void
    @ViewBuilder var content: () -> Content

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        // 겹치지 않고 위아래로 쌓는다. 겹치면 패널에 가린 만큼의 흐린 글이
        // 그려지기만 하고 보이지는 않아 계산 낭비다.
        VStack(spacing: 0) {
            backdrop
            unlockPanel
        }
        .clipShape(RoundedRectangle(cornerRadius: ClayTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: ClayTheme.Radius.card, style: .continuous)
                .strokeBorder(ClayTheme.separator, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var backdrop: some View {
        if reduceTransparency {
            ClayTheme.surfaceSunken
                .frame(height: previewHeight)
                .frame(maxWidth: .infinity)
        } else {
            content()
                .padding(ClayTheme.Spacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: previewHeight, alignment: .top)
                .clipped()
                .blur(radius: 7)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .background(ClayTheme.surface)
        }
    }

    private var unlockPanel: some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.xs) {
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
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Quote Plus 알아보기", action: onUnlock)
                .clayButton(.primary, fullWidth: true)
                .padding(.top, 2)
        }
        .padding(ClayTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ClayTheme.surface)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(feature.title), Quote Plus 필요")
        .accessibilityHint("두 번 탭하면 Quote Plus 안내를 엽니다.")
    }
}

/// 콘텐츠가 아직 없을 때 쓰는 안내. 잠금이 아니라 준비 상태를 알린다.
struct ComingSoonCard: View {
    let title: String
    var message: String = "아직 준비 중입니다."

    var body: some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.xs) {
            SectionHeader(title)
            HStack(spacing: ClayTheme.Spacing.xs) {
                Image(systemName: "hourglass")
                    .font(.caption)
                    .foregroundStyle(ClayTheme.textSecondary)
                Text(message)
                    .font(ClayFont.callout())
                    .foregroundStyle(ClayTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(ClayTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clayCard()
        .accessibilityElement(children: .combine)
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
    ScrollView {
        VStack(spacing: ClayTheme.Spacing.m) {
            PlusLockedPreview(feature: .behindStory) {} content: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("1940년 6월, 영국 하원")
                    Text(String(repeating: "이 문장이 나온 상황을 설명하는 글이 여기에 들어간다. ", count: 6))
                }
                .font(ClayFont.body())
                .foregroundStyle(ClayTheme.textPrimary)
            }
            PlusLockedCard(feature: .noteExport) {}
            ComingSoonCard(title: "비하인드 스토리")
            PlusBadge()
        }
        .padding(ClayTheme.Spacing.m)
    }
    .clayBackground()
}

import SwiftUI

/// 하트와 그 아래 전체 개수.
///
/// 숫자는 **모든 사용자의 합계**다. 내가 누른 하트도 여기에 포함된다.
struct HeartButton: View {
    let slug: String
    /// 큰 형태(명언 상세)와 작은 형태(목록)를 나눈다.
    var size: Size = .large

    @Environment(HeartStore.self) private var hearts
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var pop = false

    enum Size {
        case large
        case small

        var symbol: CGFloat { self == .large ? 26 : 15 }
        var count: CGFloat { self == .large ? 13 : 11 }
        var spacing: CGFloat { self == .large ? 4 : 2 }
    }

    private var snapshot: HeartSnapshot { hearts.snapshot(for: slug) }

    var body: some View {
        Button {
            hearts.toggle(slug)
            guard !reduceMotion else { return }
            // 채워지는 순간에만 튀어 오른다. 취소할 때 튀면 실수처럼 보인다.
            if hearts.isMine(slug) {
                pop = true
                withAnimation(.spring(response: 0.28, dampingFraction: 0.5)) { pop = false }
            }
        } label: {
            VStack(spacing: size.spacing) {
                Image(systemName: snapshot.isMine ? "heart.fill" : "heart")
                    .font(.system(size: size.symbol, weight: .semibold))
                    .foregroundStyle(snapshot.isMine ? ClayTheme.danger : ClayTheme.textSecondary)
                    .scaleEffect(pop ? 1.25 : 1)

                Text(snapshot.displayCount)
                    .font(.system(size: size.count, weight: .semibold, design: .rounded))
                    .foregroundStyle(snapshot.isMine ? ClayTheme.danger : ClayTheme.textSecondary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: snapshot)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(snapshot.isMine ? "하트 취소" : "하트")
        .accessibilityValue("전체 \(snapshot.count)개")
        .accessibilityAddTraits(snapshot.isMine ? [.isSelected, .isButton] : .isButton)
    }
}

/// 하트가 왜 이 기기에만 남는지 알려 주는 한 줄. 문제가 없으면 아무것도 그리지 않는다.
struct HeartSyncNotice: View {
    @Environment(HeartStore.self) private var hearts

    var body: some View {
        if let message = hearts.availability.message(subject: "하트") {
            Label(message, systemImage: "icloud.slash")
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    VStack(spacing: ClayTheme.Spacing.l) {
        HeartButton(slug: "jobs-love-what-you-do")
        HeartButton(slug: "laotzu-journey-of-a-thousand-miles", size: .small)
        HeartSyncNotice()
    }
    .padding(ClayTheme.Spacing.l)
    .clayBackground()
    .injecting(AppEnvironment.preview())
}

import SwiftUI

/// "지금 기분은 어떠세요?" — 지금 상태로 명언을 바꿔 고르는 카드.
///
/// 이것이 "AI 추천"의 자리를 대신한다. 추천은 취향을 알아맞히는 문제가 아니라
/// **지금 상태를 물어보는 문제**다. 사용자가 직접 고르는 편이 앱이 추측하는
/// 것보다 정확하고, 빠르고, 공짜다.
///
/// 처음에는 칩 한 줄로 만들었다가 바꿨다. 이유가 셋이다.
///
/// 하나. **누를 수가 없었다.** 캡션 글씨에 위아래 6pt 를 두니 탭 영역이 26pt
/// 쯤이었다. 애플이 권하는 최소는 44pt 다. 보기에 작은 것이 아니라 실제로
/// 누르기 어려웠다.
///
/// 둘. **여섯 개 중 네 개만 보였다.** 가로로 밀어야 나머지가 나오는데,
/// 밀 수 있다는 것을 모르면 없는 기능이다.
///
/// 셋. 카드 두 장 사이에 배경 없이 끼어 있어서 **각주처럼 보였다.** 이 앱이
/// AI 추천 대신 내놓은 답인데 화면에서 가장 약한 요소였다.
///
/// 고른 기분은 그날 기록에 함께 저장된다. 월간 회고의 "가장 많이 고른 기분"이
/// 거기서 나온다 — 기능 두 개가 서로를 먹여 살린다.
struct MoodPickerCard: View {
    /// 고른 기분으로 바꿔 보여 줄 명언. 고르지 않았으면 nil.
    @Binding var selection: QuoteMood?

    /// 글씨가 커지면 타일도 같이 커져서 두 줄로 접힌다.
    /// 고정값으로 두면 큰 글씨 설정에서 "인간관계" 가 잘린다.
    @ScaledMetric(relativeTo: .callout) private var tileMinimumWidth: CGFloat = 96
    @ScaledMetric(relativeTo: .title2) private var emojiSize: CGFloat = 26

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: tileMinimumWidth), spacing: ClayTheme.Spacing.xs)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
            header

            LazyVGrid(columns: columns, spacing: ClayTheme.Spacing.xs) {
                ForEach(QuoteMood.allCases) { mood in
                    tile(mood)
                }
            }

            if let selection {
                footer(selection)
            }
        }
        .padding(ClayTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clayCard(cornerRadius: ClayTheme.Radius.card)
        .animation(.easeInOut(duration: 0.22), value: selection)
    }

    // MARK: - 조각들

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("지금 기분은 어떠세요?")
                .font(ClayFont.headline())
                .foregroundStyle(ClayTheme.textPrimary)
            Text("고르면 그 기분에 어울리는 명언으로 바뀌어요.")
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tile(_ mood: QuoteMood) -> some View {
        let isOn = selection == mood
        return Button {
            // 같은 것을 다시 누르면 해제한다.
            withAnimation { selection = isOn ? nil : mood }
        } label: {
            VStack(spacing: 4) {
                Text(mood.emoji)
                    .font(.system(size: emojiSize))
                Text(mood.title)
                    .font(ClayFont.callout())
                    .foregroundStyle(isOn ? ClayTheme.textOnAccent : ClayTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            // 위아래 12pt + 글씨 두 줄이면 70pt 가 넘는다. 44pt 는 최소선이지,
            // 매일 누르는 자리의 목표치가 아니다.
            .padding(.vertical, ClayTheme.Spacing.s)
            .padding(.horizontal, ClayTheme.Spacing.xs)
            .background {
                RoundedRectangle(cornerRadius: ClayTheme.Radius.control, style: .continuous)
                    .fill(isOn ? ClayTheme.accent : ClayTheme.surfaceRaised)
            }
            .overlay {
                RoundedRectangle(cornerRadius: ClayTheme.Radius.control, style: .continuous)
                    .strokeBorder(ClayTheme.accent, lineWidth: isOn ? 0 : 1)
                    // 고르지 않았을 때도 누를 수 있는 자리임이 보여야 한다.
                    .opacity(isOn ? 0 : 0.18)
            }
            .contentShape(RoundedRectangle(cornerRadius: ClayTheme.Radius.control, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(mood.title) 기분의 명언 보기")
        .accessibilityHint(mood.invitation)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    private func footer(_ mood: QuoteMood) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: ClayTheme.Spacing.xs) {
            Text(mood.invitation)
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button("되돌리기") {
                withAnimation { selection = nil }
            }
            .font(ClayFont.caption())
            .foregroundStyle(ClayTheme.accent)
            .accessibilityLabel("오늘의 명언으로 되돌리기")
        }
    }
}

#Preview("기분 고르기") {
    struct Harness: View {
        @State private var mood: QuoteMood?
        var body: some View {
            VStack {
                MoodPickerCard(selection: $mood)
            }
            .padding()
            .clayBackground()
        }
    }
    return Harness()
}

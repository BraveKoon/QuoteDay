import SwiftUI

/// "오늘 기분이 다르다면" — 지금 상태로 명언을 바꿔 고르는 줄.
///
/// 이것이 "AI 추천"의 자리를 대신한다. 추천은 취향을 알아맞히는 문제가 아니라
/// **지금 상태를 물어보는 문제**다. 사용자가 직접 고르는 편이 앱이 추측하는
/// 것보다 정확하고, 빠르고, 공짜다.
///
/// 고른 기분은 그날 기록에 함께 저장된다. 월간 회고의 "가장 많이 고른 기분"이
/// 거기서 나온다 — 기능 두 개가 서로를 먹여 살린다.
struct MoodPickerRow: View {
    /// 고른 기분으로 바꿔 보여 줄 명언. 고르지 않았으면 nil.
    @Binding var selection: QuoteMood?

    var body: some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.xs) {
            HStack {
                Text(selection.map(\.invitation) ?? "오늘 기분이 다르다면")
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.textSecondary)
                Spacer(minLength: 0)
                if selection != nil {
                    Button("오늘의 명언으로") {
                        withAnimation { selection = nil }
                    }
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.accent)
                }
            }

            ScrollView(.horizontal) {
                HStack(spacing: ClayTheme.Spacing.xs) {
                    ForEach(QuoteMood.allCases) { mood in
                        chip(mood)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func chip(_ mood: QuoteMood) -> some View {
        let isOn = selection == mood
        return Button {
            // 같은 것을 다시 누르면 해제한다.
            withAnimation { selection = isOn ? nil : mood }
        } label: {
            Text("\(mood.emoji) \(mood.title)")
                .font(ClayFont.caption())
                .foregroundStyle(isOn ? ClayTheme.textOnAccent : ClayTheme.textPrimary)
                .padding(.horizontal, ClayTheme.Spacing.s)
                .padding(.vertical, ClayTheme.Spacing.xs)
                .background {
                    RoundedRectangle(cornerRadius: ClayTheme.Radius.chip, style: .continuous)
                        .fill(isOn ? ClayTheme.accent : ClayTheme.surfaceRaised)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(mood.title) 기분의 명언 보기")
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}

import SwiftUI

/// 반복 주기를 고르는 칩 그리드. 일정 편집 화면에서 쓴다.
struct RecurrencePicker: View {
    @Binding var selection: RecurrenceFrequency

    private let columns = [GridItem(.adaptive(minimum: 84), spacing: ClayTheme.Spacing.s)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: ClayTheme.Spacing.s) {
            ForEach(RecurrenceFrequency.allCases) { frequency in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selection = frequency
                    }
                } label: {
                    Text(frequency.shortTitle)
                        .font(ClayFont.callout())
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ClayTheme.Spacing.s)
                        .foregroundStyle(
                            selection == frequency ? ClayTheme.textOnTint : ClayTheme.textSecondary
                        )
                }
                .buttonStyle(RecurrenceButtonStyle(isSelected: selection == frequency))
                .accessibilityLabel(frequency.title)
                .accessibilityAddTraits(selection == frequency ? [.isSelected, .isButton] : .isButton)
            }
        }
    }
}

private struct RecurrenceButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        Group {
            if isSelected {
                configuration.label
                    .clayCard(
                        cornerRadius: ClayTheme.Radius.control,
                        tint: ClayTheme.accent,
                        elevation: 10,
                        isPressed: configuration.isPressed
                    )
            } else {
                configuration.label
                    .claySunken(cornerRadius: ClayTheme.Radius.control)
                    .scaleEffect(configuration.isPressed ? 0.97 : 1)
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// 프리뷰에서 선택 상태를 보여 주기 위한 래퍼.
private struct RecurrencePickerPreview: View {
    @State private var selection: RecurrenceFrequency = .weekly

    var body: some View {
        VStack(spacing: ClayTheme.Spacing.m) {
            RecurrencePicker(selection: $selection)
            Text(RecurrenceRule(frequency: selection).summary(anchor: .now))
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
        }
        .padding(ClayTheme.Spacing.l)
        .clayBackground()
    }
}

#Preview("반복 선택") {
    RecurrencePickerPreview()
}

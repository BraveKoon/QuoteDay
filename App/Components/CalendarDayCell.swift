import SwiftUI

/// 월간 캘린더의 날짜 한 칸.
struct CalendarDayCell: View {
    let day: CalendarDay
    let dayNumber: Int
    let isSelected: Bool
    let isToday: Bool
    /// 그 날 일정들의 카테고리 색(최대 3개까지 점으로 표시).
    let categories: [AppCategory]
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text("\(dayNumber)")
                    .font(.system(size: 15, weight: isSelected || isToday ? .bold : .medium, design: .rounded))
                    .foregroundStyle(numberColor)
                    .monospacedDigit()

                HStack(spacing: 2.5) {
                    ForEach(Array(categories.prefix(3).enumerated()), id: \.offset) { _, category in
                        Circle()
                            .fill(isSelected ? Color.white.opacity(0.9) : category.tint)
                            .frame(width: 4.5, height: 4.5)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, ClayTheme.Spacing.xs + 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(CalendarDayButtonStyle(isSelected: isSelected, isToday: isToday))
        .opacity(day.isInDisplayedMonth ? 1 : 0.38)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.72), value: isSelected)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    private var numberColor: Color {
        if isSelected { return .white }
        if isToday { return ClayTheme.accent }
        return ClayTheme.textPrimary
    }

    private var accessibilityText: String {
        var text = Formatters.dayAndWeekday.string(from: day.date)
        if isToday { text += ", 오늘" }
        if !categories.isEmpty { text += ", 일정 \(categories.count)종류" }
        return text
    }
}

private struct CalendarDayButtonStyle: ButtonStyle {
    let isSelected: Bool
    let isToday: Bool

    func makeBody(configuration: Configuration) -> some View {
        Group {
            if isSelected {
                configuration.label
                    .clayCard(
                        cornerRadius: ClayTheme.Radius.tiny,
                        tint: ClayTheme.accent,
                        isPressed: configuration.isPressed
                    )
            } else if isToday {
                configuration.label
                    .background {
                        RoundedRectangle(cornerRadius: ClayTheme.Radius.tiny, style: .continuous)
                            .strokeBorder(ClayTheme.accent.opacity(0.6), lineWidth: 1.5)
                    }
                    .scaleEffect(configuration.isPressed ? 0.94 : 1)
            } else {
                configuration.label
                    .scaleEffect(configuration.isPressed ? 0.94 : 1)
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

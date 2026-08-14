import SwiftUI

/// 일정 한 줄. 홈의 "오늘의 일정"과 캘린더 하단 목록에서 함께 쓴다.
struct ScheduleRow: View {
    let item: ScheduleItem
    var showsCountdown: Bool = false
    var onTap: (() -> Void)?
    var onDelete: (() -> Void)?
    var onShuffleQuote: (() -> Void)?

    @State private var isPressed = false

    var body: some View {
        Button {
            onTap?()
        } label: {
            content
        }
        .buttonStyle(PressReportingStyle(isPressed: $isPressed))
        .disabled(onTap == nil)
        .contextMenu {
            if let onShuffleQuote {
                Button {
                    onShuffleQuote()
                } label: {
                    Label("다른 명언 배정", systemImage: "arrow.triangle.2.circlepath")
                }
            }
            if let onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("일정 삭제", systemImage: "trash")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint(onTap == nil ? "" : "두 번 탭하면 일정을 편집합니다.")
    }

    private var content: some View {
        HStack(spacing: ClayTheme.Spacing.s) {
            VStack(spacing: 2) {
                Text(Formatters.time.string(from: item.startDate))
                    .font(ClayFont.headline())
                    .foregroundStyle(ClayTheme.textPrimary)
                if item.duration > 0 {
                    Text(Formatters.time.string(from: item.endDate))
                        .font(ClayFont.caption())
                        .foregroundStyle(ClayTheme.textSecondary)
                }
            }
            .frame(minWidth: 56)
            .padding(.vertical, ClayTheme.Spacing.xs)
            .padding(.horizontal, ClayTheme.Spacing.xs)
            .claySunken(cornerRadius: ClayTheme.Radius.tiny)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: ClayTheme.Spacing.xs) {
                    Text(item.category.emoji)
                    Text(item.displayTitle)
                        .font(ClayFont.headline())
                        .foregroundStyle(ClayTheme.textPrimary)
                        .lineLimit(2)
                }

                HStack(spacing: ClayTheme.Spacing.xs) {
                    Text(item.category.title)
                        .font(ClayFont.caption())
                        .foregroundStyle(ClayTheme.textSecondary)

                    if item.isQuoteNotificationEnabled {
                        Label("명언 알림", systemImage: "bell.fill")
                            .font(ClayFont.caption())
                            .labelStyle(.iconOnly)
                            .foregroundStyle(ClayTheme.accent)
                    }

                    if showsCountdown, let countdown = Formatters.countdown(to: item.startDate) {
                        Text(countdown)
                            .font(ClayFont.caption())
                            .foregroundStyle(ClayTheme.accent)
                    }
                }
            }

            Spacer(minLength: 0)

            Circle()
                .fill(item.category.tint)
                .frame(width: 10, height: 10)
        }
        .padding(ClayTheme.Spacing.s + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clayCard(cornerRadius: ClayTheme.Radius.control, elevation: 9, isPressed: isPressed)
    }

    private var accessibilityText: String {
        var parts = [
            Formatters.timeRange(item.startDate, item.endDate),
            item.displayTitle,
            item.category.title
        ]
        if item.isQuoteNotificationEnabled { parts.append("명언 알림 켜짐") }
        if showsCountdown, let countdown = Formatters.countdown(to: item.startDate) {
            parts.append(countdown)
        }
        return parts.joined(separator: ", ")
    }
}

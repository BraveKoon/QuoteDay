import SwiftUI
import WidgetKit

/// 위젯 본문. 크기별로 정보량을 조절하되 디자인 언어는 앱과 동일하게 맞춘다.
///
/// 위젯은 정적 렌더링이므로 애니메이션은 넣지 않고 입체감만 유지한다.
struct QuoteWidgetEntryView: View {
    let entry: QuoteEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .systemSmall: small
            case .systemLarge: large
            default: medium
            }
        }
        .widgetURL(entry.deepLink)
    }

    // MARK: - Small : 명언만

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.quote.category.emoji)
                    .font(.system(size: 13))
                Spacer()
                Image(systemName: "quote.opening")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(ClayTheme.textSecondary.opacity(0.6))
            }

            Text(entry.quote.text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(ClayTheme.textPrimary)
                .lineLimit(5)
                .minimumScaleFactor(0.75)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)

            Text("— \(entry.author.displayName)")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(ClayTheme.textSecondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clayCard(cornerRadius: 24, elevation: 8)
        .padding(8)
    }

    // MARK: - Medium : 명언 + 인물 + 카테고리

    private var medium: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                categoryBadge

                Text(entry.quote.text)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(ClayTheme.textPrimary)
                    .lineLimit(4)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 1) {
                    Text("— \(entry.author.displayName)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(ClayTheme.textPrimary)
                    Text(entry.author.occupation)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(ClayTheme.textSecondary)
                        .lineLimit(1)
                }
            }

            portrait(size: 54)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clayCard(cornerRadius: 26, elevation: 8)
        .padding(8)
    }

    // MARK: - Large : 명언 + 인물 + 오늘의 일정

    private var large: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    categoryBadge
                    Text(entry.quote.text)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(ClayTheme.textPrimary)
                        .lineLimit(5)
                        .minimumScaleFactor(0.8)
                    Text("— \(entry.author.displayName)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(ClayTheme.textSecondary)
                }
                Spacer(minLength: 0)
                portrait(size: 56)
            }

            Divider().opacity(0.25)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("오늘의 일정")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(ClayTheme.textSecondary)
                    Spacer()
                    if let next = entry.nextSchedule,
                       let countdown = Formatters.countdown(to: next.start, from: entry.date) {
                        Text(countdown)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(ClayTheme.accent)
                    }
                }

                if entry.todaySchedules.isEmpty {
                    Text("등록된 일정이 없어요. 앱에서 일정을 추가해 보세요.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(ClayTheme.textSecondary)
                        .lineLimit(2)
                } else {
                    ForEach(entry.todaySchedules.prefix(3), id: \.occurrenceKey) { schedule in
                        scheduleRow(schedule)
                    }
                    if entry.todaySchedules.count > 3 {
                        Text("외 \(entry.todaySchedules.count - 3)개")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(ClayTheme.textSecondary)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clayCard(cornerRadius: 30, elevation: 10)
        .padding(8)
    }

    // MARK: - 조각

    private var categoryBadge: some View {
        HStack(spacing: 4) {
            Text(entry.quote.category.emoji)
                .font(.system(size: 10))
            Text(entry.quote.category.title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(ClayTheme.textOnTint)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background {
            Capsule().fill(ClayTheme.tintedGradient(entry.quote.category.tint))
        }
    }

    private func portrait(size: CGFloat) -> some View {
        ZStack {
            Circle().fill(
                LinearGradient(
                    colors: [entry.quote.category.tint.opacity(0.9), entry.quote.category.tint.opacity(0.5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            Text(entry.author.initials)
                .font(.system(size: size * 0.34, weight: .bold, design: .rounded))
                .foregroundStyle(ClayTheme.textOnTint)
        }
        .frame(width: size, height: size)
        .overlay { Circle().strokeBorder(ClayTheme.strokeLight, lineWidth: 1) }
    }

    private func scheduleRow(_ schedule: ScheduleSnapshot) -> some View {
        HStack(spacing: 7) {
            Text(schedule.category.emoji)
                .font(.system(size: 11))
            Text(schedule.title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(ClayTheme.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(Formatters.time.string(from: schedule.start))
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(ClayTheme.textSecondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(ClayTheme.sunkenGradient)
        }
    }
}

#Preview("Small", as: .systemSmall) {
    QuoteWidget()
} timeline: {
    QuoteEntry.placeholder()
}

#Preview("Medium", as: .systemMedium) {
    QuoteWidget()
} timeline: {
    QuoteEntry.placeholder()
}

#Preview("Large", as: .systemLarge) {
    QuoteWidget()
} timeline: {
    QuoteEntry.placeholder()
}

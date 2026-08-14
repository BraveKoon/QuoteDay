import AppIntents
import SwiftUI
import WidgetKit

/// 잠금화면 · 대기 화면(StandBy) 위젯.
///
/// 홈 화면 위젯과 타임라인 프로바이더를 공유하지만 별도의 `kind` 로 등록한다.
/// accessory 패밀리는 시스템이 색을 걷어내고 단색으로 그리기 때문에
/// 클레이 표면·그림자를 쓸 수 없고, 정보 밀도와 대비만 남겨야 한다.
struct QuoteLockScreenWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: AppGroup.lockScreenWidgetKind,
            intent: SelectQuoteCategoryIntent.self,
            provider: QuoteTimelineProvider()
        ) { entry in
            LockScreenWidgetView(entry: entry)
                // 잠금화면 위젯은 시스템이 배경을 관리하므로 비워 둔다.
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("잠금화면 명언")
        .description("잠금화면과 대기 화면에서 오늘의 명언과 다음 일정을 확인합니다.")
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

struct LockScreenWidgetView: View {
    let entry: QuoteEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .accessoryInline: inline
            case .accessoryCircular: circular
            default: rectangular
            }
        }
        .widgetURL(entry.deepLink)
    }

    // MARK: - Inline : 시계 위 한 줄

    /// 한 줄뿐이라 가장 시급한 정보를 고른다.
    /// 다음 일정이 있으면 일정을, 없으면 명언을 보여 준다.
    private var inline: some View {
        Text(inlineText)
    }

    private var inlineText: String {
        if let next = entry.nextSchedule {
            return "\(next.category.emoji) \(timeLabel(for: next.start)) \(next.title)"
        }
        return entry.quote.text
    }

    // MARK: - Circular : 원형

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()

            if let next = entry.nextSchedule {
                VStack(spacing: 1) {
                    Image(systemName: next.category.symbolName)
                        .font(.system(size: 13, weight: .semibold))
                    Text(Formatters.time.string(from: next.start))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
            } else {
                VStack(spacing: 1) {
                    Image(systemName: "quote.bubble.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text(entry.author.initials)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .lineLimit(1)
                }
            }
        }
        .widgetAccentable()
        .accessibilityLabel(circularAccessibilityLabel)
    }

    private var circularAccessibilityLabel: String {
        if let next = entry.nextSchedule {
            return "다음 일정 \(next.title), \(Formatters.time.string(from: next.start))"
        }
        return "오늘의 명언, \(entry.author.displayName)"
    }

    // MARK: - Rectangular : 3줄

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 3) {
                Image(systemName: headerSymbol)
                    .font(.system(size: 11, weight: .bold))
                Text(headerText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }
            .widgetAccentable()

            Text(entry.quote.text)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Text("— \(entry.author.displayName)")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(headerText). \(entry.quote.text). \(entry.author.displayName)")
    }

    private var headerSymbol: String {
        entry.nextSchedule?.category.symbolName ?? "quote.opening"
    }

    private var headerText: String {
        if let next = entry.nextSchedule {
            return "\(timeLabel(for: next.start)) \(next.title)"
        }
        return "오늘의 명언"
    }

    // MARK: - 도우미

    /// 오늘이 아니면 날짜를 알 수 있게 접두사를 붙인다.
    private func timeLabel(for date: Date, calendar: Calendar = .current) -> String {
        let time = Formatters.time.string(from: date)
        if calendar.isDateInToday(date) { return time }
        if calendar.isDateInTomorrow(date) { return "내일 \(time)" }
        return "\(Formatters.dayAndWeekday.string(from: date)) \(time)"
    }
}

#Preview("Inline", as: .accessoryInline) {
    QuoteLockScreenWidget()
} timeline: {
    QuoteEntry.placeholder()
}

#Preview("Circular", as: .accessoryCircular) {
    QuoteLockScreenWidget()
} timeline: {
    QuoteEntry.placeholder()
}

#Preview("Rectangular", as: .accessoryRectangular) {
    QuoteLockScreenWidget()
} timeline: {
    QuoteEntry.placeholder()
}

import AppIntents
import SwiftUI
import WidgetKit

/// 위젯 한 칸에 필요한 모든 값.
struct QuoteEntry: TimelineEntry {
    let date: Date
    let quote: Quote
    let author: Author
    /// 오늘의 일정(라지 위젯용).
    let todaySchedules: [ScheduleSnapshot]
    let nextSchedule: ScheduleSnapshot?

    var deepLink: URL { DeepLink.quote(quote.id).url }

    static func placeholder(date: Date = .now) -> QuoteEntry {
        let service = QuoteService.shared
        let quote = service.quoteOfTheDay(for: date)
        return QuoteEntry(
            date: date,
            quote: quote,
            author: service.author(for: quote),
            todaySchedules: [],
            nextSchedule: nil
        )
    }
}

/// 타임라인 생성.
///
/// 위젯 프로세스는 앱과 별개로 동작하므로 명언은 번들 데이터에서 **직접 계산**하고,
/// 일정만 App Group 스냅샷에서 읽는다. 스냅샷이 없어도 명언은 항상 표시된다.
struct QuoteTimelineProvider: AppIntentTimelineProvider {
    private let quoteService = QuoteService.shared
    private let snapshotStore = WidgetSnapshotStore()

    func placeholder(in context: Context) -> QuoteEntry {
        .placeholder()
    }

    func snapshot(for configuration: SelectQuoteCategoryIntent, in context: Context) async -> QuoteEntry {
        makeEntry(at: .now, configuration: configuration)
    }

    func timeline(
        for configuration: SelectQuoteCategoryIntent,
        in context: Context
    ) async -> Timeline<QuoteEntry> {
        let now = Date.now
        let calendar = Calendar.current
        let midnight = now.nextMidnight(calendar: calendar)

        // 남은 시간과 "다음 일정"이 자연스럽게 갱신되도록 한 시간 간격으로 항목을 만든다.
        var entries: [QuoteEntry] = [makeEntry(at: now, configuration: configuration)]
        var cursor = calendar.date(bySetting: .minute, value: 0, of: now.addingTimeInterval(3600)) ?? midnight
        while cursor < midnight && entries.count < 24 {
            entries.append(makeEntry(at: cursor, configuration: configuration))
            guard let next = calendar.date(byAdding: .hour, value: 1, to: cursor) else { break }
            cursor = next
        }

        // 자정에 새 명언으로 바뀌어야 하므로 그 시점에 타임라인을 다시 요청한다.
        return Timeline(entries: entries, policy: .after(midnight))
    }

    private func makeEntry(at date: Date, configuration: SelectQuoteCategoryIntent) -> QuoteEntry {
        let quote = quoteService.quoteOfTheDay(for: date, preferred: configuration.category.category)
        let snapshot = snapshotStore.load()
        return QuoteEntry(
            date: date,
            quote: quote,
            author: quoteService.author(for: quote),
            todaySchedules: snapshot.schedules(on: date),
            nextSchedule: snapshot.nextSchedule(after: date)
        )
    }
}

struct QuoteWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: AppGroup.widgetKind,
            intent: SelectQuoteCategoryIntent.self,
            provider: QuoteTimelineProvider()
        ) { entry in
            QuoteWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [ClayTheme.backgroundTop, ClayTheme.backgroundBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("오늘의 명언")
        .description("매일 자정에 바뀌는 명언과 오늘의 일정을 보여 줍니다.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

@main
struct QuoteDayWidgetBundle: WidgetBundle {
    var body: some Widget {
        QuoteWidget()
    }
}

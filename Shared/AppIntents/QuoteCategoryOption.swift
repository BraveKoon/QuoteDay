import AppIntents

/// 위젯 편집 화면에서 고를 수 있는 카테고리.
///
/// `AppCategory` 를 그대로 `AppEnum` 으로 만들면 "전체" 선택지를 넣을 수 없어
/// 위젯 전용 래퍼를 둔다.
enum QuoteCategoryOption: String, AppEnum, CaseIterable {
    case all
    case work, leisure, meal, study, exercise, health, relationship, growth, daily

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "명언 카테고리")
    }

    static var caseDisplayRepresentations: [QuoteCategoryOption: DisplayRepresentation] {
        var representations: [QuoteCategoryOption: DisplayRepresentation] = [
            .all: DisplayRepresentation(title: "✨ 전체")
        ]
        for option in allCases where option != .all {
            if let category = option.category {
                representations[option] = DisplayRepresentation(
                    title: LocalizedStringResource(stringLiteral: category.displayName)
                )
            }
        }
        return representations
    }

    /// `all` 이면 nil.
    var category: AppCategory? {
        guard self != .all else { return nil }
        return AppCategory(rawValue: rawValue)
    }
}

/// 위젯 구성 인텐트. 사용자가 위젯을 길게 눌러 카테고리를 바꿀 수 있다.
struct SelectQuoteCategoryIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "오늘의 명언" }
    static var description: IntentDescription {
        IntentDescription("홈 화면에서 오늘의 명언을 확인합니다.")
    }

    @Parameter(title: "카테고리", default: .all)
    var category: QuoteCategoryOption

    init() {}

    init(category: QuoteCategoryOption) {
        self.category = category
    }
}

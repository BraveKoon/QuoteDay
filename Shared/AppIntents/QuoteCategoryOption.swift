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

    /// AppIntents 는 이 값을 **컴파일 타임에 메타데이터로 추출**하므로
    /// 반드시 모든 케이스를 담은 리터럴이어야 한다. 루프나 계산으로 만들 수 없다.
    /// 케이스를 추가하면 여기에도 반드시 한 줄 추가해야 한다.
    static var caseDisplayRepresentations: [QuoteCategoryOption: DisplayRepresentation] {
        [
            .all: DisplayRepresentation(title: "✨ 전체"),
            .work: DisplayRepresentation(title: "💼 직장"),
            .leisure: DisplayRepresentation(title: "🎮 여가"),
            .meal: DisplayRepresentation(title: "🍽 식사"),
            .study: DisplayRepresentation(title: "📚 학업"),
            .exercise: DisplayRepresentation(title: "🏃 운동"),
            .health: DisplayRepresentation(title: "❤️ 건강"),
            .relationship: DisplayRepresentation(title: "👥 인간관계"),
            .growth: DisplayRepresentation(title: "💡 자기계발"),
            .daily: DisplayRepresentation(title: "🏠 일상")
        ]
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

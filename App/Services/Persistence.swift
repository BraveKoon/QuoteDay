import Foundation
import SwiftData

/// SwiftData 컨테이너 생성.
///
/// App Group → 앱 전용 저장소 → 메모리 순으로 단계적으로 내려간다.
/// 프로비저닝이 아직 안 된 개발 초기나 스토어가 손상된 경우에도
/// 앱이 실행되지 않는 상황을 만들지 않기 위함이다.
enum Persistence {
    static let schema = Schema([ScheduleItem.self])

    /// 앱 전역에서 쓰는 컨테이너.
    static let shared: ModelContainer = makeContainer()

    static func makeContainer() -> ModelContainer {
        if AppGroup.isConfigured {
            let configuration = ModelConfiguration(
                schema: schema,
                groupContainer: .identifier(AppGroup.identifier)
            )
            if let container = try? ModelContainer(for: schema, configurations: configuration) {
                return container
            }
            AppLog.schedule.error("App Group 컨테이너를 열지 못해 로컬 저장소로 대체합니다.")
        }

        let local = ModelConfiguration(schema: schema)
        if let container = try? ModelContainer(for: schema, configurations: local) {
            return container
        }

        AppLog.schedule.fault("영구 저장소를 열지 못해 메모리 저장소로 실행합니다. 이번 실행의 일정은 저장되지 않습니다.")
        let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        // 메모리 컨테이너까지 실패하면 복구할 방법이 없다.
        // swiftlint:disable:next force_try
        return try! ModelContainer(for: schema, configurations: memory)
    }

    /// 테스트/프리뷰용 인메모리 컨테이너.
    static func makeInMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
    }
}

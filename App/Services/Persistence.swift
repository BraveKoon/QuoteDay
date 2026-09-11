import Foundation
import SwiftData

/// SwiftData 컨테이너 생성.
///
/// App Group → 앱 전용 저장소 → 메모리 순으로 단계적으로 내려간다.
/// 프로비저닝이 아직 안 된 개발 초기나 스토어가 손상된 경우에도
/// 앱이 실행되지 않는 상황을 만들지 않기 위함이다.
///
/// **모든 설정에 `cloudKitDatabase: .none` 을 명시한다.** 기본값이 `.automatic`
/// 이라서, 앱에 iCloud 엔타이틀먼트가 붙어 있으면 SwiftData 가 일정과 노트까지
/// 알아서 CloudKit 에 올리려 든다. 그런데 그러려면 스키마가 CloudKit 규칙을
/// 지켜야 한다 — 모든 속성이 옵셔널이거나 기본값이 있어야 하고, 유일성 제약
/// (`@Attribute(.unique)`)을 쓸 수 없다. 우리 모델은 둘 다 어긴다.
///
///     CloudKit integration requires that all attributes be optional,
///     or have a default value set.
///
/// v1.8.2 에서 하트용 iCloud 엔타이틀먼트를 켜자 이 검증이 시작되어 세 단계
/// 폴백이 모두 실패했고, 마지막 `try!` 에서 앱이 실행 즉시 죽었다.
///
/// 하트와 랭킹은 **공개 데이터베이스**를 `CKContainer` 로 직접 쓴다
/// (`CloudKitHeartService`). SwiftData 쪽 동기화는 별개의 결정이고 아직 하지
/// 않는다 — 개인의 일정과 노트를 올리는 일이라 스키마와 사생활을 함께 따져야 한다.
enum Persistence {
    static let schema = Schema([ScheduleItem.self, QuoteNote.self])

    /// 앱 전역에서 쓰는 컨테이너.
    static let shared: ModelContainer = makeContainer()

    static func makeContainer() -> ModelContainer {
        if AppGroup.isConfigured {
            let configuration = ModelConfiguration(
                schema: schema,
                groupContainer: .identifier(AppGroup.identifier),
                cloudKitDatabase: .none
            )
            if let container = try? ModelContainer(for: schema, configurations: configuration) {
                return container
            }
            AppLog.schedule.error("App Group 컨테이너를 열지 못해 로컬 저장소로 대체합니다.")
        }

        let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        if let container = try? ModelContainer(for: schema, configurations: local) {
            return container
        }

        AppLog.schedule.fault("영구 저장소를 열지 못해 메모리 저장소로 실행합니다. 이번 실행의 일정은 저장되지 않습니다.")
        let memory = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        // 메모리 컨테이너까지 실패하면 복구할 방법이 없다.
        // swiftlint:disable:next force_try
        return try! ModelContainer(for: schema, configurations: memory)
    }

    /// 테스트/프리뷰용 인메모리 컨테이너.
    static func makeInMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        )
    }
}

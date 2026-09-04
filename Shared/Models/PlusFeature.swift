import Foundation

/// Quote Plus 로 잠기는 기능 목록.
///
/// 잠금 판단을 화면에 흩어 두면 "어디가 유료인지"를 코드에서 셀 수 없게 된다.
/// 게이트가 필요한 곳은 모두 이 열거형을 통해 `PlusStore.isUnlocked(_:)` 를 묻는다.
public enum PlusFeature: String, CaseIterable, Identifiable, Sendable {
    /// 인물의 생애·업적·시대적 배경 프로필.
    case authorProfile
    /// 명언이 나온 상황과 맥락.
    case behindStory
    /// 관련 저서·연관 인물 추천.
    case relatedWorks
    /// 노트를 PDF 로 내보내기.
    case noteExport
    /// 공유 카드의 프리미엄 테마·서체.
    case premiumShareTheme
    /// 공유 카드에서 워터마크 제거.
    case watermarkFree

    public var id: String { rawValue }

    /// 페이월에서 이 기능을 소개할 때 쓰는 제목.
    public var title: String {
        switch self {
        case .authorProfile: "인물 프로필"
        case .behindStory: "비하인드 스토리"
        case .relatedWorks: "관련 저서와 연관 인물"
        case .noteExport: "노트 PDF 내보내기"
        case .premiumShareTheme: "프리미엄 카드 테마"
        case .watermarkFree: "워터마크 없는 공유"
        }
    }

    public var detail: String {
        switch self {
        case .authorProfile: "생애, 주요 업적, 활동한 시대를 한 장에 정리해 드려요."
        case .behindStory: "이 문장이 어떤 상황에서 나왔는지 배경을 읽어 보세요."
        case .relatedWorks: "인물의 저서와 이어서 볼 만한 인물·명언을 추천해요."
        case .noteExport: "적어 둔 생각을 예쁜 PDF 한 권으로 내보낼 수 있어요."
        case .premiumShareTheme: "감성 배경과 프리미엄 서체로 카드를 꾸며 보세요."
        case .watermarkFree: "공유 카드에서 QuoteDay 표시를 뺄 수 있어요."
        }
    }

    public var symbol: String {
        switch self {
        case .authorProfile: "person.text.rectangle"
        case .behindStory: "book.closed"
        case .relatedWorks: "books.vertical"
        case .noteExport: "square.and.arrow.up.on.square"
        case .premiumShareTheme: "paintpalette"
        case .watermarkFree: "sparkles"
        }
    }
}

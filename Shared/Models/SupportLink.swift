import Foundation

/// 개발자 후원 링크.
///
/// 후원은 인앱 결제가 아니라 외부 링크로 받는다. 애플 정책상 앱 기능을 여는 대가로
/// 외부 결제를 받을 수는 없지만, **아무것도 대가로 주지 않는 순수한 기부**는
/// 외부 링크로 받을 수 있다. 그래서 후원에는 어떤 기능도 붙이지 않는다.
/// 기능이 필요한 사람은 Quote Plus 를 사면 된다.
public struct SupportLink: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let symbol: String
    public let url: URL

    public init(id: String, title: String, symbol: String, url: URL) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.url = url
    }

    /// 설정 화면에 노출할 후원 수단.
    ///
    /// ⚠️ 아래 주소는 **자리표시자**다. 배포 전에 본인 계정 주소로 바꿔야 한다.
    /// 링크가 죽어 있으면 후원 카드는 그냥 없는 편이 낫다.
    public static let all: [SupportLink] = [
        SupportLink(
            id: "buymeacoffee",
            title: "커피 한 잔 사주기",
            symbol: "cup.and.saucer.fill",
            url: URL(string: "https://buymeacoffee.com/quoteday")!
        ),
        SupportLink(
            id: "toss",
            title: "토스로 보내기",
            symbol: "wonsign.circle.fill",
            url: URL(string: "https://toss.me/quoteday")!
        )
    ]
}

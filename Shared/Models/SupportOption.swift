import Foundation

/// 개발자 후원 수단.
///
/// 후원에는 어떤 기능도 붙이지 않는다. 기능이 필요한 사람은 Quote Plus 를 사면 된다.
/// (기능을 대가로 외부 결제를 받으면 App Store 정책 위반이다.)
public struct SupportOption: Identifiable, Hashable, Sendable {
    /// 후원을 받는 방식.
    public enum Kind: Hashable, Sendable {
        /// 눌러서 브라우저로 나가는 링크.
        case link(URL)
        /// 화면에 적어 두고 눌러서 복사하는 계좌.
        /// - Parameters:
        ///   - bank: 은행 이름
        ///   - number: 계좌번호
        ///   - holder: 예금주
        case account(bank: String, number: String, holder: String)
    }

    public let id: String
    public let title: String
    public let symbol: String
    public let kind: Kind

    public init(id: String, title: String, symbol: String, kind: Kind) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.kind = kind
    }

    /// 복사 버튼이 넣어 줄 문자열. 계좌가 아니면 nil.
    public var copyableText: String? {
        guard case .account(let bank, let number, _) = kind else { return nil }
        return "\(bank) \(number)"
    }

    /// 계좌를 한 줄로 보여 줄 때 쓰는 표기.
    public var accountLine: String? {
        guard case .account(let bank, let number, let holder) = kind else { return nil }
        return "\(bank) \(number) · \(holder)"
    }

    public var url: URL? {
        guard case .link(let url) = kind else { return nil }
        return url
    }
}

public extension SupportOption {
    /// 설정 화면에 노출할 후원 수단.
    ///
    /// 계좌번호는 앱에 그대로 실려 나가는 공개 정보다. 바꿀 때는 반드시 두 번 확인할 것 —
    /// 한 자리만 틀려도 후원금이 남의 계좌로 간다.
    ///
    /// ⚠️ Buy Me a Coffee 주소는 아직 **자리표시자**다.
    static let all: [SupportOption] = [
        SupportOption(
            id: "toss-account",
            title: "토스로 보내기",
            symbol: "wonsign.circle.fill",
            kind: .account(bank: "토스뱅크", number: "1908-1161-1257", holder: "전우진")
        ),
        SupportOption(
            id: "buymeacoffee",
            title: "커피 한 잔 사주기",
            symbol: "cup.and.saucer.fill",
            kind: .link(URL(string: "https://buymeacoffee.com/quoteday")!)
        )
    ]
}

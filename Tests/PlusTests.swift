import XCTest
@testable import QuoteDay

/// Quote Plus 관련 순수 로직 검증.
///
/// 결제 자체(StoreKit)는 시뮬레이터의 StoreKit 설정 파일이 있어야 검증할 수 있어
/// 여기서는 다루지 않는다. 대신 **잠금 판단과 데이터 규칙**을 지킨다.
final class PlusTests: XCTestCase {

    // MARK: - 기능 목록

    func testEveryPlusFeatureHasCopy() {
        for feature in PlusFeature.allCases {
            XCTAssertFalse(feature.title.isEmpty, "\(feature.rawValue) 에 제목이 없다.")
            XCTAssertFalse(feature.detail.isEmpty, "\(feature.rawValue) 에 설명이 없다.")
            XCTAssertFalse(feature.symbol.isEmpty, "\(feature.rawValue) 에 아이콘이 없다.")
        }
    }

    func testPlusFeatureIDsAreUnique() {
        let ids = Set(PlusFeature.allCases.map(\.id))
        XCTAssertEqual(ids.count, PlusFeature.allCases.count)
    }

    // MARK: - 공유 카드 테마

    func testFreeAndPremiumThemesPartitionAllCases() {
        XCTAssertEqual(
            ShareCardTheme.free.count + ShareCardTheme.premium.count,
            ShareCardTheme.allCases.count
        )
        XCTAssertFalse(ShareCardTheme.free.isEmpty, "무료 테마가 하나도 없으면 무료 공유가 막힌다.")
        XCTAssertFalse(ShareCardTheme.premium.isEmpty, "유료 테마가 없으면 팔 것이 없다.")
    }

    func testFreeThemesNeverRequirePlus() {
        for theme in ShareCardTheme.free {
            XCTAssertFalse(theme.requiresPlus)
        }
    }

    func testUnknownStoredThemeDegradesToDefault() {
        XCTAssertEqual(ShareCardTheme(storedValue: nil), .paper)
        XCTAssertEqual(ShareCardTheme(storedValue: "미래버전테마"), .paper)
        XCTAssertEqual(ShareCardTheme(storedValue: "forest"), .forest)
    }

    func testEveryThemeHasTitle() {
        for theme in ShareCardTheme.allCases {
            XCTAssertFalse(theme.title.isEmpty)
        }
    }

    // MARK: - 비하인드 스토리 데이터

    func testEveryBehindStoryPointsAtAnExistingQuote() {
        for story in BehindStoryLibrary.all {
            XCTAssertNotNil(
                QuoteService.shared.quote(slug: story.quoteSlug),
                "\(story.quoteSlug) 에 해당하는 명언이 없다. 배경만 남으면 화면에 뜨지 않는다."
            )
        }
    }

    func testEveryBehindStoryCitesASource() {
        for story in BehindStoryLibrary.all {
            XCTAssertFalse(
                story.source.trimmingCharacters(in: .whitespaces).isEmpty,
                "\(story.quoteSlug) 에 출처가 없다. 확인되지 않은 배경은 넣지 않는다."
            )
            XCTAssertFalse(story.occasion.isEmpty)
            XCTAssertFalse(story.context.isEmpty)
        }
    }

    func testBehindStorySlugsAreUnique() {
        let slugs = BehindStoryLibrary.all.map(\.quoteSlug)
        XCTAssertEqual(Set(slugs).count, slugs.count)
    }

    func testStoryLookupMissesGracefully() {
        XCTAssertNil(BehindStoryLibrary.story(for: "존재하지-않는-슬러그"))
        if let first = BehindStoryLibrary.all.first {
            XCTAssertEqual(BehindStoryLibrary.story(for: first.quoteSlug)?.quoteSlug, first.quoteSlug)
        }
    }

    // MARK: - 인물 확장 필드

    func testAuthorEraAndWorksDefaultToEmpty() {
        let author = Author(
            id: "test",
            name: "테스트",
            birthYear: 1900,
            occupation: "작가",
            nationality: "대한민국",
            biography: "설명"
        )
        XCTAssertNil(author.era)
        XCTAssertTrue(author.notableWorks.isEmpty)
    }

    // MARK: - 노트

    func testNotePreviewTruncatesLongText() {
        let note = QuoteNote(
            quoteSlug: "s",
            quoteTextSnapshot: "명언",
            authorNameSnapshot: "인물",
            text: String(repeating: "가", count: 200)
        )
        XCTAssertTrue(note.preview.hasSuffix("…"))
        XCTAssertLessThanOrEqual(note.preview.count, 81)
    }

    func testNotePreviewFlattensNewlines() {
        let note = QuoteNote(
            quoteSlug: "s",
            quoteTextSnapshot: "명언",
            authorNameSnapshot: "인물",
            text: "첫 줄\n둘째 줄"
        )
        XCTAssertEqual(note.preview, "첫 줄 둘째 줄")
        XCTAssertFalse(note.preview.contains("\n"))
    }

    func testBlankNoteIsEmpty() {
        let note = QuoteNote(
            quoteSlug: "s",
            quoteTextSnapshot: "명언",
            authorNameSnapshot: "인물",
            text: "   \n  "
        )
        XCTAssertTrue(note.isEmpty)
    }

    // MARK: - 후원 수단

    func testSupportOptionsAreWellFormed() {
        XCTAssertFalse(SupportOption.all.isEmpty)
        for option in SupportOption.all {
            XCTAssertFalse(option.title.isEmpty)
            if let url = option.url {
                XCTAssertEqual(url.scheme, "https", "후원 링크는 https 여야 한다.")
            }
        }
        let ids = Set(SupportOption.all.map(\.id))
        XCTAssertEqual(ids.count, SupportOption.all.count)
    }

    func testAccountOptionExposesCopyableTextAndLinkDoesNot() {
        let account = SupportOption(
            id: "a", title: "계좌", symbol: "wonsign.circle.fill",
            kind: .account(bank: "토스뱅크", number: "1000-0000-0000", holder: "홍길동")
        )
        XCTAssertEqual(account.copyableText, "토스뱅크 1000-0000-0000")
        XCTAssertEqual(account.accountLine, "토스뱅크 1000-0000-0000 · 홍길동")
        XCTAssertNil(account.url, "계좌는 여는 링크가 아니다.")

        let link = SupportOption(
            id: "b", title: "링크", symbol: "cup.and.saucer.fill",
            kind: .link(URL(string: "https://example.com")!)
        )
        XCTAssertNil(link.copyableText)
        XCTAssertNil(link.accountLine)
        XCTAssertNotNil(link.url)
    }

    func testAtLeastOneAccountIsOffered() {
        let hasAccount = SupportOption.all.contains { $0.copyableText != nil }
        XCTAssertTrue(hasAccount, "계좌 이체를 원하는 사람을 위한 수단이 하나는 있어야 한다.")
    }

    // MARK: - 상품 식별자

    // `PlusStore` 가 @MainActor 라 중첩 타입도 같은 격리를 따른다.
    @MainActor
    func testProductIDsAreUniqueAndPrefixed() {
        let ids = PlusStore.ProductID.all
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertEqual(ids.first, PlusStore.ProductID.monthly, "월정액을 먼저 보여 준다.")
        for id in ids {
            XCTAssertTrue(id.hasPrefix("com.quoteday."), "\(id) 가 번들 접두사를 따르지 않는다.")
        }
    }
}

import XCTest
@testable import QuoteDay

/// 앱 화면의 버전과 깃허브 릴리스 태그가 어긋나지 않는지 본다.
///
/// 어긋나면 사용자는 자기가 쓰는 것이 어느 버전인지 확인할 방법이 없고,
/// "변경 이력"에서 자기 버전을 못 찾는다. 세 곳(번들 · CHANGELOG · 태그)을
/// 한 줄로 묶어 두는 것이 이 파일의 목적이다.
///
/// 여기서는 앱이 들고 있는 값끼리 대조하고, `project.yml`·`CHANGELOG.md` 와의
/// 대조는 `tools/check_project.py` 가 한다 — 그쪽은 저장소 파일을 직접 읽는다.
final class ReleaseHistoryTests: XCTestCase {

    // MARK: - 목록 자체

    func testHistoryIsNotEmpty() {
        XCTAssertFalse(ReleaseHistory.all.isEmpty, "변경 이력이 비어 있으면 화면이 빈 채로 뜬다.")
    }

    func testVersionsAreUnique() {
        let versions = ReleaseHistory.all.map(\.version)
        XCTAssertEqual(Set(versions).count, versions.count, "같은 버전이 두 번 실렸다.")
    }

    /// 최신이 앞. 화면이 정렬하지 않고 그대로 그리므로 데이터가 순서를 지켜야 한다.
    func testHistoryIsNewestFirst() {
        let numbers = ReleaseHistory.all.map(components(of:))
        for (newer, older) in zip(numbers, numbers.dropFirst()) {
            XCTAssertTrue(
                isDescending(newer, older),
                "버전 순서가 어긋났다: \(newer) 다음에 \(older)"
            )
        }
    }

    func testEveryReleaseHasSomethingToShow() {
        for release in ReleaseHistory.all {
            let hasBody = release.summary != nil || !release.sections.isEmpty
            XCTAssertTrue(hasBody, "\(release.tag) 에 보여 줄 내용이 없다.")
            for section in release.sections {
                XCTAssertFalse(section.items.isEmpty, "\(release.tag) 의 '\(section.title)' 이 비어 있다.")
                XCTAssertFalse(section.title.isEmpty)
            }
        }
    }

    /// 생성기가 마크다운 강조를 벗겼는지. 남아 있으면 화면에 별표가 그대로 보인다.
    func testItemsCarryNoMarkdownEmphasis() {
        for release in ReleaseHistory.all {
            for item in release.sections.flatMap(\.items) {
                XCTAssertFalse(item.contains("**"), "\(release.tag): 굵게 표시가 남아 있다 — \(item)")
                XCTAssertFalse(item.contains("`"), "\(release.tag): 코드 표시가 남아 있다 — \(item)")
            }
        }
    }

    // MARK: - 태그

    func testTagMatchesVersion() {
        for release in ReleaseHistory.all {
            XCTAssertEqual(release.tag, "v" + release.version)
            XCTAssertNotNil(release.releaseURL, "\(release.tag) 의 깃허브 주소를 만들지 못했다.")
        }
    }

    func testDisplayDateIsReadable() {
        XCTAssertEqual(
            Release(version: "1.0", date: "2026-08-15", summary: nil, sections: []).displayDate,
            "2026년 8월 15일"
        )
        // 형식이 어긋나면 원본을 그대로 보여 준다. 화면이 비지 않는 쪽이 낫다.
        XCTAssertEqual(
            Release(version: "1.0", date: "언젠가", summary: nil, sections: []).displayDate,
            "언젠가"
        )
    }

    // MARK: - 지금 실행 중인 빌드

    func testRunningBuildTagFollowsBundleVersion() {
        XCTAssertEqual(AppVersion.tag, "v" + AppVersion.marketing)
        XCTAssertTrue(AppVersion.display.hasPrefix(AppVersion.marketing))
    }

    /// 번들 버전을 올리고 CHANGELOG 를 안 고치면 여기서 걸린다.
    func testRunningBuildIsTheNewestRelease() {
        XCTAssertEqual(
            ReleaseHistory.latest?.version, AppVersion.marketing,
            "지금 빌드(\(AppVersion.marketing))가 변경 이력의 최신 항목이 아니다. "
            + "CHANGELOG.md 에 항목을 넣고 tools/generate_release_history.py 를 실행할 것."
        )
        XCTAssertNotNil(AppVersion.release, "지금 빌드가 변경 이력에 없다.")
    }

    // MARK: - 도우미

    private func components(of release: Release) -> [Int] {
        release.version.split(separator: ".").compactMap { Int($0) }
    }

    /// `[1, 7, 1]` 이 `[1, 7]` 보다 뒤라고 판단한다. 자리 수가 다르면 없는 자리는 0.
    private func isDescending(_ newer: [Int], _ older: [Int]) -> Bool {
        for index in 0..<max(newer.count, older.count) {
            let left = index < newer.count ? newer[index] : 0
            let right = index < older.count ? older[index] : 0
            if left != right { return left > right }
        }
        return false
    }
}

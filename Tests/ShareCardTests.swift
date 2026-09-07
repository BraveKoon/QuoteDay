import SwiftUI
import XCTest
@testable import QuoteDay

/// 공유 카드 검증.
///
/// 카드 그림 자체는 눈으로 봐야 하지만, **글자가 배경에 묻히는지**는 계산으로 확인할 수 있다.
/// 사용자가 배경색을 자유롭게 고를 수 있게 되면서 이게 실제 위험이 되었다 —
/// 어두운 보라를 고른 사람에게 검은 글씨가 나가면 카드가 통째로 못 쓰게 된다.
final class ShareCardTests: XCTestCase {

    // MARK: - 색 대비

    func testDarkBackgroundsGetLightText() {
        XCTAssertTrue(ShareCardDesign.defaultColor.prefersLightText, "QuoteDay 보라 위에는 흰 글자다.")
        XCTAssertTrue(Color(hex: 0x000000).prefersLightText)
        XCTAssertTrue(Color(hex: 0x1B1F2A).prefersLightText)
        XCTAssertTrue(Color(hex: 0x4F7A5B).prefersLightText)
    }

    func testLightBackgroundsGetDarkText() {
        XCTAssertFalse(Color(hex: 0xFFFFFF).prefersLightText)
        XCTAssertFalse(Color(hex: 0xFBFAF7).prefersLightText)
        XCTAssertFalse(Color(hex: 0xC7A44A).prefersLightText)
    }

    /// 견본으로 내놓는 색은 전부 글자가 읽혀야 한다. 하나라도 어긋나면 그 견본이 문제다.
    func testEveryPresetColorProducesReadableText() {
        for preset in ShareCardDesign.presetColors {
            var design = ShareCardDesign()
            design.backgroundColor = preset.color
            let palette = design.palette()

            // 배경과 글자의 밝기 판정이 서로 반대여야 대비가 산다.
            XCTAssertNotEqual(
                preset.color.prefersLightText,
                palette.text.prefersLightText,
                "\(preset.name): 배경과 글자가 같은 밝기라 묻힙니다."
            )
        }
    }

    // MARK: - 색 저장

    func testColorSurvivesAHexRoundTrip() {
        for preset in ShareCardDesign.presetColors {
            guard let hex = preset.color.hexString else {
                return XCTFail("\(preset.name): 16진수로 바꾸지 못했습니다.")
            }
            guard let restored = Color(hexString: hex) else {
                return XCTFail("\(preset.name): 되읽지 못했습니다.")
            }
            XCTAssertEqual(restored.hexString, hex, "\(preset.name): 저장 후 색이 달라졌습니다.")
        }
    }

    func testMalformedHexFallsBackInsteadOfCrashing() {
        XCTAssertNil(Color(hexString: nil))
        XCTAssertNil(Color(hexString: ""))
        XCTAssertNil(Color(hexString: "xyz"))
        XCTAssertNil(Color(hexString: "12345"))
        XCTAssertNil(Color(hexString: "12345678"))
        XCTAssertNotNil(Color(hexString: "#5A64D8"), "# 이 붙어 있어도 읽어야 한다.")
    }

    func testDefaultColorIsTheAppAccent() {
        // 기본 카드 색은 앱의 메인 보라와 같아야 한다.
        XCTAssertEqual(ShareCardDesign.defaultColor.hexString, "5A64D8")
        XCTAssertEqual(ShareCardDesign.presetColors.first?.name, "QuoteDay")
    }

    // MARK: - 느낀 점

    func testEmptyNoteIsNotDrawn() {
        var design = ShareCardDesign()
        XCTAssertFalse(design.hasNote)

        design.note = "   \n  "
        XCTAssertFalse(design.hasNote, "공백만 적은 것은 적지 않은 것이다.")

        design.note = "  좋은 문장  "
        XCTAssertTrue(design.hasNote)
        XCTAssertEqual(design.trimmedNote, "좋은 문장")
    }

    // MARK: - 프리셋

    /// 프리셋을 고르면 직접 정한 색이 물러나야 한다.
    /// 둘 다 살아 있으면 화면에서 무엇이 이겼는지 알 수 없다.
    func testPresetPaletteIsUsedWhenNoColorIsChosen() {
        var design = ShareCardDesign()
        design.theme = .ink
        design.backgroundColor = nil

        XCTAssertEqual(design.palette().background, ShareCardTheme.ink.background)
        XCTAssertEqual(design.palette().text, ShareCardTheme.ink.textColor)
    }

    func testChosenColorWinsOverThePreset() {
        var design = ShareCardDesign()
        design.theme = .ink
        design.backgroundColor = ShareCardDesign.defaultColor

        XCTAssertEqual(design.palette().background.hexString, "5A64D8")
    }

    /// 워터마크는 기본으로 켜져 있어야 한다. 카드가 어디로 퍼지든 출처가 남는다.
    func testWatermarkIsOnByDefault() {
        XCTAssertTrue(ShareCardDesign().showsWatermark)
    }
}

import Foundation

/// 사람 이름을 비교하기 위한 정규화 키.
///
/// 같은 사람을 가리키는 표기가 데이터마다 다르다. ZenQuotes 는 `"C.S. Lewis"` 를
/// 주는데 앱에는 `"C. S. Lewis"` 로 들어 있고, `"Antoine de Saint-Exupery"` 와
/// `"Antoine de Saint-Exupéry"` 도 같은 사람이다. 이 표기 차이를 지운다.
///
/// 규칙은 셋뿐이다.
/// 1. 발음 구별 기호를 벗긴다 (`é` → `e`).
/// 2. 글자와 숫자가 아닌 것은 **공백으로 바꾼다**. 지우면 안 된다 —
///    지우면 `"C.S."` 가 `"cs"` 가 되어 `"c s"` 와 어긋난다.
/// 3. 소문자로 낮추고 연속된 공백을 하나로 줄인다.
public enum NameKey {
    public static func normalize(_ name: String) -> String {
        let folded = name.folding(
            options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        let spaced = folded.map { character -> Character in
            (character.isLetter || character.isNumber) ? character : " "
        }
        return String(spaced)
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
    }
}

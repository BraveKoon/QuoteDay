import Foundation

/// 문장에서 낱말을 뽑아 빈칸으로 바꾼다.
///
/// 한국어는 조사가 붙어 다녀서 형태소 단위로 자르려면 사전이 필요하다.
/// 여기서는 **어절**(띄어쓰기 단위)을 그대로 하나의 낱말로 쓴다.
/// "인생은"에서 "인생"만 뽑아내지 않고 "인생은" 통째로 뚫는다는 뜻인데,
/// 문제로서는 오히려 이쪽이 자연스럽다 — 조사가 남아 있으면 답이 절반쯤 보인다.
///
/// 앞뒤에 붙은 따옴표·마침표는 빈칸 밖에 남긴다. 문장 부호까지 지우면
/// 남은 문장이 어색해지고, 보기에 마침표가 섞여 들어간다.
public enum BlankMaker {

    /// 어절 하나. `leading + core + trailing` 이 원래 어절이다.
    public struct Token: Hashable, Sendable {
        public let leading: String
        public let core: String
        public let trailing: String

        public var original: String { leading + core + trailing }
    }

    /// 빈칸을 뚫은 결과.
    public struct Blanked: Hashable, Sendable {
        /// 빈칸이 `ChallengeQuestion.blankMarker` 로 바뀐 문장.
        public let text: String
        /// 빈칸에 들어갈 낱말. 문장에 나오는 순서를 따른다.
        public let answers: [String]
    }

    /// 낱말 앞뒤에서 떼어 내는 문자.
    private static let punctuation = CharacterSet(charactersIn:
        ".,!?;:'\"()[]{}\u{201C}\u{201D}\u{2018}\u{2019}\u{300C}\u{300D}\u{300E}\u{300F}"
        + "\u{2014}\u{2013}\u{2026}\u{00B7}\u{FF0C}\u{FF0E}\u{FF01}\u{FF1F}\u{2015}-"
    )

    // MARK: - 자르기

    public static func tokenize(_ text: String) -> [Token] {
        text.split(whereSeparator: { $0.isWhitespace }).map { piece in
            let characters = Array(String(piece))
            var start = 0
            var end = characters.count
            while start < end, isPunctuation(characters[start]) { start += 1 }
            while end > start, isPunctuation(characters[end - 1]) { end -= 1 }
            return Token(
                leading: String(characters[0..<start]),
                core: String(characters[start..<end]),
                trailing: String(characters[end..<characters.count])
            )
        }
    }

    private static func isPunctuation(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { punctuation.contains($0) }
    }

    // MARK: - 후보

    /// 빈칸으로 뚫을 수 있는 낱말.
    ///
    /// 한 글자 어절("나", "그")은 제외한다. 보기로 늘어놓아도 구분이 안 되고,
    /// 문맥만으로 찍기가 너무 쉽다. 숫자만으로 된 어절도 뺀다.
    public static func candidates(in text: String) -> [String] {
        tokenize(text).map(\.core).filter(isUsable)
    }

    private static func isUsable(_ core: String) -> Bool {
        guard core.count >= 2 else { return false }
        return core.contains { $0.isLetter }
    }

    /// 남겨 둘 최소 어절 수. 이보다 짧아지면 문장이 문제 구실을 못 한다.
    private static let minimumRemainingTokens = 3

    // MARK: - 뚫기

    /// - Parameters:
    ///   - blankCount: 뚫을 낱말 수.
    ///   - preferLongWords: 참이면 긴 낱말 쪽에서 고른다. 긴 어절일수록
    ///     문맥으로 유추하기 어려워 문제가 어려워진다.
    /// - Returns: 조건을 채우지 못하면 nil. 호출하는 쪽은 그 명언을 건너뛴다.
    public static func make(
        from text: String,
        blankCount: Int,
        preferLongWords: Bool,
        using rng: inout SeededRandomGenerator
    ) -> Blanked? {
        guard blankCount > 0 else { return nil }
        let tokens = tokenize(text)
        let candidateIndices = tokens.indices.filter { isUsable(tokens[$0].core) }

        guard candidateIndices.count >= blankCount,
              tokens.count - blankCount >= minimumRemainingTokens
        else { return nil }

        // 긴 낱말 우선일 때는 상위 절반만 후보로 남긴다.
        // 길이가 같으면 인덱스로 순서를 못 박아, 정렬이 불안정해도 결과가 흔들리지 않게 한다.
        var pickPool = candidateIndices
        if preferLongWords {
            let ranked = candidateIndices.sorted { lhs, rhs in
                let left = tokens[lhs].core.count
                let right = tokens[rhs].core.count
                return left == right ? lhs < rhs : left > right
            }
            pickPool = Array(ranked.prefix(max(blankCount, (ranked.count + 1) / 2)))
        }

        let shuffled = pickPool.shuffled(using: &rng)
        var chosen: [Int] = []

        // 빈칸이 붙어 있으면 문맥이 통째로 사라진다. 먼저 떨어뜨려 고른다.
        for index in shuffled where chosen.count < blankCount {
            if chosen.allSatisfy({ abs($0 - index) >= 2 }) { chosen.append(index) }
        }
        // 짧은 문장이라 떨어뜨릴 수 없으면 조건을 푼다.
        for index in shuffled where chosen.count < blankCount {
            if !chosen.contains(index) { chosen.append(index) }
        }
        guard chosen.count == blankCount else { return nil }

        chosen.sort()
        let blanks = Set(chosen)
        let rendered = tokens.indices.map { index -> String in
            guard blanks.contains(index) else { return tokens[index].original }
            return tokens[index].leading + ChallengeQuestion.blankMarker + tokens[index].trailing
        }

        return Blanked(
            text: rendered.joined(separator: " "),
            answers: chosen.map { tokens[$0].core }
        )
    }
}

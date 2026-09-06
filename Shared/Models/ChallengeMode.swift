import SwiftUI

/// 챌린지 문제의 종류.
public enum ChallengeMode: String, CaseIterable, Identifiable, Codable, Sendable {
    /// 인물과 명언을 보여 주고, 뚫린 단어를 맞힌다.
    case fillInTheBlank
    /// 명언만 보여 주고, 누가 말했는지 맞힌다.
    case guessTheAuthor

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .fillInTheBlank: "빈칸 채우기"
        case .guessTheAuthor: "누가 말했을까"
        }
    }

    public var summary: String {
        switch self {
        case .fillInTheBlank: "명언에서 사라진 낱말을 찾아 넣습니다."
        case .guessTheAuthor: "문장만 보고 말한 사람을 고릅니다."
        }
    }

    public var symbol: String {
        switch self {
        case .fillInTheBlank: "square.dashed"
        case .guessTheAuthor: "person.crop.circle.badge.questionmark"
        }
    }
}

/// 난이도 5단계.
///
/// 단계를 나누는 손잡이는 네 가지다. 어느 것도 "정답을 덜 알려 주는" 방식이 아니라,
/// **찍어서 맞힐 확률을 낮추는** 방식이라는 점이 중요하다.
///
/// 1. 보기 개수 — 3개에서 6개로 늘어난다.
/// 2. 힌트 — 낮은 단계에서는 인물(또는 인물의 직업·국적)을 미리 알려 준다.
/// 3. 오답의 그럴듯함 — 무작위 낱말에서 시작해, 마지막에는 같은 인물·비슷한 길이의
///    낱말만 골라 붙인다. 같은 문제라도 4단계와 5단계는 체감이 다르다.
/// 4. 제한 시간 — 4·5단계에만 있다. 시간이 지나면 오답 처리된다.
///
/// 빈칸 개수는 4단계부터 둘로 늘고, 그때는 보기도 낱말 한 쌍이 된다.
public enum ChallengeDifficulty: Int, CaseIterable, Identifiable, Codable, Sendable {
    case beginner = 1
    case normal = 2
    case hard = 3
    case veryHard = 4
    case extreme = 5

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .beginner: "입문"
        case .normal: "보통"
        case .hard: "어려움"
        case .veryHard: "매우 어려움"
        case .extreme: "극한"
        }
    }

    /// 목록에서 단계를 구분하는 색.
    public var tint: Color {
        switch self {
        case .beginner: ClayPalette.mint
        case .normal: ClayPalette.sky
        case .hard: ClayPalette.lemon
        case .veryHard: ClayPalette.apricot
        case .extreme: ClayPalette.coral
        }
    }

    // MARK: - 손잡이

    /// 보기 개수.
    public var choiceCount: Int {
        switch self {
        case .beginner: 3
        case .normal: 4
        case .hard: 4
        case .veryHard: 5
        case .extreme: 6
        }
    }

    /// 한 문제에서 뚫는 낱말 수(빈칸 채우기 전용).
    public var blankCount: Int {
        switch self {
        case .beginner, .normal, .hard: 1
        case .veryHard, .extreme: 2
        }
    }

    /// 힌트(인물 이름 또는 직업·국적)를 보여 줄지.
    public var showsHint: Bool {
        switch self {
        case .beginner, .normal: true
        case .hard, .veryHard, .extreme: false
        }
    }

    /// 오답을 정답과 얼마나 닮게 고를지.
    public var similarity: ChallengeSimilarity {
        switch self {
        case .beginner: .random
        case .normal: .related
        case .hard: .close
        case .veryHard: .close
        case .extreme: .close
        }
    }

    /// 문제당 제한 시간. nil 이면 시간 제한이 없다.
    public var timeLimit: Int? {
        switch self {
        case .beginner, .normal, .hard: nil
        case .veryHard: 20
        case .extreme: 15
        }
    }

    /// 목록 화면에 한 줄로 요약해 보여 줄 조건.
    public func detail(for mode: ChallengeMode) -> String {
        var parts = ["보기 \(choiceCount)개"]
        if mode == .fillInTheBlank && blankCount > 1 {
            parts.append("빈칸 \(blankCount)개")
        }
        parts.append(showsHint ? "힌트 있음" : "힌트 없음")
        if let timeLimit {
            parts.append("\(timeLimit)초")
        }
        return parts.joined(separator: " · ")
    }
}

/// 오답을 정답과 얼마나 닮게 고를지.
public enum ChallengeSimilarity: Sendable {
    /// 전체에서 아무거나.
    case random
    /// 같은 주제(카테고리) 안에서.
    case related
    /// 같은 인물 · 비슷한 길이까지 맞춘다.
    case close
}

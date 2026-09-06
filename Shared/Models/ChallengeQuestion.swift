import Foundation

/// 챌린지 한 문제.
///
/// 값 타입이고 생성 시점에 정답까지 확정되어 있다. 화면은 이 값을 그리기만 하며
/// 채점도 `isCorrect(_:)` 한 곳에서만 한다.
public struct ChallengeQuestion: Identifiable, Hashable, Sendable {
    /// 문제를 만든 seed. 같은 seed 는 항상 같은 문제를 만든다.
    public let id: String
    public let mode: ChallengeMode
    public let difficulty: ChallengeDifficulty
    /// 문제의 바탕이 된 명언.
    public let quote: Quote
    public let author: Author
    /// 화면에 띄울 본문. 빈칸 채우기에서는 낱말이 `ChallengeQuestion.blankMarker` 로 바뀌어 있다.
    public let promptText: String
    /// 보기. 순서는 이미 섞여 있다.
    public let choices: [String]
    public let correctIndex: Int
    /// 난이도가 낮을 때만 채워지는 한 줄 힌트.
    public let hint: String?

    public init(
        id: String,
        mode: ChallengeMode,
        difficulty: ChallengeDifficulty,
        quote: Quote,
        author: Author,
        promptText: String,
        choices: [String],
        correctIndex: Int,
        hint: String?
    ) {
        self.id = id
        self.mode = mode
        self.difficulty = difficulty
        self.quote = quote
        self.author = author
        self.promptText = promptText
        self.choices = choices
        self.correctIndex = correctIndex
        self.hint = hint
    }

    /// 본문에서 빈칸을 나타내는 표시. 화면에서 이 조각만 다른 색으로 그린다.
    public static let blankMarker = "____"

    public var correctAnswer: String { choices[correctIndex] }

    public func isCorrect(_ index: Int) -> Bool { index == correctIndex }

    /// 답을 맞힌 뒤 보여 주는 원래 문장.
    public var revealedText: String { quote.text }
}

/// 한 문제에 대한 사용자의 응답.
public enum ChallengeAnswer: Hashable, Sendable {
    case picked(Int)
    /// 제한 시간을 넘겼다. 오답으로 친다.
    case timedOut

    public var pickedIndex: Int? {
        if case .picked(let index) = self { return index }
        return nil
    }
}

/// 한 판의 결과.
public struct ChallengeResult: Hashable, Sendable {
    public let mode: ChallengeMode
    public let difficulty: ChallengeDifficulty
    public let correctCount: Int
    public let questionCount: Int
    public let bestStreak: Int
    /// 이번 판에서 최고 기록을 새로 썼는지.
    public let isNewRecord: Bool

    public init(
        mode: ChallengeMode,
        difficulty: ChallengeDifficulty,
        correctCount: Int,
        questionCount: Int,
        bestStreak: Int,
        isNewRecord: Bool
    ) {
        self.mode = mode
        self.difficulty = difficulty
        self.correctCount = correctCount
        self.questionCount = questionCount
        self.bestStreak = bestStreak
        self.isNewRecord = isNewRecord
    }

    public var accuracy: Double {
        guard questionCount > 0 else { return 0 }
        return Double(correctCount) / Double(questionCount)
    }

    /// 모두 맞혔는지.
    public var isPerfect: Bool { questionCount > 0 && correctCount == questionCount }

    /// 결과 화면 맨 위에 띄우는 한마디.
    public var headline: String {
        switch accuracy {
        case 1: "전부 맞혔습니다"
        case 0.8...: "거의 다 맞혔습니다"
        case 0.5...: "절반은 넘겼습니다"
        case 0.2...: "다음 판이 있습니다"
        default: "한 단계 낮춰 볼까요"
        }
    }
}

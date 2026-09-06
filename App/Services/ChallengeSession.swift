import Foundation

/// 진행 중인 한 판.
///
/// 문제 생성은 `ChallengeGenerator` 가 이미 끝내 놓았고, 여기서는 진행과 채점만 한다.
/// 화면은 상태를 읽고 `select(_:)` / `advance()` / `tick()` 세 개만 호출한다.
@MainActor
@Observable
final class ChallengeSession: Identifiable {
    /// `fullScreenCover(item:)` 에 넘기기 위한 식별자.
    /// 판이 새로 시작될 때마다 새 인스턴스라서 값이 바뀐다.
    nonisolated let id = UUID()

    enum Phase: Hashable {
        /// 문제를 풀고 있다.
        case asking
        /// 답을 냈고 정답을 보여 주는 중이다.
        case revealing
        /// 판이 끝났다.
        case finished
    }

    let mode: ChallengeMode
    let difficulty: ChallengeDifficulty
    let questions: [ChallengeQuestion]

    private(set) var index: Int = 0
    private(set) var answer: ChallengeAnswer?
    private(set) var correctCount: Int = 0
    private(set) var currentStreak: Int = 0
    private(set) var bestStreak: Int = 0
    private(set) var phase: Phase = .asking
    /// 제한 시간이 있는 단계에서 남은 초. 없으면 nil.
    private(set) var remainingSeconds: Int?

    init(mode: ChallengeMode, difficulty: ChallengeDifficulty, questions: [ChallengeQuestion]) {
        self.mode = mode
        self.difficulty = difficulty
        self.questions = questions
        self.remainingSeconds = difficulty.timeLimit
        if questions.isEmpty { self.phase = .finished }
    }

    /// 명언 라이브러리에서 새 판을 만든다. seed 를 넘기지 않으면 매번 다른 문제가 나온다.
    convenience init(
        mode: ChallengeMode,
        difficulty: ChallengeDifficulty,
        generator: ChallengeGenerator = ChallengeGenerator(),
        seed: String = UUID().uuidString
    ) {
        self.init(
            mode: mode,
            difficulty: difficulty,
            questions: generator.makeRound(mode: mode, difficulty: difficulty, seed: seed)
        )
    }

    // MARK: - 읽기

    var currentQuestion: ChallengeQuestion? {
        questions.indices.contains(index) ? questions[index] : nil
    }

    var questionCount: Int { questions.count }

    /// 1부터 세는 문제 번호. 화면에 "3 / 10" 으로 쓴다.
    var displayNumber: Int { min(index + 1, questionCount) }

    var isLastQuestion: Bool { index >= questionCount - 1 }

    var progress: Double {
        guard questionCount > 0 else { return 0 }
        return Double(index) / Double(questionCount)
    }

    /// 이번 문제를 맞혔는지. 아직 답하지 않았으면 nil.
    var wasCorrect: Bool? {
        guard let answer, let question = currentQuestion else { return nil }
        guard let picked = answer.pickedIndex else { return false }
        return question.isCorrect(picked)
    }

    /// 이 보기를 사용자가 골랐는지. 시간이 지나 끝난 문제에는 고른 보기가 없다.
    func isPicked(_ choiceIndex: Int) -> Bool {
        guard case .picked(let index)? = answer else { return false }
        return index == choiceIndex
    }

    var result: ChallengeResult {
        ChallengeResult(
            mode: mode,
            difficulty: difficulty,
            correctCount: correctCount,
            questionCount: questionCount,
            bestStreak: bestStreak,
            // 기록 갱신 여부는 저장소가 판단한다. 여기서는 자리만 채운다.
            isNewRecord: false
        )
    }

    // MARK: - 진행

    /// 보기를 골랐다. 이미 답한 문제면 아무 일도 하지 않는다.
    func select(_ choiceIndex: Int) {
        guard phase == .asking, let question = currentQuestion else { return }
        guard question.choices.indices.contains(choiceIndex) else { return }
        record(.picked(choiceIndex))
    }

    /// 다음 문제로 넘어간다. 마지막 문제였으면 판이 끝난다.
    func advance() {
        guard phase == .revealing else { return }
        if isLastQuestion {
            phase = .finished
            return
        }
        index += 1
        answer = nil
        phase = .asking
        remainingSeconds = difficulty.timeLimit
    }

    /// 1초마다 화면에서 불러 준다. 제한 시간이 없으면 아무 일도 하지 않는다.
    func tick() {
        guard phase == .asking, let remaining = remainingSeconds else { return }
        if remaining <= 1 {
            remainingSeconds = 0
            record(.timedOut)
        } else {
            remainingSeconds = remaining - 1
        }
    }

    private func record(_ answer: ChallengeAnswer) {
        guard let question = currentQuestion else { return }
        self.answer = answer
        phase = .revealing

        let isCorrect = answer.pickedIndex.map(question.isCorrect) ?? false
        if isCorrect {
            correctCount += 1
            currentStreak += 1
            bestStreak = max(bestStreak, currentStreak)
        } else {
            currentStreak = 0
        }
    }
}

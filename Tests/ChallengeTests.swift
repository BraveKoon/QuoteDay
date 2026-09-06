import XCTest
@testable import QuoteDay

/// 챌린지 문제 생성기 검증.
///
/// 화면은 여기서 만든 문제를 그리기만 하므로, 문제가 옳게 만들어지는지만 확인하면
/// 기능 전체가 검증된다. 특히 **보기가 모자란 문제**와 **정답이 두 번 들어간 보기**는
/// 눈으로 찾기 어렵고 사용자에게는 바로 티가 나므로 전수로 확인한다.
final class ChallengeTests: XCTestCase {

    private let generator = ChallengeGenerator()
    private let library = QuoteLibrary.shared

    // MARK: - 어절 자르기

    func testTokenizerKeepsPunctuationOutsideTheWord() {
        let tokens = BlankMaker.tokenize("\u{201C}인생은 짧다.\u{201D}")
        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0].core, "인생은")
        XCTAssertEqual(tokens[0].leading, "\u{201C}")
        XCTAssertEqual(tokens[1].core, "짧다")
        XCTAssertEqual(tokens[1].trailing, ".\u{201D}")
    }

    func testTokensRebuildTheOriginalWord() {
        for quote in library.quotes {
            for token in BlankMaker.tokenize(quote.text) {
                XCTAssertFalse(token.original.isEmpty, "빈 어절이 나왔습니다: \(quote.slug)")
            }
        }
    }

    func testOneLetterWordsAreNotBlankCandidates() {
        // 한 글자 어절은 보기에 늘어놓아도 구분이 안 되고 찍기가 너무 쉽다.
        let candidates = BlankMaker.candidates(in: "나 는 너 를 정말 좋아한다")
        XCTAssertEqual(candidates, ["정말", "좋아한다"])
    }

    // MARK: - 결정성

    func testSameSeedMakesTheSameRound() {
        let first = generator.makeRound(mode: .fillInTheBlank, difficulty: .hard, seed: "seed-1")
        let second = generator.makeRound(mode: .fillInTheBlank, difficulty: .hard, seed: "seed-1")
        XCTAssertEqual(first.map(\.id), second.map(\.id))
        XCTAssertEqual(first.map(\.choices), second.map(\.choices))
        XCTAssertEqual(first.map(\.correctIndex), second.map(\.correctIndex))
    }

    func testDifferentSeedsMakeDifferentRounds() {
        let first = generator.makeRound(mode: .fillInTheBlank, difficulty: .hard, seed: "seed-1")
        let second = generator.makeRound(mode: .fillInTheBlank, difficulty: .hard, seed: "seed-2")
        XCTAssertNotEqual(first.map(\.id), second.map(\.id))
    }

    // MARK: - 문제의 모양

    /// 모든 모드·단계에서 한 판이 다 채워져야 한다.
    /// 문제가 모자라면 판이 짧아지고, 점수 비교가 무너진다.
    func testEveryModeAndDifficultyFillsAFullRound() {
        for mode in ChallengeMode.allCases {
            for difficulty in ChallengeDifficulty.allCases {
                let round = generator.makeRound(mode: mode, difficulty: difficulty, seed: "round")
                XCTAssertEqual(
                    round.count,
                    ChallengeGenerator.questionsPerRound,
                    "\(mode.rawValue) \(difficulty.rawValue)단계에서 문제가 모자랍니다."
                )
            }
        }
    }

    func testRoundNeverRepeatsTheSameQuote() {
        for mode in ChallengeMode.allCases {
            let round = generator.makeRound(mode: mode, difficulty: .normal, seed: "unique")
            let slugs = round.map(\.quote.slug)
            XCTAssertEqual(Set(slugs).count, slugs.count, "같은 명언이 한 판에 두 번 나왔습니다.")
        }
    }

    /// 보기 개수, 중복, 정답 위치를 전 명언에 대해 확인한다.
    func testEveryGeneratedQuestionIsWellFormed() {
        for mode in ChallengeMode.allCases {
            for difficulty in ChallengeDifficulty.allCases {
                for quote in generator.sourceQuotes(for: mode) {
                    guard let question = generator.makeQuestion(
                        for: quote,
                        mode: mode,
                        difficulty: difficulty,
                        seed: quote.slug
                    ) else { continue }

                    XCTAssertEqual(
                        question.choices.count,
                        difficulty.choiceCount,
                        "\(quote.slug): 보기 개수가 다릅니다."
                    )
                    XCTAssertEqual(
                        Set(question.choices).count,
                        question.choices.count,
                        "\(quote.slug): 보기가 중복되었습니다."
                    )
                    XCTAssertTrue(
                        question.choices.indices.contains(question.correctIndex),
                        "\(quote.slug): 정답 위치가 범위를 벗어났습니다."
                    )
                    XCTAssertFalse(
                        question.correctAnswer.isEmpty,
                        "\(quote.slug): 정답이 비어 있습니다."
                    )
                }
            }
        }
    }

    func testBlankCountMatchesTheDifficulty() {
        for difficulty in ChallengeDifficulty.allCases {
            for quote in generator.sourceQuotes(for: .fillInTheBlank).prefix(40) {
                guard let question = generator.makeQuestion(
                    for: quote,
                    mode: .fillInTheBlank,
                    difficulty: difficulty,
                    seed: quote.slug
                ) else { continue }

                let blanks = question.promptText.components(
                    separatedBy: ChallengeQuestion.blankMarker
                ).count - 1
                XCTAssertEqual(
                    blanks,
                    difficulty.blankCount,
                    "\(quote.slug) \(difficulty.rawValue)단계: 빈칸 수가 다릅니다."
                )
            }
        }
    }

    /// 정답 낱말이 지문에 그대로 남아 있으면 문제가 성립하지 않는다.
    func testTheAnswerIsRemovedFromThePrompt() {
        for quote in generator.sourceQuotes(for: .fillInTheBlank) {
            guard let question = generator.makeQuestion(
                for: quote,
                mode: .fillInTheBlank,
                difficulty: .beginner,
                seed: quote.slug
            ) else { continue }
            XCTAssertTrue(
                question.promptText.contains(ChallengeQuestion.blankMarker),
                "\(quote.slug): 빈칸이 뚫리지 않았습니다."
            )
        }
    }

    // MARK: - 힌트와 제한 시간

    func testHintOnlyAppearsInTheEasyLevels() {
        for difficulty in ChallengeDifficulty.allCases {
            let question = generator.makeRound(
                mode: .guessTheAuthor,
                difficulty: difficulty,
                count: 1,
                seed: "hint"
            ).first
            XCTAssertNotNil(question)
            XCTAssertEqual(
                question?.hint != nil,
                difficulty.showsHint,
                "\(difficulty.rawValue)단계의 힌트 노출이 정의와 다릅니다."
            )
        }
    }

    func testTimeLimitOnlyAppliesToTheTopTwoLevels() {
        XCTAssertNil(ChallengeDifficulty.beginner.timeLimit)
        XCTAssertNil(ChallengeDifficulty.normal.timeLimit)
        XCTAssertNil(ChallengeDifficulty.hard.timeLimit)
        XCTAssertNotNil(ChallengeDifficulty.veryHard.timeLimit)
        XCTAssertNotNil(ChallengeDifficulty.extreme.timeLimit)
        // 위 단계가 더 촉박해야 한다.
        XCTAssertLessThan(
            ChallengeDifficulty.extreme.timeLimit ?? 0,
            ChallengeDifficulty.veryHard.timeLimit ?? 0
        )
    }

    /// 단계가 오를수록 보기가 줄어들지 않아야 한다.
    func testDifficultyKnobsIncreaseMonotonically() {
        let levels = ChallengeDifficulty.allCases.sorted { $0.rawValue < $1.rawValue }
        for (lower, higher) in zip(levels, levels.dropFirst()) {
            XCTAssertLessThanOrEqual(lower.choiceCount, higher.choiceCount)
            XCTAssertLessThanOrEqual(lower.blankCount, higher.blankCount)
        }
    }

    // MARK: - 귀속

    /// 출처가 확인되지 않은 명언으로 "누가 말했을까"를 내면
    /// 앱이 확인되지 않은 귀속을 정답이라고 가르치게 된다.
    func testDisputedQuotesAreExcludedFromTheAuthorMode() {
        let slugs = Set(generator.sourceQuotes(for: .guessTheAuthor).map(\.slug))
        XCTAssertTrue(
            slugs.isDisjoint(with: DisputedAttribution.slugs),
            "귀속이 확인되지 않은 명언이 인물 문제로 나옵니다."
        )
    }

    /// 빈칸 채우기는 인물을 묻지 않으므로 그대로 쓴다.
    func testDisputedQuotesStillAppearInTheBlankMode() {
        let slugs = Set(generator.sourceQuotes(for: .fillInTheBlank).map(\.slug))
        XCTAssertFalse(
            slugs.isDisjoint(with: DisputedAttribution.slugs),
            "인물을 묻지 않는 문제까지 뺄 이유는 없습니다."
        )
    }

    func testDisputedSlugsAllExist() {
        let known = Set(library.quotes.map(\.slug))
        for slug in DisputedAttribution.slugs {
            XCTAssertTrue(known.contains(slug), "없는 명언이 목록에 있습니다: \(slug)")
        }
    }

    // MARK: - 비하인드 스토리

    func testBehindStoriesPointAtRealQuotes() {
        let known = Set(library.quotes.map(\.slug))
        for story in BehindStoryLibrary.all {
            XCTAssertTrue(
                known.contains(story.quoteSlug),
                "없는 명언의 배경입니다: \(story.quoteSlug)"
            )
        }
    }

    func testBehindStoriesAlwaysCarryASource() {
        for story in BehindStoryLibrary.all {
            XCTAssertFalse(
                story.source.trimmingCharacters(in: .whitespaces).isEmpty,
                "\(story.quoteSlug): 출처가 비어 있습니다."
            )
            XCTAssertFalse(
                story.occasion.trimmingCharacters(in: .whitespaces).isEmpty,
                "\(story.quoteSlug): 언제·어디서인지가 비어 있습니다."
            )
        }
    }

    func testBehindStoriesAreUnique() {
        let slugs = BehindStoryLibrary.all.map(\.quoteSlug)
        XCTAssertEqual(Set(slugs).count, slugs.count, "같은 명언에 배경이 두 번 달렸습니다.")
    }

    /// 귀속이 논쟁 중인 명언에는 배경을 달지 않는다는 규칙.
    func testDisputedQuotesHaveNoBehindStory() {
        for story in BehindStoryLibrary.all {
            XCTAssertFalse(
                DisputedAttribution.isDisputed(story.quoteSlug),
                "\(story.quoteSlug): 귀속이 확인되지 않았는데 배경이 달려 있습니다."
            )
        }
    }

    // MARK: - 판 진행

    @MainActor
    func testSessionScoresAndStreaks() {
        let session = ChallengeSession(mode: .fillInTheBlank, difficulty: .beginner, seed: "play")
        XCTAssertEqual(session.questionCount, ChallengeGenerator.questionsPerRound)

        var expectedCorrect = 0
        while session.phase != .finished {
            guard let question = session.currentQuestion else { break }
            // 홀수 번째만 맞힌다.
            let pick = session.index % 2 == 0 ? question.correctIndex : wrongIndex(for: question)
            if pick == question.correctIndex { expectedCorrect += 1 }
            session.select(pick)
            XCTAssertEqual(session.phase, .revealing)
            session.advance()
        }

        XCTAssertEqual(session.correctCount, expectedCorrect)
        XCTAssertEqual(session.bestStreak, 1, "번갈아 맞혔으므로 연속 기록은 1이어야 합니다.")
    }

    @MainActor
    func testAnsweringTwiceIsIgnored() {
        let session = ChallengeSession(mode: .fillInTheBlank, difficulty: .beginner, seed: "double")
        guard let question = session.currentQuestion else { return XCTFail("문제가 없습니다.") }

        session.select(question.correctIndex)
        XCTAssertEqual(session.correctCount, 1)
        // 답을 낸 뒤 다시 눌러도 점수가 늘면 안 된다.
        session.select(question.correctIndex)
        XCTAssertEqual(session.correctCount, 1)
    }

    @MainActor
    func testRunningOutOfTimeCountsAsWrong() {
        let session = ChallengeSession(mode: .fillInTheBlank, difficulty: .extreme, seed: "timeout")
        let limit = ChallengeDifficulty.extreme.timeLimit ?? 0
        XCTAssertEqual(session.remainingSeconds, limit)

        for _ in 0..<limit { session.tick() }

        XCTAssertEqual(session.remainingSeconds, 0)
        XCTAssertEqual(session.phase, .revealing)
        XCTAssertEqual(session.answer, .timedOut)
        XCTAssertEqual(session.correctCount, 0)
        XCTAssertEqual(session.wasCorrect, false)
    }

    @MainActor
    func testTickDoesNothingWithoutATimeLimit() {
        let session = ChallengeSession(mode: .fillInTheBlank, difficulty: .beginner, seed: "notimer")
        XCTAssertNil(session.remainingSeconds)
        for _ in 0..<100 { session.tick() }
        XCTAssertEqual(session.phase, .asking, "제한 시간이 없는 단계는 시간으로 끝나면 안 됩니다.")
    }

    // MARK: - 기록

    @MainActor
    func testStoreKeepsTheBestScoreOnly() {
        let store = makeCleanStore()

        XCTAssertTrue(store.finish(
            mode: .fillInTheBlank, difficulty: .normal,
            correctCount: 7, questionCount: 10, bestStreak: 4
        ))
        // 더 낮은 점수는 최고 기록을 덮어쓰지 않는다.
        XCTAssertFalse(store.finish(
            mode: .fillInTheBlank, difficulty: .normal,
            correctCount: 3, questionCount: 10, bestStreak: 2
        ))

        let record = store.record(mode: .fillInTheBlank, difficulty: .normal)
        XCTAssertEqual(record.bestScore, 7)
        XCTAssertEqual(record.bestStreak, 4)
        XCTAssertEqual(record.playCount, 2)
        XCTAssertEqual(record.totalCorrect, 10)
        XCTAssertEqual(record.totalAnswered, 20)
        XCTAssertEqual(record.accuracy, 0.5, accuracy: 0.0001)
    }

    @MainActor
    func testRecordsAreKeptPerModeAndDifficulty() {
        let store = makeCleanStore()
        store.finish(
            mode: .fillInTheBlank, difficulty: .normal,
            correctCount: 9, questionCount: 10, bestStreak: 9
        )
        XCTAssertEqual(store.record(mode: .fillInTheBlank, difficulty: .normal).bestScore, 9)
        XCTAssertEqual(store.record(mode: .guessTheAuthor, difficulty: .normal).bestScore, 0)
        XCTAssertEqual(store.record(mode: .fillInTheBlank, difficulty: .hard).bestScore, 0)
    }

    @MainActor
    func testRecordsSurviveARestart() {
        let suite = "test.challenge.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        ChallengeStore(defaults: defaults).finish(
            mode: .guessTheAuthor, difficulty: .extreme,
            correctCount: 6, questionCount: 10, bestStreak: 3
        )

        let reopened = ChallengeStore(defaults: defaults)
        XCTAssertEqual(reopened.record(mode: .guessTheAuthor, difficulty: .extreme).bestScore, 6)
    }

    // MARK: - 도우미

    private func wrongIndex(for question: ChallengeQuestion) -> Int {
        question.choices.indices.first { $0 != question.correctIndex } ?? question.correctIndex
    }

    @MainActor
    private func makeCleanStore() -> ChallengeStore {
        let suite = "test.challenge.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return ChallengeStore(defaults: defaults)
    }
}

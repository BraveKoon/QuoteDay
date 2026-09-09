import Foundation

/// seed 문자열 하나로 완전히 재현되는 난수원.
///
/// 챌린지가 난수를 쓰면서도 결정적이어야 하는 이유는 두 가지다.
/// 테스트가 "이 seed 면 이 문제가 나온다"를 그대로 검증할 수 있고,
/// 화면이 다시 그려질 때마다 보기 순서가 뒤바뀌는 사고를 막을 수 있다.
public struct SeededRandomGenerator: RandomNumberGenerator {
    private let base: UInt64
    private var counter: UInt64 = 0

    public init(seed: String) {
        self.base = StableHash.fnv1a(seed)
    }

    public mutating func next() -> UInt64 {
        counter &+= 1
        // StableHash.mix 가 splitmix64 의 마무리 단계다. 입력을 황금비 간격으로
        // 밀어 넣으면 splitmix64 그대로가 된다.
        return StableHash.mix(base &+ counter &* 0x9E37_79B9_7F4A_7C15)
    }
}

/// 명언 데이터에서 챌린지 문제를 만든다.
///
/// 순수 함수다 — 저장소도 화면도 건드리지 않고, 같은 seed 에는 같은 문제를 돌려준다.
public struct ChallengeGenerator: Sendable {

    /// 한 판의 문제 수.
    public static let questionsPerRound = 10

    private let library: QuoteLibrary
    /// slug → 빈칸 후보 낱말. 문제 하나를 만들 때마다 200편 넘는 문장을 다시 자르지 않기 위해
    /// 생성기를 만들 때 한 번만 계산한다.
    private let wordsBySlug: [String: [String]]

    public init(library: QuoteLibrary = .shared) {
        self.library = library
        self.wordsBySlug = Dictionary(
            library.quotes.map { ($0.slug, BlankMaker.candidates(in: $0.text)) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    // MARK: - 한 판 만들기

    /// 서로 다른 명언에서 문제를 뽑아 한 판을 만든다.
    ///
    /// 같은 명언이 한 판에 두 번 나오지 않는다. 후보가 모자라면 나온 만큼만 돌려준다.
    public func makeRound(
        mode: ChallengeMode,
        difficulty: ChallengeDifficulty,
        count: Int = ChallengeGenerator.questionsPerRound,
        seed: String
    ) -> [ChallengeQuestion] {
        var rng = SeededRandomGenerator(seed: "round:\(mode.rawValue):\(difficulty.rawValue):\(seed)")
        let pool = sourceQuotes(for: mode).shuffled(using: &rng)

        var questions: [ChallengeQuestion] = []
        for quote in pool {
            guard questions.count < count else { break }
            if let question = makeQuestion(
                for: quote,
                mode: mode,
                difficulty: difficulty,
                seed: "\(seed):\(quote.slug)"
            ) {
                questions.append(question)
            }
        }
        return questions
    }

    /// 문제로 쓸 수 있는 명언.
    ///
    /// "누가 말했을까"에서는 귀속이 확인되지 않은 명언을 뺀다.
    /// 정답을 하나로 못 박는 형식이라, 그대로 내면 앱이 확인되지 않은 귀속을
    /// 정답이라고 가르치게 되기 때문이다.
    public func sourceQuotes(for mode: ChallengeMode) -> [Quote] {
        switch mode {
        case .fillInTheBlank:
            return library.quotes.filter { !(wordsBySlug[$0.slug] ?? []).isEmpty }
        case .guessTheAuthor:
            return DisputedAttribution.attributable(library.quotes)
        }
    }

    // MARK: - 문제 하나 만들기

    public func makeQuestion(
        for quote: Quote,
        mode: ChallengeMode,
        difficulty: ChallengeDifficulty,
        seed: String
    ) -> ChallengeQuestion? {
        switch mode {
        case .fillInTheBlank:
            return makeBlankQuestion(for: quote, difficulty: difficulty, seed: seed)
        case .guessTheAuthor:
            return makeAuthorQuestion(for: quote, difficulty: difficulty, seed: seed)
        }
    }

    // MARK: - 빈칸 채우기

    private func makeBlankQuestion(
        for quote: Quote,
        difficulty: ChallengeDifficulty,
        seed: String
    ) -> ChallengeQuestion? {
        var rng = SeededRandomGenerator(seed: "blank:\(difficulty.rawValue):\(seed)")
        let author = library.author(for: quote)

        guard let blanked = BlankMaker.make(
            from: quote.text,
            blankCount: difficulty.blankCount,
            preferLongWords: difficulty.similarity != .random,
            using: &rng
        ) else { return nil }

        let answer = blanked.answers.joined(separator: ChallengeGenerator.pairSeparator)

        // 오답 후보를 그럴듯한 순서로 **나눠서** 쌓는다.
        //
        // 한 배열에 이어 붙이면 안 된다. 전체 낱말이 1,000개가 넘어서, 앞에 붙인
        // 수십 개짜리 후보는 뽑힐 확률이 거의 없어지고 난이도 차이가 사라진다.
        // 우선순위가 다른 풀은 배열째로 나눠 두고 순서대로 시도한다.
        var pools: [[String]] = []
        switch difficulty.similarity {
        case .close:
            pools.append(words(inQuotesBy: quote.authorID, excluding: quote.slug))
            pools.append(words(inCategory: quote.category, excluding: quote.slug))
        case .related:
            pools.append(words(inCategory: quote.category, excluding: quote.slug))
        case .random:
            break
        }
        pools.append(allWords(excluding: quote.slug))

        var distractors: [String] = []
        var used = Set(blanked.answers)
        used.insert(answer)

        for slot in 0..<(difficulty.choiceCount - 1) {
            // 두 낱말짜리 문제에서는 한쪽만 바꾼 보기를 섞어 둔다. 훨씬 헷갈린다.
            let replaceOnly: Int? = blanked.answers.count > 1 && slot % 2 == 0
                ? Int(rng.next() % UInt64(blanked.answers.count))
                : nil

            guard let candidate = nextDistractor(
                answers: blanked.answers,
                replaceOnly: replaceOnly,
                pools: pools,
                similarity: difficulty.similarity,
                used: used,
                rng: &rng
            ) else { break }

            distractors.append(candidate)
            used.insert(candidate)
        }

        // 보기를 채우지 못하면 문제를 내지 않는다. 보기가 모자란 문제는 정답이 티가 난다.
        guard distractors.count == difficulty.choiceCount - 1 else { return nil }

        let choices = ([answer] + distractors).shuffled(using: &rng)
        guard let correctIndex = choices.firstIndex(of: answer) else { return nil }

        return ChallengeQuestion(
            id: "blank:\(difficulty.rawValue):\(seed)",
            mode: .fillInTheBlank,
            difficulty: difficulty,
            quote: quote,
            author: author,
            promptText: blanked.text,
            choices: choices,
            correctIndex: correctIndex,
            hint: difficulty.showsHint ? author.displayName : nil
        )
    }

    /// 두 낱말 보기를 이어 붙일 때 쓰는 구분자.
    public static let pairSeparator = " · "

    /// 오답 하나를 고른다.
    ///
    /// - Parameter replaceOnly: 값이 있으면 그 자리의 낱말만 바꾼 보기를 만든다.
    ///   나머지는 정답과 같아서, 한 낱말 차이로 갈리는 보기가 된다.
    private func nextDistractor(
        answers: [String],
        replaceOnly: Int?,
        pools: [[String]],
        similarity: ChallengeSimilarity,
        used: Set<String>,
        rng: inout SeededRandomGenerator
    ) -> String? {
        // 길이를 맞추는 조건부터 시도하고, 후보가 없으면 조건을 푼다.
        // 길이 조건이 풀보다 바깥에 있는 이유: 같은 인물이 쓴 낱말이라도 길이가
        // 크게 다르면 보기에서 정답이 튀어 보인다. 닮음보다 길이가 먼저다.
        let tolerances: [Int?] = similarity == .close ? [1, 2, nil] : [nil]

        for tolerance in tolerances {
            for pool in pools where !pool.isEmpty {
                var attempts = 0
                while attempts < 64 {
                    attempts += 1
                    guard let word = pool.randomElement(using: &rng) else { break }

                    var parts = answers
                    if let index = replaceOnly, parts.indices.contains(index) {
                        // 한 낱말만 바꾼 보기. 나머지는 정답과 같다.
                        guard word != parts[index] else { continue }
                        if let tolerance, abs(word.count - parts[index].count) > tolerance { continue }
                        parts[index] = word
                    } else {
                        // 전부 새로 뽑는다. 자리마다 서로 다른 낱말이어야 한다.
                        var replaced: [String] = []
                        var seen = Set<String>()
                        for original in answers {
                            guard let pick = pickWord(
                                pool: pool,
                                avoiding: seen.union([original]),
                                similarTo: tolerance == nil ? nil : original,
                                tolerance: tolerance,
                                rng: &rng
                            ) else { break }
                            seen.insert(pick)
                            replaced.append(pick)
                        }
                        guard replaced.count == answers.count else { continue }
                        parts = replaced
                    }

                    let candidate = parts.joined(separator: ChallengeGenerator.pairSeparator)
                    if !used.contains(candidate) { return candidate }
                }
            }
        }
        return nil
    }

    private func pickWord(
        pool: [String],
        avoiding: Set<String>,
        similarTo target: String?,
        tolerance: Int?,
        rng: inout SeededRandomGenerator
    ) -> String? {
        var attempts = 0
        while attempts < 64 {
            attempts += 1
            guard let word = pool.randomElement(using: &rng) else { return nil }
            guard !avoiding.contains(word) else { continue }
            if let target, let tolerance, abs(word.count - target.count) > tolerance { continue }
            return word
        }
        return nil
    }

    // MARK: - 누가 말했을까

    private func makeAuthorQuestion(
        for quote: Quote,
        difficulty: ChallengeDifficulty,
        seed: String
    ) -> ChallengeQuestion? {
        var rng = SeededRandomGenerator(seed: "author:\(difficulty.rawValue):\(seed)")
        let author = library.author(for: quote)
        guard author.id != Author.unknown.id else { return nil }

        // 낱말 풀과 같은 이유로 배열을 이어 붙이지 않는다. 전체 인물 백여 명 뒤에
        // 붙인 "같은 시대 · 같은 직업" 몇 명은 뽑힐 확률이 거의 없어진다.
        let others = AuthorLibrary.all.filter { $0.id != author.id && $0.id != Author.unknown.id }
        var pools: [[Author]] = []
        switch difficulty.similarity {
        case .close:
            pools.append(others.filter { sharesOccupation($0, author) && sharesEra($0, author) })
            pools.append(others.filter { sharesOccupation($0, author) })
        case .related:
            pools.append(others.filter {
                $0.nationality == author.nationality || sharesOccupation($0, author)
            })
        case .random:
            break
        }
        pools.append(others)

        var names: [String] = []
        var used: Set<String> = [author.displayName]
        for pool in pools where !pool.isEmpty {
            var attempts = 0
            while names.count < difficulty.choiceCount - 1 && attempts < 128 {
                attempts += 1
                guard let candidate = pool.randomElement(using: &rng) else { break }
                let name = candidate.displayName
                guard !used.contains(name) else { continue }
                used.insert(name)
                names.append(name)
            }
            if names.count == difficulty.choiceCount - 1 { break }
        }
        guard names.count == difficulty.choiceCount - 1 else { return nil }

        let choices = ([author.displayName] + names).shuffled(using: &rng)
        guard let correctIndex = choices.firstIndex(of: author.displayName) else { return nil }

        return ChallengeQuestion(
            id: "author:\(difficulty.rawValue):\(seed)",
            mode: .guessTheAuthor,
            difficulty: difficulty,
            quote: quote,
            author: author,
            promptText: quote.text,
            choices: choices,
            correctIndex: correctIndex,
            hint: difficulty.showsHint ? "\(author.nationality) · \(author.occupation)" : nil
        )
    }

    /// 직업 문자열("정치인 · 작가")에 겹치는 낱말이 있는지.
    private func sharesOccupation(_ lhs: Author, _ rhs: Author) -> Bool {
        !Set(occupationTokens(lhs)).isDisjoint(with: Set(occupationTokens(rhs)))
    }

    private func occupationTokens(_ author: Author) -> [String] {
        author.occupation
            .components(separatedBy: CharacterSet(charactersIn: "·,/"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// 생몰 연도가 겹치거나 가까운지. 연도를 모르면 같은 시대로 보지 않는다.
    private func sharesEra(_ lhs: Author, _ rhs: Author) -> Bool {
        guard let a = lhs.birthYear, let b = rhs.birthYear else { return false }
        return abs(a - b) <= 120
    }

    // MARK: - 낱말 풀

    private func words(in quotes: [Quote], excluding slug: String) -> [String] {
        quotes.filter { $0.slug != slug }.flatMap { wordsBySlug[$0.slug] ?? [] }
    }

    private func allWords(excluding slug: String) -> [String] {
        words(in: library.quotes, excluding: slug)
    }

    private func words(inCategory category: AppCategory, excluding slug: String) -> [String] {
        words(in: library.quotes(in: category), excluding: slug)
    }

    private func words(inQuotesBy authorID: String, excluding slug: String) -> [String] {
        words(in: library.quotes(byAuthor: authorID), excluding: slug)
    }
}

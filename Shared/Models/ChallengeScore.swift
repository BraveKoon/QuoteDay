import Foundation

/// 챌린지 랭킹 점수와 순위.
public enum ChallengeScore {

    /// 한 판의 점수. 맞힌 개수 × 단계 배점.
    public static func points(correctCount: Int, difficulty: ChallengeDifficulty) -> Int {
        max(0, correctCount) * difficulty.pointsPerQuestion
    }

    /// 랭킹에 올라가는 총점.
    ///
    /// **누적이 아니라 모드·단계별 최고 기록의 합**이다. 누적으로 하면 랭킹이
    /// 실력이 아니라 앱을 켜 둔 시간을 재게 된다. 최고 기록의 합이면
    /// 같은 판을 여러 번 돌아도 오르지 않고, 안 해 본 단계를 해 보면 오른다.
    public static func total(bestScore: (ChallengeMode, ChallengeDifficulty) -> Int) -> Int {
        var sum = 0
        for mode in ChallengeMode.allCases {
            for difficulty in ChallengeDifficulty.allCases {
                sum += points(correctCount: bestScore(mode, difficulty), difficulty: difficulty)
            }
        }
        return sum
    }

    /// 모든 모드·단계를 다 맞혔을 때의 총점.
    public static let maximumTotal: Int = {
        ChallengeMode.allCases.count
            * ChallengeDifficulty.allCases.reduce(0) { $0 + $1.perfectScore }
    }()
}

/// 점수 분포를 세는 구간.
///
/// 사람마다 점수 레코드를 하나씩 두고 그것을 **세어서** 순위를 내려면
/// 조건 검색이 필요하고, CloudKit 에서 조건 검색은 대시보드에서 필드마다
/// 인덱스를 켜 줘야 한다. 그 설정을 잊으면 실기기에서만 조용히 실패한다.
///
/// 그래서 분포를 미리 구간으로 나눠 세어 둔다. 구간 레코드는 이름이 정해져 있어
/// **ID 로 한 번에 가져올 수 있다.** 하트와 같은 원칙이다.
public enum RankBucket {
    /// 구간 하나의 폭(점).
    public static let width = 200
    /// 구간 개수. `ChallengeScore.maximumTotal` 을 덮을 만큼 둔다.
    public static let count = (ChallengeScore.maximumTotal / width) + 1

    /// 이 점수가 속하는 구간.
    public static func index(for total: Int) -> Int {
        min(max(0, total) / width, count - 1)
    }

    public static let allIndices: [Int] = Array(0..<count)
}

/// 지금 내 순위.
public struct RankStanding: Hashable, Sendable {
    /// 내 총점.
    public let total: Int
    /// 상위 몇 퍼센트인지. 표본이 모자라면 nil.
    public let percentile: Int?
    /// 집계에 들어간 사람 수.
    public let playerCount: Int

    public init(total: Int, percentile: Int?, playerCount: Int) {
        self.total = total
        self.percentile = percentile
        self.playerCount = playerCount
    }

    /// 이 수보다 사람이 적으면 순위를 내지 않는다.
    ///
    /// 세 명 중 한 명이 "상위 33%"인 것은 숫자일 뿐 뜻이 없다.
    /// 모자랄 때는 순위 대신 그 사실을 말한다.
    public static let minimumPlayers = 20

    public static let empty = RankStanding(total: 0, percentile: nil, playerCount: 0)

    /// 화면에 크게 띄우는 한 줄.
    public var headline: String {
        guard let percentile else { return "\(total)점" }
        return "상위 \(percentile)%"
    }

    /// 그 아래 설명.
    public var detail: String {
        guard percentile != nil else {
            return playerCount < Self.minimumPlayers
                ? "순위를 낼 만큼 기록이 모이지 않았어요. \(Self.minimumPlayers)명부터 보여 드려요."
                : "아직 순위를 계산하지 못했어요."
        }
        return "\(playerCount)명 중 \(total)점"
    }

    /// 구간을 세어 순위를 낸다.
    ///
    /// - Parameters:
    ///   - counts: 구간 인덱스 → 그 구간에 속한 사람 수.
    ///   - total: 내 총점.
    ///
    /// 내 구간 안에서의 정확한 위치는 알 수 없으므로 **구간의 한가운데**로 본다.
    /// 맨 앞으로 치면 실제보다 후하고, 맨 뒤로 치면 박하다.
    public static func from(counts: [Int: Int], total: Int) -> RankStanding {
        let playerCount = counts.values.reduce(0, +)
        guard playerCount >= minimumPlayers else {
            return RankStanding(total: total, percentile: nil, playerCount: playerCount)
        }

        let myBucket = RankBucket.index(for: total)
        let above = counts.filter { $0.key > myBucket }.values.reduce(0, +)
        let mine = max(1, counts[myBucket] ?? 1)
        let rank = above + Int((Double(mine) / 2).rounded(.up))

        let raw = Int((Double(rank) / Double(playerCount) * 100).rounded(.up))
        return RankStanding(
            total: total,
            percentile: min(100, max(1, raw)),
            playerCount: playerCount
        )
    }
}

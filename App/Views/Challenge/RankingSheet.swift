import SwiftUI

/// 챌린지 랭킹. 내가 전체에서 어디쯤인지 보여 준다.
///
/// 다른 사람의 이름이나 점수는 보여 주지 않는다. 필요한 정보는 "내가 어디쯤인가"
/// 하나뿐이고, 그 이상을 모으면 지켜야 할 것만 늘어난다.
struct RankingSheet: View {
    @Environment(ChallengeStore.self) private var store
    @Environment(RankStore.self) private var rank
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ClayTheme.Spacing.m) {
                    standingCard
                    breakdownCard
                    ruleCard
                }
                .padding(ClayTheme.Spacing.m)
                .padding(.bottom, ClayTheme.Spacing.xl)
            }
            .scrollIndicators(.hidden)
            .clayBackground()
            .navigationTitle("랭킹")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .task { await rank.submit(total: store.rankingTotal) }
        }
    }

    // MARK: - 내 순위

    private var standingCard: some View {
        VStack(spacing: ClayTheme.Spacing.xs) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(ClayTheme.accent)
                .padding(.bottom, 2)

            if rank.isLoading && rank.standing.playerCount == 0 {
                ProgressView()
                    .padding(.vertical, ClayTheme.Spacing.s)
            } else {
                Text(rank.standing.headline)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(ClayTheme.textPrimary)
                    .monospacedDigit()
            }

            Text(rank.standing.detail)
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let message = rank.availability.message(subject: "랭킹") {
                Label(message, systemImage: "icloud.slash")
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, ClayTheme.Spacing.xs)
            }
        }
        .padding(.vertical, ClayTheme.Spacing.l)
        .padding(.horizontal, ClayTheme.Spacing.m)
        .frame(maxWidth: .infinity)
        .clayCard(cornerRadius: ClayTheme.Radius.hero)
        .accessibilityElement(children: .combine)
    }

    // MARK: - 점수 내역

    private var breakdownCard: some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
            HStack {
                Text("점수 내역")
                    .font(ClayFont.headline())
                    .foregroundStyle(ClayTheme.textPrimary)
                Spacer()
                Text("\(store.rankingTotal) / \(ChallengeScore.maximumTotal)")
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.textSecondary)
                    .monospacedDigit()
            }

            ForEach(ChallengeMode.allCases) { mode in
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.title)
                        .font(ClayFont.caption())
                        .foregroundStyle(ClayTheme.textSecondary)

                    ForEach(ChallengeDifficulty.allCases) { difficulty in
                        breakdownRow(mode: mode, difficulty: difficulty)
                    }
                }
                .padding(.top, mode == ChallengeMode.allCases.first ? 0 : ClayTheme.Spacing.xs)
            }
        }
        .padding(ClayTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clayCard()
    }

    private func breakdownRow(mode: ChallengeMode, difficulty: ChallengeDifficulty) -> some View {
        let best = store.record(mode: mode, difficulty: difficulty).bestScore
        let points = ChallengeScore.points(correctCount: best, difficulty: difficulty)

        return HStack(spacing: ClayTheme.Spacing.xs) {
            Text("\(difficulty.rawValue)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(ClayTheme.textOnTint)
                .frame(width: 20, height: 20)
                .background {
                    RoundedRectangle(cornerRadius: ClayTheme.Radius.tiny, style: .continuous)
                        .fill(difficulty.tint)
                }

            Text(difficulty.title)
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textPrimary)

            Spacer(minLength: 0)

            Text("\(best)문제 × \(difficulty.pointsPerQuestion)점")
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
                .monospacedDigit()

            Text("\(points)")
                .font(ClayFont.caption())
                .foregroundStyle(points > 0 ? ClayTheme.textPrimary : ClayTheme.textSecondary)
                .monospacedDigit()
                .frame(minWidth: 40, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(mode.title) \(difficulty.rawValue)단계 \(points)점")
    }

    // MARK: - 규칙

    private var ruleCard: some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.xs) {
            Label("점수는 이렇게 계산해요", systemImage: "info.circle")
                .font(ClayFont.headline())
                .foregroundStyle(ClayTheme.textPrimary)

            line("맞힌 문제 하나에 단계 배점만큼 점수가 붙어요. 1단계 10점부터 5단계 80점까지입니다.")
            line("**같은 판을 여러 번 돌아도 오르지 않아요.** 모드·단계마다 최고 기록만 셉니다.")
            line("안 해 본 단계를 해 보면 오릅니다. 5단계를 절반만 맞혀도 1단계를 다 맞힌 것보다 높아요.")
            line("순위는 \(RankStanding.minimumPlayers)명부터 보여 드려요. 그보다 적으면 숫자에 뜻이 없습니다.")
            line("다른 사람의 이름이나 점수는 보여 주지 않아요. 내가 어디쯤인지만 알려 드립니다.")
        }
        .padding(ClayTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clayCard()
    }

    private func line(_ text: String) -> some View {
        HStack(alignment: .top, spacing: ClayTheme.Spacing.xs) {
            Text("·")
            Text(.init(text))
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(ClayFont.caption())
        .foregroundStyle(ClayTheme.textSecondary)
    }
}

#Preview {
    RankingSheet()
        .injecting(AppEnvironment.preview())
}

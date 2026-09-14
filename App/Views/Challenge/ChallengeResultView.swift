import SwiftUI

/// 한 판이 끝난 뒤의 결과 화면. `ChallengeQuizView` 안에서 자리를 바꿔 나타난다.
struct ChallengeResultView: View {
    @Environment(ChallengeStore.self) private var store

    let result: ChallengeResult
    let onClose: () -> Void
    /// 같은 단계로 한 판 더. 문제는 새로 뽑힌다.
    let onPlayAgain: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: ClayTheme.Spacing.m) {
                scoreCard
                statRow
                recordCard
            }
            .padding(.horizontal, ClayTheme.Spacing.m)
            .padding(.vertical, ClayTheme.Spacing.l)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            // 한 판 더 하려고 화면을 닫고 목록으로 돌아갈 이유가 없다.
            // 여기서 바로 이어서 하게 한다 — 문제는 매번 새로 뽑힌다.
            VStack(spacing: ClayTheme.Spacing.xs) {
                Button("한 판 더") { onPlayAgain() }
                    .clayButton(.primary, fullWidth: true)
                Button("닫기") { onClose() }
                    .clayButton(.secondary, fullWidth: true)
            }
            .padding(.horizontal, ClayTheme.Spacing.m)
            .padding(.bottom, ClayTheme.Spacing.m)
            .background(ClayTheme.background)
        }
    }

    // MARK: - 점수

    private var scoreCard: some View {
        VStack(spacing: ClayTheme.Spacing.s) {
            if result.isNewRecord {
                Label("최고 기록", systemImage: "sparkles")
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.textOnTint)
                    .padding(.horizontal, ClayTheme.Spacing.s)
                    .padding(.vertical, 4)
                    .background {
                        Capsule().fill(ClayPalette.lemon)
                    }
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(result.correctCount)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(ClayTheme.accent)
                    .monospacedDigit()
                Text("/ \(result.questionCount)")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(ClayTheme.textSecondary)
                    .monospacedDigit()
            }

            Text(result.headline)
                .font(ClayFont.headline())
                .foregroundStyle(ClayTheme.textPrimary)

            Text("\(result.difficulty.rawValue)단계 \(result.difficulty.title) · \(result.mode.title)")
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
        }
        .padding(.vertical, ClayTheme.Spacing.l)
        .frame(maxWidth: .infinity)
        .clayCard(cornerRadius: ClayTheme.Radius.hero)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(result.questionCount)문제 중 \(result.correctCount)문제를 맞혔습니다")
    }

    // MARK: - 세부 기록

    private var statRow: some View {
        HStack(spacing: ClayTheme.Spacing.s) {
            statBox(title: "정답률", value: percentText(result.accuracy))
            statBox(title: "최고 연속", value: "\(result.bestStreak)")
            statBox(
                title: "점수",
                value: "\(ChallengeScore.points(correctCount: result.correctCount, difficulty: result.difficulty))"
            )
        }
    }

    private func statBox(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(ClayFont.title())
                .foregroundStyle(ClayTheme.textPrimary)
                .monospacedDigit()
            Text(title)
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
        }
        .padding(.vertical, ClayTheme.Spacing.m)
        .frame(maxWidth: .infinity)
        .clayCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(value)")
    }

    /// 이 단계의 누적 기록. 랭킹은 시즌 기록으로 매기므로 둘을 나눠 보여 준다.
    private var recordCard: some View {
        let record = store.record(mode: result.mode, difficulty: result.difficulty)
        let lifetime = store.lifetimeRecord(mode: result.mode, difficulty: result.difficulty)

        return VStack(alignment: .leading, spacing: ClayTheme.Spacing.xs) {
            Text("이 단계 · \(store.season.title)")
                .font(ClayFont.headline())
                .foregroundStyle(ClayTheme.textPrimary)

            recordLine("최고 점수", "\(record.bestScore) / \(result.questionCount)")
            recordLine("최고 연속", "\(record.bestStreak)")
            recordLine("푼 판", "\(record.playCount)판")
            recordLine("누적 정답률", percentText(record.accuracy))
            recordLine(
                "랭킹에 올라가는 점수",
                "\(ChallengeScore.points(correctCount: record.bestScore, difficulty: result.difficulty))점"
            )

            if lifetime.bestScore > record.bestScore || lifetime.playCount > record.playCount {
                ClayDivider()
                    .padding(.vertical, 2)
                recordLine("통산 최고 점수", "\(lifetime.bestScore) / \(result.questionCount)")
                recordLine("통산 푼 판", "\(lifetime.playCount)판")
            }
        }
        .padding(ClayTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clayCard()
    }

    private func recordLine(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
            Spacer()
            Text(value)
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textPrimary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    private func percentText(_ ratio: Double) -> String {
        "\(Int((ratio * 100).rounded()))%"
    }
}

#Preview {
    ChallengeResultView(
        result: ChallengeResult(
            mode: .fillInTheBlank,
            difficulty: .veryHard,
            correctCount: 8,
            questionCount: 10,
            bestStreak: 5,
            isNewRecord: true
        ),
        onClose: {},
        onPlayAgain: {}
    )
    .clayBackground()
    .injecting(AppEnvironment.preview())
}

import SwiftUI

/// 한 판이 끝난 뒤의 결과 화면. `ChallengeQuizView` 안에서 자리를 바꿔 나타난다.
struct ChallengeResultView: View {
    @Environment(ChallengeStore.self) private var store

    let result: ChallengeResult
    let onClose: () -> Void

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
            Button("닫기") { onClose() }
                .clayButton(.primary, fullWidth: true)
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

    /// 이 단계의 누적 기록.
    private var recordCard: some View {
        let record = store.record(mode: result.mode, difficulty: result.difficulty)

        return VStack(alignment: .leading, spacing: ClayTheme.Spacing.xs) {
            Text("이 단계 누적")
                .font(ClayFont.headline())
                .foregroundStyle(ClayTheme.textPrimary)

            recordLine("최고 점수", "\(record.bestScore) / \(result.questionCount)")
            recordLine("최고 연속", "\(record.bestStreak)")
            recordLine("푼 판", "\(record.playCount)판")
            recordLine("누적 정답률", percentText(record.accuracy))
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
        onClose: {}
    )
    .clayBackground()
    .injecting(AppEnvironment.preview())
}

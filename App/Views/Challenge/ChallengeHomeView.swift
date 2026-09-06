import SwiftUI

/// 챌린지 탭의 첫 화면. 모드와 단계를 고르고 판을 시작한다.
struct ChallengeHomeView: View {
    @Environment(ChallengeStore.self) private var store

    @State private var session: ChallengeSession?

    private var mode: ChallengeMode { store.lastMode }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClayTheme.Spacing.l) {
                header
                    .clayAppear()

                modePicker
                    .clayAppear(delay: 0.05)

                difficultySection
                    .clayAppear(delay: 0.1)

                ruleCard
                    .clayAppear(delay: 0.15)
            }
            .padding(.horizontal, ClayTheme.Spacing.m)
            .padding(.top, ClayTheme.Spacing.m)
            // 커스텀 탭 바에 가리지 않도록 여유를 둔다.
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
        .clayBackground()
        .fullScreenCover(item: $session) { session in
            ChallengeQuizView(session: session) { self.session = nil }
        }
    }

    // MARK: - 헤더

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("얼마나 기억하고 있나요")
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
            Text("챌린지")
                .font(ClayFont.hero())
                .foregroundStyle(ClayTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - 모드

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
            Text("문제 유형")
                .font(ClayFont.headline())
                .foregroundStyle(ClayTheme.textPrimary)

            HStack(spacing: ClayTheme.Spacing.s) {
                ForEach(ChallengeMode.allCases) { candidate in
                    Button {
                        store.lastMode = candidate
                    } label: {
                        modeCard(candidate)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(candidate == mode ? [.isSelected, .isButton] : .isButton)
                }
            }

            Text(mode.summary)
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
        }
    }

    private func modeCard(_ candidate: ChallengeMode) -> some View {
        let isSelected = candidate == mode
        return VStack(spacing: ClayTheme.Spacing.xs) {
            Image(systemName: candidate.symbol)
                .font(.system(size: 22, weight: .semibold))
            Text(candidate.title)
                .font(ClayFont.callout())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(isSelected ? ClayTheme.textOnAccent : ClayTheme.textSecondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, ClayTheme.Spacing.m)
        .background {
            RoundedRectangle(cornerRadius: ClayTheme.Radius.card, style: .continuous)
                .fill(isSelected ? ClayTheme.accent : ClayTheme.surface)
        }
        .overlay {
            if !isSelected {
                RoundedRectangle(cornerRadius: ClayTheme.Radius.card, style: .continuous)
                    .strokeBorder(ClayTheme.separator, lineWidth: 1)
            }
        }
        .contentShape(Rectangle())
    }

    // MARK: - 단계

    private var difficultySection: some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
            Text("단계")
                .font(ClayFont.headline())
                .foregroundStyle(ClayTheme.textPrimary)

            VStack(spacing: ClayTheme.Spacing.s) {
                ForEach(ChallengeDifficulty.allCases) { difficulty in
                    Button {
                        start(difficulty)
                    } label: {
                        difficultyRow(difficulty)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func difficultyRow(_ difficulty: ChallengeDifficulty) -> some View {
        let record = store.record(mode: mode, difficulty: difficulty)

        return HStack(spacing: ClayTheme.Spacing.s) {
            Text("\(difficulty.rawValue)")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(ClayTheme.textOnTint)
                .frame(width: 34, height: 34)
                .background {
                    RoundedRectangle(cornerRadius: ClayTheme.Radius.chip, style: .continuous)
                        .fill(difficulty.tint)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(difficulty.title)
                    .font(ClayFont.callout())
                    .foregroundStyle(ClayTheme.textPrimary)
                Text(difficulty.detail(for: mode))
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: ClayTheme.Spacing.xs)

            VStack(alignment: .trailing, spacing: 2) {
                if record.hasPlayed {
                    Text("최고 \(record.bestScore)/\(ChallengeGenerator.questionsPerRound)")
                        .font(ClayFont.caption())
                        .foregroundStyle(ClayTheme.textPrimary)
                    Text("\(record.playCount)판")
                        .font(ClayFont.caption())
                        .foregroundStyle(ClayTheme.textSecondary)
                } else {
                    Text("기록 없음")
                        .font(ClayFont.caption())
                        .foregroundStyle(ClayTheme.textSecondary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ClayTheme.textSecondary)
        }
        .padding(ClayTheme.Spacing.s)
        .frame(maxWidth: .infinity)
        .clayCard()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(difficulty.rawValue)단계 \(difficulty.title). \(difficulty.detail(for: mode))")
        .accessibilityHint(record.hasPlayed ? "최고 기록 \(record.bestScore)점" : "아직 기록이 없습니다")
    }

    // MARK: - 규칙

    private var ruleCard: some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.xs) {
            Label("규칙", systemImage: "info.circle")
                .font(ClayFont.headline())
                .foregroundStyle(ClayTheme.textPrimary)

            ruleLine("한 판은 \(ChallengeGenerator.questionsPerRound)문제입니다.")
            ruleLine("단계가 올라가면 보기가 늘고, 힌트가 사라지고, 오답이 정답과 비슷해집니다.")
            ruleLine("4단계부터는 제한 시간이 있습니다. 시간을 넘기면 오답으로 칩니다.")
            ruleLine("모든 단계는 처음부터 열려 있습니다. 아무 데서나 시작하세요.")

            if mode == .guessTheAuthor {
                ClayDivider()
                    .padding(.vertical, ClayTheme.Spacing.xs)
                ruleLine("누가 말했는지 확인되지 않은 명언은 이 유형에서 빼 두었습니다. 정답을 하나로 정할 수 없기 때문입니다.")
            }
        }
        .padding(ClayTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clayCard()
    }

    private func ruleLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: ClayTheme.Spacing.xs) {
            Text("·")
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(ClayFont.caption())
        .foregroundStyle(ClayTheme.textSecondary)
    }

    // MARK: - 시작

    private func start(_ difficulty: ChallengeDifficulty) {
        session = ChallengeSession(mode: mode, difficulty: difficulty)
    }
}

#Preview {
    ChallengeHomeView()
        .injecting(AppEnvironment.preview())
}

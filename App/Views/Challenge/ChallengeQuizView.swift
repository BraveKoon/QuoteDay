import SwiftUI

/// 문제를 푸는 화면. 판이 끝나면 같은 자리에서 결과로 넘어간다.
struct ChallengeQuizView: View {
    @Environment(ChallengeStore.self) private var store

    let session: ChallengeSession
    /// 닫기. 부모가 시트를 내린다.
    let onClose: () -> Void

    @State private var isNewRecord = false
    @State private var hasRecorded = false

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider().overlay(ClayTheme.separator)

            if session.questionCount == 0 {
                // 문제를 하나도 만들지 못한 경우. 데이터가 모자랄 때만 일어난다.
                emptyState
            } else if session.phase == .finished {
                ChallengeResultView(
                    result: ChallengeResult(
                        mode: session.mode,
                        difficulty: session.difficulty,
                        correctCount: session.correctCount,
                        questionCount: session.questionCount,
                        bestStreak: session.bestStreak,
                        isNewRecord: isNewRecord
                    ),
                    onClose: onClose
                )
            } else if let question = session.currentQuestion {
                quiz(question)
            } else {
                emptyState
            }
        }
        .clayBackground()
        // 제한 시간이 있는 단계에서만 1초마다 깨어난다.
        // 문제가 바뀌면 id 가 바뀌어 타이머가 처음부터 다시 돈다.
        .task(id: session.index) {
            guard session.difficulty.timeLimit != nil else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                session.tick()
            }
        }
        .onChange(of: session.phase) { _, phase in
            guard phase == .finished, !hasRecorded else { return }
            hasRecorded = true
            isNewRecord = store.finish(
                mode: session.mode,
                difficulty: session.difficulty,
                correctCount: session.correctCount,
                questionCount: session.questionCount,
                bestStreak: session.bestStreak
            )
        }
    }

    // MARK: - 상단

    private var topBar: some View {
        HStack(spacing: ClayTheme.Spacing.s) {
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ClayTheme.textSecondary)
                    .frame(width: 32, height: 32)
                    .claySunken(cornerRadius: ClayTheme.Radius.chip)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("챌린지 그만두기")

            VStack(alignment: .leading, spacing: 1) {
                Text("\(session.difficulty.rawValue)단계 · \(session.difficulty.title)")
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.textSecondary)
                Text(session.mode.title)
                    .font(ClayFont.callout())
                    .foregroundStyle(ClayTheme.textPrimary)
            }

            Spacer(minLength: 0)

            if session.phase != .finished {
                Text("\(session.displayNumber) / \(session.questionCount)")
                    .font(ClayFont.callout())
                    .foregroundStyle(ClayTheme.textPrimary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, ClayTheme.Spacing.m)
        .padding(.vertical, ClayTheme.Spacing.s)
    }

    // MARK: - 문제

    private func quiz(_ question: ChallengeQuestion) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: ClayTheme.Spacing.m) {
                    if let remaining = session.remainingSeconds {
                        timerBar(remaining: remaining)
                    }

                    promptCard(question)

                    if let hint = question.hint {
                        Label(hint, systemImage: "lightbulb")
                            .font(ClayFont.caption())
                            .foregroundStyle(ClayTheme.textSecondary)
                            .padding(.horizontal, ClayTheme.Spacing.s)
                            .padding(.vertical, ClayTheme.Spacing.xs)
                            .claySunken(cornerRadius: ClayTheme.Radius.chip)
                    }

                    choiceList(question)

                    if session.phase == .revealing {
                        feedbackCard(question)
                    }
                }
                .padding(.horizontal, ClayTheme.Spacing.m)
                .padding(.top, ClayTheme.Spacing.m)
                .padding(.bottom, ClayTheme.Spacing.m)
            }
            .scrollIndicators(.hidden)

            if session.phase == .revealing {
                Button(session.isLastQuestion ? "결과 보기" : "다음 문제") {
                    session.advance()
                }
                .clayButton(.primary, fullWidth: true)
                .padding(.horizontal, ClayTheme.Spacing.m)
                .padding(.bottom, ClayTheme.Spacing.m)
            }
        }
    }

    /// 남은 시간 막대. 색은 남은 비율에 따라 바뀐다.
    private func timerBar(remaining: Int) -> some View {
        let limit = session.difficulty.timeLimit ?? 1
        let ratio = max(0, min(1, Double(remaining) / Double(limit)))

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label("남은 시간", systemImage: "timer")
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.textSecondary)
                Spacer()
                Text("\(remaining)초")
                    .font(ClayFont.caption())
                    .foregroundStyle(ratio <= 0.25 ? ClayTheme.danger : ClayTheme.textPrimary)
                    .monospacedDigit()
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(ClayTheme.surfaceSunken)
                    Capsule()
                        .fill(ratio <= 0.25 ? ClayTheme.danger : ClayTheme.accent)
                        .frame(width: proxy.size.width * ratio)
                }
            }
            .frame(height: 6)
            .animation(.linear(duration: 0.25), value: remaining)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("남은 시간 \(remaining)초")
    }

    private func promptCard(_ question: ChallengeQuestion) -> some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
            blankedText(question.promptText)
                .font(ClayFont.quote())
                .foregroundStyle(ClayTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if question.mode == .fillInTheBlank && session.phase == .revealing {
                Text("— \(question.author.displayName)")
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.textSecondary)
            }
        }
        .padding(ClayTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clayCard(cornerRadius: ClayTheme.Radius.hero)
    }

    /// 빈칸만 강조색으로 그린다. `Text` 를 이어 붙여 줄바꿈이 정상으로 동작하게 한다.
    private func blankedText(_ text: String) -> Text {
        let parts = text.components(separatedBy: ChallengeQuestion.blankMarker)
        var result = Text(parts[0])
        for part in parts.dropFirst() {
            result = result
                + Text(ChallengeQuestion.blankMarker).foregroundStyle(ClayTheme.accent)
                + Text(part)
        }
        return result
    }

    private func choiceList(_ question: ChallengeQuestion) -> some View {
        VStack(spacing: ClayTheme.Spacing.s) {
            ForEach(Array(question.choices.enumerated()), id: \.offset) { index, choice in
                Button {
                    session.select(index)
                } label: {
                    choiceRow(question, index: index, choice: choice)
                }
                .buttonStyle(.plain)
                .disabled(session.phase != .asking)
            }
        }
    }

    private func choiceRow(_ question: ChallengeQuestion, index: Int, choice: String) -> some View {
        let revealed = session.phase == .revealing
        let isCorrect = question.isCorrect(index)
        let isPicked = session.isPicked(index)

        // 답을 낸 뒤에는 정답을 초록으로, 내가 고른 오답을 빨강으로 표시한다.
        // 고르지 않은 오답은 그대로 두어 화면이 어지러워지지 않게 한다.
        let tint: Color? = {
            guard revealed else { return nil }
            if isCorrect { return ClayPalette.mint }
            if isPicked { return ClayPalette.coral }
            return nil
        }()

        return HStack(spacing: ClayTheme.Spacing.s) {
            Text(choice)
                .font(ClayFont.callout())
                .foregroundStyle(tint == nil ? ClayTheme.textPrimary : ClayTheme.textOnTint)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            if revealed && isCorrect {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(ClayTheme.textOnTint)
            } else if revealed && isPicked {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(ClayTheme.textOnTint)
            }
        }
        .padding(ClayTheme.Spacing.s + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clayCard(cornerRadius: ClayTheme.Radius.control, tint: tint)
        .contentShape(Rectangle())
        .accessibilityLabel(choice)
        .accessibilityAddTraits(revealed && isCorrect ? [.isSelected, .isButton] : .isButton)
    }

    private func feedbackCard(_ question: ChallengeQuestion) -> some View {
        let correct = session.wasCorrect ?? false
        let timedOut = session.answer == .timedOut

        return VStack(alignment: .leading, spacing: ClayTheme.Spacing.xs) {
            Label(
                correct ? "정답입니다" : (timedOut ? "시간이 지났습니다" : "아쉽습니다"),
                systemImage: correct ? "checkmark.seal.fill" : (timedOut ? "timer" : "xmark.seal.fill")
            )
            .font(ClayFont.headline())
            .foregroundStyle(correct ? ClayTheme.accent : ClayTheme.danger)

            if !correct {
                Text("정답: \(question.correctAnswer)")
                    .font(ClayFont.callout())
                    .foregroundStyle(ClayTheme.textPrimary)
            }

            ClayDivider()
                .padding(.vertical, 2)

            Text(question.revealedText)
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("— \(question.author.displayName) · \(question.author.occupation)")
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
        }
        .padding(ClayTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .claySunken(cornerRadius: ClayTheme.Radius.card)
    }

    // MARK: - 빈 상태

    private var emptyState: some View {
        VStack(spacing: ClayTheme.Spacing.s) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 34))
                .foregroundStyle(ClayTheme.textSecondary)
            Text("문제를 만들지 못했습니다")
                .font(ClayFont.headline())
                .foregroundStyle(ClayTheme.textPrimary)
            Text("이 조건으로 낼 수 있는 명언이 부족합니다. 단계를 낮춰 보세요.")
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
                .multilineTextAlignment(.center)
            Button("돌아가기") { onClose() }
                .clayButton(.secondary)
                .padding(.top, ClayTheme.Spacing.s)
            Spacer()
        }
        .padding(ClayTheme.Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ChallengeQuizView(
        session: ChallengeSession(mode: .fillInTheBlank, difficulty: .normal, seed: "preview"),
        onClose: {}
    )
    .injecting(AppEnvironment.preview())
}

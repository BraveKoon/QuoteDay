import SwiftUI

/// 명언 상세 화면의 "AI 해설" 카드.
///
/// 이 기능은 **무료**이고, 해설은 **기기 안에서** 만들어진다(Apple Foundation
/// Models). 그래서 카드에도 그 사실을 적는다 — 사용자는 무엇이 어디로 가는지
/// 알아야 하고, AI 가 쓴 글이라는 것도 알아야 한다.
///
/// 상태마다 다른 얼굴을 갖는다.
/// - 만들 수 있고 아직 안 만듦 → 소개 + "해설 보기"
/// - 만드는 중 → 부분 결과가 차례로 나타난다
/// - 완성 → 세 문단 + "다시 생성"
/// - 실패 → 이유 + "다시 시도"
/// - 이 기기에서 못 씀 → **안내 문구** (기능을 숨기지 않는다)
struct QuoteExplanationCard: View {
    let presentation: QuotePresentation

    @Environment(QuoteExplanationStore.self) private var store
    @Environment(AppSettings.self) private var settings

    private var language: AppLanguage { settings.language }
    private var availability: QuoteExplainerAvailability { store.availability(for: language) }
    private var phase: QuoteExplanationStore.Phase { store.phase(for: presentation.quote, language: language) }

    var body: some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
            SectionHeader("AI 해설", subtitle: "온디바이스 AI") {
                Label(L("무료"), systemImage: "sparkles")
                    .labelStyle(.titleAndIcon)
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.accent)
            }

            content
        }
        .padding(ClayTheme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clayCard()
        .clayAppear(delay: 0.06)
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .ready(let explanation):
            explanationBody(explanation, isStreaming: false)
        case .generating(let partial):
            explanationBody(partial, isStreaming: true)
        case .failed(let message):
            failureBody(message)
        case .idle:
            if availability.canExplain {
                introBody
            } else {
                unavailableBody
            }
        }
    }

    // MARK: - 아직 만들지 않음

    private var introBody: some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
            Text(L("이 문장이 무슨 뜻인지, 어떤 배경에서 나왔는지, 오늘 무엇을 해 볼 수 있는지 짧게 풀어 드려요."))
                .font(ClayFont.body())
                .foregroundStyle(ClayTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(L("해설은 이 기기 안에서 만들어지고, 인터넷으로 보내지 않아요."))
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                store.explain(
                    quote: presentation.quote,
                    author: presentation.author,
                    language: language
                )
            } label: {
                Label(L("해설 보기"), systemImage: "sparkles")
                    .font(ClayFont.callout())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .clayButton(.primary, fullWidth: true)
            .padding(.top, 2)
        }
    }

    // MARK: - 완성 / 생성 중

    private func explanationBody(_ explanation: QuoteExplanation, isStreaming: Bool) -> some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
            if isStreaming && !explanation.isComplete {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text(L("해설을 만드는 중…"))
                        .font(ClayFont.caption())
                        .foregroundStyle(ClayTheme.textSecondary)
                }
            }

            ForEach(explanation.sections) { section in
                VStack(alignment: .leading, spacing: 4) {
                    Label(section.kind.title, systemImage: section.kind.symbol)
                        .font(ClayFont.caption())
                        .foregroundStyle(ClayTheme.accent)

                    Text(section.text)
                        .font(ClayFont.body())
                        .foregroundStyle(ClayTheme.textPrimary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }

            if !isStreaming {
                ClayDivider()

                HStack(alignment: .firstTextBaseline) {
                    Text(L("AI 가 만든 해설이에요. 기기에서 생성했어요."))
                        .font(ClayFont.caption())
                        .foregroundStyle(ClayTheme.textSecondary)

                    Spacer(minLength: ClayTheme.Spacing.s)

                    Button(L("다시 생성")) {
                        store.regenerate(
                            quote: presentation.quote,
                            author: presentation.author,
                            language: language
                        )
                    }
                    .font(ClayFont.caption())
                    .buttonStyle(.plain)
                    .foregroundStyle(ClayTheme.accent)
                }
            }
        }
    }

    // MARK: - 실패

    private func failureBody(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
            Text(message)
                .font(ClayFont.body())
                .foregroundStyle(ClayTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(L("다시 시도")) {
                store.explain(
                    quote: presentation.quote,
                    author: presentation.author,
                    language: language,
                    force: true
                )
            }
            .font(ClayFont.callout())
            .clayButton(.secondary)
        }
    }

    // MARK: - 이 기기에서 못 씀

    /// 확정 사양: 기능을 숨기지 않고 **안내**를 보여 준다.
    ///
    /// 이유를 정확히 말하는 것이 중요하다. "지원되지 않습니다" 만 적으면
    /// 사용자는 앱이 고장 났다고 생각한다. 켜기만 하면 되는 경우에는
    /// 설정으로 가는 길까지 알려 준다.
    private var unavailableBody: some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.xs) {
            Label {
                Text(availability.explanation ?? L("이 기기에서는 AI 해설을 쓸 수 없어요."))
            } icon: {
                Image(systemName: "sparkles.slash")
            }
            .font(ClayFont.body())
            .foregroundStyle(ClayTheme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)

            if let url = availability.settingsURL {
                Link(L("설정 열기"), destination: url)
                    .font(ClayFont.callout())
            }
        }
    }
}

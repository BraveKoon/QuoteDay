import SwiftUI
import UIKit

/// 기기 안의 AI 를 같은 질문으로 한 번에 돌려 보는 점검 화면. **TestFlight 에서만** 보인다.
///
/// 답이 어떤지는 실기기에서만 알 수 있다(`QwenDiagnostic` 참고). 결과를 복사해서 보내면
/// 화면 캡처를 한 장씩 주고받지 않고 실제 출력으로 다음 수정을 정할 수 있다.
struct QwenDiagnosticView: View {
    @Environment(AIChatSettings.self) private var aiSettings
    @Environment(LocalQwenService.self) private var localQwen
    @Environment(AppSettings.self) private var settings

    @State private var results: [QwenDiagnostic.Result] = []
    @State private var isRunning = false
    @State private var runningPrompt: String?
    @State private var notice: String?
    @State private var task: Task<Void, Never>?
    @State private var copied = false

    private var language: AppLanguage { settings.language }
    private var model: LocalQwenModel { aiSettings.localModel }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClayTheme.Spacing.m) {
                header
                controls
                if let notice {
                    Text(verbatim: notice)
                        .font(ClayFont.caption())
                        .foregroundStyle(ClayTheme.textSecondary)
                }
                ForEach(results) { result in
                    resultCard(result)
                }
                if let runningPrompt {
                    HStack(spacing: ClayTheme.Spacing.xs) {
                        ProgressView().controlSize(.small)
                        Text(verbatim: "묻는 중: \(runningPrompt)")
                            .font(ClayFont.caption())
                            .foregroundStyle(ClayTheme.textSecondary)
                    }
                }
            }
            .padding(.horizontal, ClayTheme.Spacing.m)
            .padding(.vertical, ClayTheme.Spacing.m)
            .padding(.bottom, 60)
        }
        .scrollIndicators(.hidden)
        .clayBackground()
        .navigationTitle(Text(verbatim: "모델 점검"))
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { task?.cancel() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: "같은 질문 \(QwenDiagnostic.prompts(language: language).count)개를 실제 대화와 같은 길로 보냅니다.")
                .font(ClayFont.callout())
                .foregroundStyle(ClayTheme.textPrimary)
            Text(verbatim: "\(model.title) · 앱 언어 \(language.rawValue) · 프롬프트 판 \(QuoteChatPrompt.version)")
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
            Text(verbatim: "끝나면 \"결과 복사\"를 눌러 그대로 보내 주세요. 질문마다 새 대화로 시작합니다.")
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
        }
    }

    private var controls: some View {
        HStack(spacing: ClayTheme.Spacing.s) {
            Button {
                isRunning ? stop() : start()
            } label: {
                Text(verbatim: isRunning ? "중지" : "점검 시작")
                    .font(ClayFont.callout())
            }
            .clayButton(.primary, fullWidth: true)

            Button {
                UIPasteboard.general.string = QwenDiagnostic.report(
                    model: model.title, language: language, results: results
                )
                copied = true
            } label: {
                Text(verbatim: copied ? "복사했어요" : "결과 복사")
                    .font(ClayFont.callout())
            }
            .clayButton(.secondary, fullWidth: true)
            .disabled(results.isEmpty)
        }
    }

    private func resultCard(_ result: QwenDiagnostic.Result) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: ClayTheme.Spacing.xs) {
                Image(systemName: result.passed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(result.passed ? Color.green : Color.orange)
                Text(verbatim: result.prompt)
                    .font(ClayFont.callout())
                    .foregroundStyle(ClayTheme.textPrimary)
                Spacer(minLength: 0)
                Text(verbatim: String(format: "%.1f초", result.seconds))
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.textSecondary)
            }
            if !result.passed {
                Text(verbatim: result.problems.joined(separator: " · "))
                    .font(ClayFont.caption())
                    .foregroundStyle(Color.orange)
            }
            Text(verbatim: result.reply.trimmed.isEmpty ? "(빈 답)" : result.reply.trimmed)
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(ClayTheme.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clayCard()
    }

    // MARK: - 실행

    private func start() {
        guard !isRunning else { return }
        guard aiSettings.availability == .ready else {
            notice = "기기 내 모델을 먼저 내려받아 주세요. (설정 → AI 대화)"
            return
        }
        notice = nil
        copied = false
        results = []
        isRunning = true

        let model = self.model
        let language = self.language
        task = Task { @MainActor in
            for prompt in QwenDiagnostic.prompts(language: language) {
                if Task.isCancelled { break }
                runningPrompt = prompt
                // 질문마다 새 대화. 앞 답이 뒤 답에 영향을 주지 않게 한다.
                localQwen.resetSession()

                let context = QuoteChatContext.today()
                let transport = LocalQwenChatTransport(service: localQwen, model: model)
                let started = Date()
                var reply = ""
                var failure: String?
                do {
                    let stream = transport.stream(
                        system: QuoteChatPrompt.system(context: context, language: language),
                        messages: [QuoteChatMessage(role: .user, text: prompt)],
                        language: language,
                        context: context
                    )
                    for try await chunk in stream { reply += chunk }
                } catch {
                    failure = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
                }

                let problems = failure.map { ["오류: \($0)"] }
                    ?? QwenDiagnostic.evaluate(reply: reply, language: language)
                results.append(QwenDiagnostic.Result(
                    prompt: prompt,
                    reply: reply,
                    seconds: Date().timeIntervalSince(started),
                    problems: problems
                ))
            }
            runningPrompt = nil
            isRunning = false
        }
    }

    private func stop() {
        task?.cancel()
        task = nil
        runningPrompt = nil
        isRunning = false
    }
}

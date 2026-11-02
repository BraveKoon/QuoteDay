import SwiftUI

/// 명언 탭 우측 상단 버튼으로 여는 **AI 대화** 시트.
///
/// 묻는 것: 이 문장의 숨은 뜻, 이해가 안 되는 구절, 작가의 일생과 시대,
/// 지금 내 상황에 어떻게 적용할지.
///
/// 답하는 쪽은 사용자가 고른다 — 기기 안(무료) 또는 Qwen(자기 키).
/// 어느 쪽이든 **누가 답하는지 화면에 적는다.** 특히 기기 밖으로 나가는
/// 경우에는 사용자가 그 사실을 알고 물어야 한다.
struct QuoteChatSheet: View {
    /// 지금 보고 있는 명언. 없으면 오늘의 명언을 쓴다.
    let context: QuoteChatContext?

    @Environment(QuoteChatEngine.self) private var engine
    @Environment(AIChatSettings.self) private var aiSettings
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ""
    @FocusState private var isInputFocused: Bool

    private var language: AppLanguage { settings.language }
    private var availability: AIChatAvailability { aiSettings.availability }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                providerBar
                Divider().overlay(ClayTheme.separator)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
                            if engine.messages.isEmpty {
                                emptyState
                            }
                            ForEach(engine.messages) { message in
                                bubble(for: message)
                                    .id(message.id)
                            }
                            if let error = engine.errorMessage {
                                errorBanner(error)
                            }
                        }
                        .padding(ClayTheme.Spacing.m)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: engine.messages.count) { _, _ in
                        scrollToBottom(proxy)
                    }
                    .onChange(of: engine.messages.last?.text) { _, _ in
                        scrollToBottom(proxy)
                    }
                }

                inputBar
            }
            .background(ClayTheme.background)
            .navigationTitle("명언에게 묻기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        engine.clear()
                    } label: {
                        Label("새 대화", systemImage: "square.and.pencil")
                    }
                    .disabled(engine.messages.isEmpty)
                }
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard let last = engine.messages.last else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }

    // MARK: - 위쪽: 누가 답하는지

    private var providerBar: some View {
        HStack(spacing: ClayTheme.Spacing.xs) {
            Image(systemName: aiSettings.provider.symbol)
                .font(.caption)
                .foregroundStyle(ClayTheme.accent)
            Text(aiSettings.provider.title)
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)

            if aiSettings.provider.leavesDevice {
                Label("질문이 기기 밖으로 전송돼요", systemImage: "arrow.up.right.circle")
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.textSecondary)
            } else {
                Label("기기 안에서 답해요", systemImage: "lock")
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.textSecondary)
            }

            Spacer(minLength: 0)

            // 답하는 쪽을 바꾸고 싶으면 여기서 바로 설정으로 간다.
            NavigationLink {
                AIChatSettingsView()
            } label: {
                Text("설정")
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.accent)
            }
        }
        .padding(.horizontal, ClayTheme.Spacing.m)
        .padding(.vertical, ClayTheme.Spacing.xs)
    }

    // MARK: - 비어 있을 때

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
            if let context {
                VStack(alignment: .leading, spacing: 4) {
                    Text("지금 보고 있는 명언")
                        .font(ClayFont.caption())
                        .foregroundStyle(ClayTheme.textSecondary)
                    Text("\u{201C}\(context.quote.text)\u{201D}")
                        .font(ClayFont.callout())
                        .foregroundStyle(ClayTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("— \(context.author.displayName)")
                        .font(ClayFont.caption())
                        .foregroundStyle(ClayTheme.textSecondary)
                }
                .padding(ClayTheme.Spacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .clayCard()
            }

            Text(AIChatAvailabilityText.intro(availability))
                .font(ClayFont.body())
                .foregroundStyle(ClayTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if availability.canChat {
                ForEach(QuoteChatPrompt.suggestions(hasContext: context != nil), id: \.self) { suggestion in
                    Button {
                        send(suggestion)
                    } label: {
                        HStack(spacing: ClayTheme.Spacing.xs) {
                            Image(systemName: "sparkle")
                                .font(.caption)
                            Text(suggestion)
                                .font(ClayFont.callout())
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, ClayTheme.Spacing.m)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(ClayTheme.textPrimary)
                    .claySunken(cornerRadius: ClayTheme.Radius.control)
                }
            } else {
                setupHint
            }
        }
        .padding(.top, ClayTheme.Spacing.s)
    }

    /// 지금 대화할 수 없을 때 — 이유와 다음 행동.
    @ViewBuilder
    private var setupHint: some View {
        switch availability {
        case .needsKey:
            VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
                Text("Qwen 을 쓰려면 내 API 키가 필요해요. 알리바바 클라우드에서 발급받아 설정에 넣어 주세요.")
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                NavigationLink {
                    AIChatSettingsView()
                } label: {
                    Text("키 넣으러 가기")
                        .font(ClayFont.callout())
                }
                .clayButton(.primary, fullWidth: true)
            }
        case .unavailable(let reason):
            VStack(alignment: .leading, spacing: ClayTheme.Spacing.xs) {
                Text(reason.explanation ?? L("이 기기에서는 온디바이스 AI 를 쓸 수 없어요."))
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                NavigationLink {
                    AIChatSettingsView()
                } label: {
                    Text("Qwen 으로 바꾸기")
                        .font(ClayFont.callout())
                }
            }
        case .ready, .misconfigured:
            EmptyView()
        }
    }

    // MARK: - 말풍선

    @ViewBuilder
    private func bubble(for message: QuoteChatMessage) -> some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }

            VStack(alignment: .leading, spacing: 2) {
                Text(message.text)
                    .font(ClayFont.body())
                    .foregroundStyle(message.role == .user ? ClayTheme.textOnAccent : ClayTheme.textPrimary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)

                if message.isStreaming {
                    HStack(spacing: 4) {
                        ProgressView().controlSize(.mini)
                        Text("답하는 중…")
                            .font(.caption2)
                            .foregroundStyle(
                                message.role == .user ? ClayTheme.textOnAccent : ClayTheme.textSecondary
                            )
                    }
                }
            }
            .padding(.horizontal, ClayTheme.Spacing.m)
            .padding(.vertical, ClayTheme.Spacing.s)
            .background(
                RoundedRectangle(cornerRadius: ClayTheme.Radius.card, style: .continuous)
                    .fill(message.role == .user ? ClayTheme.accent : ClayTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ClayTheme.Radius.card, style: .continuous)
                    .stroke(ClayTheme.separator, lineWidth: message.role == .user ? 0 : 1)
            )

            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: ClayTheme.Spacing.xs) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            Text(message)
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button {
                engine.dismissError()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(ClayTheme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(ClayTheme.Spacing.s)
        .clayCard()
    }

    // MARK: - 아래쪽: 입력

    private var inputBar: some View {
        VStack(spacing: 4) {
            HStack(spacing: ClayTheme.Spacing.xs) {
                TextField("무엇이든 물어보세요", text: $draft, axis: .vertical)
                    .font(ClayFont.body())
                    .lineLimit(1...4)
                    .focused($isInputFocused)
                    .submitLabel(.send)
                    .onSubmit { send(draft) }
                    .disabled(!availability.canChat)

                if engine.isSending {
                    Button {
                        engine.stop()
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.title2)
                            .foregroundStyle(ClayTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("그만 받기")
                } else {
                    Button {
                        send(draft)
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(canSend ? ClayTheme.accent : ClayTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSend)
                    .accessibilityLabel("보내기")
                }
            }
            .padding(.horizontal, ClayTheme.Spacing.m)
            .padding(.vertical, ClayTheme.Spacing.xs)
            .claySunken(cornerRadius: ClayTheme.Radius.control)
            .padding(.horizontal, ClayTheme.Spacing.m)

            // AI 가 쓴 글이라는 사실은 화면에 늘 있어야 한다.
            Text("AI 가 만든 답이에요. 중요한 내용은 원문과 함께 확인해 주세요.")
                .font(.caption2)
                .foregroundStyle(ClayTheme.textSecondary)
                .padding(.bottom, ClayTheme.Spacing.xs)
        }
        .padding(.top, ClayTheme.Spacing.xs)
        .background(ClayTheme.background)
    }

    private var canSend: Bool {
        !draft.trimmed.isEmpty && !engine.isSending && availability.canChat
    }

    private func send(_ text: String) {
        let question = text.trimmed
        guard !question.isEmpty, availability.canChat else { return }
        draft = ""
        isInputFocused = false
        engine.send(
            question,
            context: context ?? QuoteChatContext.today(),
            settings: aiSettings,
            language: language
        )
    }
}

/// 안내 문구 모음. 뷰와 설정 화면이 같은 말을 하도록 한곳에 둔다.
enum AIChatAvailabilityText {
    static func intro(_ availability: AIChatAvailability) -> String {
        switch availability {
        case .ready:
            L("명언의 숨은 뜻, 이해가 안 되는 구절, 작가의 일생까지 편하게 물어보세요.")
        case .needsKey:
            L("Qwen API 키를 넣으면 대화를 시작할 수 있어요.")
        case .unavailable(let reason):
            reason.explanation ?? L("지금은 AI 대화를 쓸 수 없어요.")
        case .misconfigured:
            L("주소 설정이 잘못됐어요. 설정에서 지역을 다시 골라 주세요.")
        }
    }
}

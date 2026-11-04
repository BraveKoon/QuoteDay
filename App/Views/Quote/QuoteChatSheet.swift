import SwiftUI

/// 명언 탭 우측 상단 버튼으로 여는 **AI 대화** 시트.
///
/// 묻는 것: 이 문장의 숨은 뜻, 이해가 안 되는 구절, 작가의 일생과 시대,
/// 지금 내 상황에 어떻게 적용할지.
///
/// 답하는 쪽은 사용자가 고른다 — Apple 온디바이스 또는 Qwen3 기기 내(오픈소스).
/// 둘 다 **기기 안에서** 끝나고, 어느 쪽인지는 화면 위에 적는다.
struct QuoteChatSheet: View {
    /// 지금 보고 있는 명언. 없으면 오늘의 명언을 쓴다.
    let context: QuoteChatContext?

    @Environment(QuoteChatEngine.self) private var engine
    @Environment(AIChatSettings.self) private var aiSettings
    @Environment(LocalQwenService.self) private var localQwen
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ""
    /// 사용자가 이 시트 안에서 직접 고른 명언. 없으면 `context`(지금 보던 명언)를 쓴다.
    @State private var picked: QuoteChatContext?
    @State private var showsPicker = false
    @FocusState private var isInputFocused: Bool

    /// 지금 묻고 있는 명언. 고른 것 → 보던 것 → 오늘의 명언 순이다.
    private var activeContext: QuoteChatContext {
        picked ?? context ?? QuoteChatContext.today()
    }

    private var language: AppLanguage { settings.language }
    private var availability: AIChatAvailability { aiSettings.availability }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                providerBar
                Divider().overlay(ClayTheme.separator)

                // 대화가 시작되면 위의 큰 카드는 스크롤로 사라진다. 어떤 명언에 대해
                // 묻고 있는지, 그리고 바꿀 수 있다는 것이 늘 보이도록 한 줄을 남긴다.
                if !engine.messages.isEmpty {
                    quoteBar
                    Divider().overlay(ClayTheme.separator)
                }

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
            .sheet(isPresented: $showsPicker) {
                QuoteChatQuotePicker(currentSlug: activeContext.quote.slug) { quote in
                    choose(quote)
                }
            }
        }
    }

    /// 다른 명언을 골랐다. 이미 오간 대화는 **앞 명언에 대한 것**이라 비운다 —
    /// 남겨 두면 "이 명언" 이 무엇을 가리키는지 사용자도 모델도 헷갈린다.
    private func choose(_ quote: Quote) {
        guard quote.slug != activeContext.quote.slug else { return }
        if !engine.messages.isEmpty { engine.clear() }
        picked = QuoteChatContext.make(for: quote)
    }

    // MARK: - 위쪽: 어떤 명언인지

    private var quoteBar: some View {
        Button {
            showsPicker = true
        } label: {
            HStack(spacing: ClayTheme.Spacing.xs) {
                Image(systemName: "quote.opening")
                    .font(.caption)
                    .foregroundStyle(ClayTheme.accent)
                Text(verbatim: "\(activeContext.quote.text) — \(activeContext.author.displayName)")
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(ClayTheme.textSecondary)
            }
            .padding(.horizontal, ClayTheme.Spacing.m)
            .padding(.vertical, ClayTheme.Spacing.xs + 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // 답하는 중에 명언을 바꾸면 흐르던 답이 엉뚱한 명언에 붙는다.
        .disabled(engine.isSending)
        .accessibilityLabel("명언 바꾸기")
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

            // 지금은 어떤 통로도 기기 밖으로 나가지 않는다. 나중에 서버 통로가
            // 생기면 provider.leavesDevice 만 바꾸면 이 안내가 따라온다.
            Label(
                aiSettings.provider.leavesDevice ? "질문이 기기 밖으로 전송돼요" : "기기 안에서 답해요",
                systemImage: aiSettings.provider.leavesDevice ? "arrow.up.right.circle" : "lock"
            )
            .font(ClayFont.caption())
            .foregroundStyle(ClayTheme.textSecondary)

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
            Button {
                showsPicker = true
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(picked == nil ? L("지금 보고 있는 명언") : L("선택한 명언"))
                        .font(ClayFont.caption())
                        .foregroundStyle(ClayTheme.textSecondary)
                    Text("\u{201C}\(activeContext.quote.text)\u{201D}")
                        .font(ClayFont.callout())
                        .foregroundStyle(ClayTheme.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("— \(activeContext.author.displayName)")
                        .font(ClayFont.caption())
                        .foregroundStyle(ClayTheme.textSecondary)

                    // 눌러서 바꿀 수 있다는 것을 말로 적는다. 카드만 보고는 알 수 없다.
                    Label("다른 명언 고르기", systemImage: "arrow.triangle.2.circlepath")
                        .font(ClayFont.caption())
                        .foregroundStyle(ClayTheme.accent)
                        .padding(.top, 4)
                }
                .padding(ClayTheme.Spacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .clayCard()
            }
            .buttonStyle(.plain)

            Text(AIChatAvailabilityText.intro(availability))
                .font(ClayFont.body())
                .foregroundStyle(ClayTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if availability.canChat {
                ForEach(QuoteChatPrompt.suggestions(hasContext: true), id: \.self) { suggestion in
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
        case .unavailable(let reason):
            VStack(alignment: .leading, spacing: ClayTheme.Spacing.xs) {
                Text(reason.explanation ?? L("이 기기에서는 온디바이스 AI 를 쓸 수 없어요."))
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                NavigationLink {
                    AIChatSettingsView()
                } label: {
                    Text("다른 방법 고르기")
                        .font(ClayFont.callout())
                }
            }
        case .needsDownload(let model):
            downloadCard(model)
        case .localUnsupportedDevice:
            VStack(alignment: .leading, spacing: ClayTheme.Spacing.xs) {
                Text("기기 내 Qwen 은 실제 기기에서만 돌아가요. 시뮬레이터에서는 확인할 수 없어요.")
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                NavigationLink {
                    AIChatSettingsView()
                } label: {
                    Text("다른 방법 고르기")
                        .font(ClayFont.callout())
                }
            }
        case .ready:
            EmptyView()
        }
    }

    /// 아직 모델을 받지 않았을 때. 여기서 바로 받을 수 있게 한다 —
    /// 설정으로 보내고 다시 돌아오게 하면 두 번 일하게 된다.
    private func downloadCard(_ model: LocalQwenModel) -> some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
            HStack(spacing: ClayTheme.Spacing.xs) {
                Image(systemName: "arrow.down.circle")
                    .foregroundStyle(ClayTheme.accent)
                Text(verbatim: "\(model.title) · \(model.formattedSize)")
                    .font(ClayFont.callout())
                    .foregroundStyle(ClayTheme.textPrimary)
                Spacer(minLength: 0)
            }

            Text("한 번만 받으면 그다음부터는 인터넷 없이도 대화할 수 있어요. 와이파이에서 받는 편이 좋아요.")
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if localQwen.preparing == model {
                ProgressView(value: localQwen.progress.isFinite ? max(0, min(1, localQwen.progress)) : 0)
                    .tint(ClayTheme.accent)
                Text(verbatim: "\(L("받는 중…")) \(Int((max(0, min(1, localQwen.progress))) * 100))%")
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.textSecondary)
            } else {
                Button {
                    Task { await localQwen.prepare(model) }
                } label: {
                    Text("내려받기")
                        .font(ClayFont.callout())
                }
                .clayButton(.primary, fullWidth: true)
            }

            Text(LocalQwenModel.licenseNotice)
                .font(.caption2)
                .foregroundStyle(ClayTheme.textSecondary)
        }
        .padding(ClayTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clayCard()
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
            context: activeContext,
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
        case .unavailable(let reason):
            reason.explanation ?? L("지금은 AI 대화를 쓸 수 없어요.")
        case .needsDownload(let model):
            L("%@ 모델을 한 번만 받으면 기기 안에서 대화할 수 있어요. 약 %@예요.", model.title, model.formattedSize)
        case .localUnsupportedDevice:
            L("이 환경에서는 기기 내 AI 를 돌릴 수 없어요. 실제 기기에서 써 주세요.")
        }
    }
}

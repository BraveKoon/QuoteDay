import SwiftUI

/// AI 대화 설정 — 누가 답할지, 어떤 열쇠를 쓸지.
///
/// 앱에 키를 넣어 배포하지 않는 이유를 화면에도 적는다. 사용자는 "왜 내가 키를
/// 넣어야 하지?" 를 알아야 하고, 키를 넣으면 **무엇이 어디로 가는지**도 알아야
/// 한다. 그 두 가지를 숨기면 편해 보이지만 정직하지 않다.
struct AIChatSettingsView: View {
    @Environment(AIChatSettings.self) private var aiSettings
    @Environment(LocalQwenService.self) private var localQwen

    @State private var keyDraft = ""
    @State private var message: String?
    @State private var isMessageGood = false

    var body: some View {
        @Bindable var aiSettings = aiSettings

        ScrollView {
            VStack(spacing: ClayTheme.Spacing.m) {
                providerCard(aiSettings: $aiSettings)

                if aiSettings.provider == .localQwen {
                    localCard(aiSettings: $aiSettings)
                }

                if aiSettings.provider == .qwen {
                    keyCard
                    modelCard(aiSettings: $aiSettings)
                }

                privacyCard
            }
            .padding(.horizontal, ClayTheme.Spacing.m)
            .padding(.vertical, ClayTheme.Spacing.m)
            .padding(.bottom, 60)
        }
        .scrollIndicators(.hidden)
        .clayBackground()
        .navigationTitle("AI 대화")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 누가 답하나

    private func providerCard(aiSettings: Bindable<AIChatSettings>) -> some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
            SectionHeader("누가 답할까요")

            ForEach(AIChatProvider.allCases) { provider in
                Button {
                    aiSettings.wrappedValue.provider = provider
                    message = nil
                } label: {
                    HStack(alignment: .top, spacing: ClayTheme.Spacing.s) {
                        Image(systemName: provider.symbol)
                            .foregroundStyle(
                                aiSettings.wrappedValue.provider == provider
                                    ? ClayTheme.accent : ClayTheme.textSecondary
                            )
                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(provider.title)
                                .font(ClayFont.callout())
                                .foregroundStyle(ClayTheme.textPrimary)
                            Text(provider.detail)
                                .font(ClayFont.caption())
                                .foregroundStyle(ClayTheme.textSecondary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)

                        if aiSettings.wrappedValue.provider == provider {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(ClayTheme.accent)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            // 지금 상태 한 줄. 고른 통로를 실제로 쓸 수 있는지 알려 준다.
            Text(AIChatAvailabilityText.intro(aiSettings.wrappedValue.availability))
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .padding(ClayTheme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clayCard()
    }

    // MARK: - 기기 내 Qwen (오픈소스 가중치)

    private func localCard(aiSettings: Bindable<AIChatSettings>) -> some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
            SectionHeader("기기 내 모델")

            Picker("크기", selection: aiSettings.localChoice) {
                ForEach(LocalQwenChoice.allCases) { choice in
                    Text(choice.title).tag(choice)
                }
            }
            .pickerStyle(.segmented)

            Text(aiSettings.wrappedValue.localChoice.detail)
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(LocalQwenModel.allCases) { model in
                localModelRow(model)
            }

            Text("가중치는 처음 한 번만 내려받아요. 받은 파일은 이 기기의 저장 공간에 남고, 앱을 지우면 함께 지워져요.")
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(LocalQwenModel.licenseNotice)
                .font(.caption2)
                .foregroundStyle(ClayTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(ClayTheme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clayCard()
    }

    @ViewBuilder
    private func localModelRow(_ model: LocalQwenModel) -> some View {
        let isDownloaded = localQwen.isDownloaded(model)
        let isPreparing = localQwen.preparing == model
        let recommended = LocalQwenModel.recommendedForThisDevice == model

        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: ClayTheme.Spacing.xs) {
                Text(model.title)
                    .font(ClayFont.callout())
                    .foregroundStyle(ClayTheme.textPrimary)
                if recommended {
                    Text("이 기기 추천")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ClayTheme.accent.opacity(0.12), in: Capsule())
                        .foregroundStyle(ClayTheme.accent)
                }
                Spacer(minLength: 0)
                Text(isDownloaded ? LocalQwenModel.format(localQwen.bytesOnDisk(for: model)) : model.formattedSize)
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.textSecondary)
            }

            if isPreparing {
                ProgressView(value: localQwen.progress.isFinite ? max(0, min(1, localQwen.progress)) : 0)
                    .tint(ClayTheme.accent)
            } else if isDownloaded {
                HStack(spacing: ClayTheme.Spacing.xs) {
                    Label("받아 두었어요", systemImage: "checkmark.seal.fill")
                        .font(ClayFont.caption())
                        .foregroundStyle(ClayTheme.accent)
                    Spacer(minLength: 0)
                    Button("지우기") {
                        localQwen.delete(model)
                    }
                    .font(ClayFont.caption())
                    .buttonStyle(.plain)
                    .foregroundStyle(ClayTheme.textSecondary)
                }
            } else {
                Button {
                    Task { await localQwen.prepare(model) }
                } label: {
                    Text(verbatim: "\(L("내려받기")) (\(model.formattedSize))")
                        .font(ClayFont.caption())
                }
                .buttonStyle(.plain)
                .foregroundStyle(ClayTheme.accent)
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - 열쇠

    private var keyCard: some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
            SectionHeader("Qwen API 키")

            Text("Alibaba Cloud Model Studio(DashScope)에서 발급한 키를 붙여 넣으세요. 이 기기의 Keychain 에만 저장되고, 앱이 Qwen 을 부를 때만 쓰여요.")
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if aiSettings.hasKey {
                HStack(spacing: ClayTheme.Spacing.xs) {
                    Label("키가 저장되어 있어요", systemImage: "checkmark.seal.fill")
                        .font(ClayFont.callout())
                        .foregroundStyle(ClayTheme.accent)
                    Spacer(minLength: 0)
                    Button("지우기") {
                        aiSettings.deleteKey()
                        keyDraft = ""
                        set("키를 지웠어요", good: true)
                    }
                    .font(ClayFont.caption())
                    .buttonStyle(.plain)
                    .foregroundStyle(ClayTheme.textSecondary)
                }
            }

            SecureField("sk-…", text: $keyDraft)
                .font(ClayFont.body())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(ClayTheme.Spacing.s)
                .claySunken()

            Button {
                if aiSettings.saveKey(keyDraft) {
                    keyDraft = ""
                    set("키를 저장했어요", good: true)
                } else {
                    set("키를 저장하지 못했어요. 다시 확인해 주세요.", good: false)
                }
            } label: {
                Text("키 저장")
                    .font(ClayFont.callout())
            }
            .clayButton(.primary, fullWidth: true)
            .disabled(keyDraft.trimmed.isEmpty)

            if let message {
                Text(message)
                    .font(ClayFont.caption())
                    .foregroundStyle(isMessageGood ? ClayTheme.accent : .orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(ClayTheme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clayCard()
    }

    // MARK: - 모델·지역

    private func modelCard(aiSettings: Bindable<AIChatSettings>) -> some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
            SectionHeader("모델")

            Picker("모델", selection: aiSettings.model) {
                ForEach(AIChatSettings.QwenModel.allCases) { model in
                    Text(model.title).tag(model)
                }
            }
            .pickerStyle(.segmented)

            Text(aiSettings.wrappedValue.model.detail)
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)

            ClayDivider()

            SectionHeader("지역")

            Picker("지역", selection: aiSettings.region) {
                ForEach(QwenRegion.allCases) { region in
                    Text(region.title).tag(region)
                }
            }
            .pickerStyle(.segmented)

            Text("계정을 만든 곳과 가까운 지역을 고르세요. 키는 지역마다 따로 발급돼요.")
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(ClayTheme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clayCard()
    }

    // MARK: - 무엇이 어디로 가나

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.xs) {
            SectionHeader("무엇이 오가나")
            bullet("온디바이스와 기기 내 Qwen3 는 질문도 답도 기기 밖으로 나가지 않아요.")
            bullet("기기 내 Qwen3 는 오픈소스 가중치(Apache 2.0)를 처음 한 번만 내려받아 기기에서 돌려요.")
            bullet("Qwen 을 고르면 질문과 지금 보고 있는 명언·작가 정보가 알리바바 클라우드로 전송돼요.")
            bullet("대화는 저장하지 않아요. 시트를 닫으면 사라져요.")
            bullet("API 키는 이 기기 Keychain 에만 있고, 위젯·백업과 공유하지 않아요.")
        }
        .padding(ClayTheme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clayCard()
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("·").foregroundStyle(ClayTheme.textSecondary)
            Text(L(text))
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func set(_ text: String, good: Bool) {
        message = text
        isMessageGood = good
    }
}

import SwiftUI

/// AI 대화 설정 — 누가 답할지, 기기 내 모델을 얼마나 쓸지.
///
/// 여기서 정하는 것은 **기기 안에서만** 일어난다. 클라우드 통로를 걷어낸 뒤로
/// 적어 둘 것이 줄었다: 통로(Apple / Qwen3)와, Qwen3 를 쓸 때의 크기뿐이다.
struct AIChatSettingsView: View {
    @Environment(AIChatSettings.self) private var aiSettings
    @Environment(LocalQwenService.self) private var localQwen

    var body: some View {
        @Bindable var aiSettings = aiSettings

        ScrollView {
            VStack(spacing: ClayTheme.Spacing.m) {
                providerCard(aiSettings: $aiSettings)

                if aiSettings.provider == .localQwen {
                    localCard(aiSettings: $aiSettings)
                }

                privacyCard

                // TestFlight 에서만. 실기기에서 모델이 어떻게 답하는지 한 번에 돌려 본다.
                if QwenDiagnostic.isAvailable, aiSettings.provider == .localQwen {
                    NavigationLink {
                        QwenDiagnosticView()
                    } label: {
                        HStack {
                            Text(verbatim: "모델 점검 (TestFlight 전용)")
                                .font(ClayFont.callout())
                                .foregroundStyle(ClayTheme.textPrimary)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(ClayTheme.textSecondary)
                        }
                        .padding(ClayTheme.Spacing.l)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .clayCard()
                    }
                    .buttonStyle(.plain)
                }
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
                ForEach(LocalQwenChoice.availableOnThisDevice) { choice in
                    Text(choice.title).tag(choice)
                }
            }
            .pickerStyle(.segmented)

            Text(aiSettings.wrappedValue.localChoice.detail)
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(LocalQwenModel.availableOnThisDevice) { model in
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

    // MARK: - 무엇이 어디로 가나

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.xs) {
            SectionHeader("무엇이 오가나")
            bullet("질문도 답도 기기 밖으로 나가지 않아요. 서버를 거치지 않아요.")
            bullet("기기 내 Qwen3 는 오픈소스 가중치(Apache 2.0)를 처음 한 번만 내려받아 기기에서 돌려요.")
            bullet("받은 모델 파일은 이 기기의 저장 공간에만 있고, 설정에서 언제든 지울 수 있어요.")
            bullet("대화는 저장하지 않아요. 시트를 닫으면 사라져요.")
            bullet("API 키를 넣을 일이 없어요. 앱은 어떤 키도 요구하지 않고 보관하지도 않아요.")
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
}

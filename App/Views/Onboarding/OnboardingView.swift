import SwiftUI

/// 첫 실행 안내.
///
/// 한 화면에 한 단계씩만 보여 준다. 순서는 **로그인 → 언어 → 닉네임**이고,
/// 이 순서에는 이유가 있다.
///
/// 1. 로그인을 먼저 물어야 Apple 이 준 이름을 닉네임 기본값으로 쓸 수 있다.
/// 2. 언어는 그다음이다. 앞에서 고른 언어로 나머지 화면이 바로 바뀌므로,
///    사용자는 자기 언어로 닉네임을 정하게 된다.
///
/// 어느 단계에서든 "로그인 없이 사용하기"로 들어온 사람도 똑같이
/// 언어와 닉네임을 정한다. 계정이 없는 것과 이름이 없는 것은 다르다.
struct OnboardingView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ProfileStore.self) private var profile
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var step: Step = .login
    @State private var nickname = ""
    /// 로그인 실패를 알리는 한 줄. 취소는 오류가 아니므로 비어 있다.
    @State private var errorMessage: String?
    @FocusState private var isNicknameFocused: Bool

    /// 안내의 세 단계.
    private enum Step: Int, CaseIterable {
        case login, language, nickname
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: ClayTheme.Spacing.l) {
                    switch step {
                    case .login: loginStep
                    case .language: languageStep
                    case .nickname: nicknameStep
                    }
                }
                .padding(.horizontal, ClayTheme.Spacing.m)
                .padding(.top, ClayTheme.Spacing.m)
                .padding(.bottom, ClayTheme.Spacing.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .clayBackground()
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: step)
        // 첫 화면에서 바로 로그인 버튼을 누를 수 있게, 실패 메시지는 사라진다.
        .onChange(of: step) { _, newValue in
            errorMessage = nil
            guard newValue == .nickname else { return }
            if nickname.isEmpty, let suggested = profile.appleDisplayName {
                nickname = ProfileStore.cleaned(suggested)
            }
            isNicknameFocused = newValue == .nickname
        }
    }

    // MARK: - 머리말 (뒤로 · 진행 표시)

    private var header: some View {
        HStack(spacing: ClayTheme.Spacing.s) {
            if step != .login {
                Button {
                    goBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(ClayTheme.textSecondary)
                        .frame(width: 32, height: 32)
                        .clayCard(cornerRadius: ClayTheme.Radius.tiny)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("뒤로"))
            } else {
                Color.clear.frame(width: 32, height: 32)
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                ForEach(Step.allCases, id: \.self) { value in
                    Capsule()
                        .fill(value.rawValue <= step.rawValue ? ClayTheme.accent : ClayTheme.separator)
                        .frame(width: value == step ? 18 : 6, height: 6)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(step.rawValue + 1) / \(Step.allCases.count)"))

            Spacer(minLength: 0)

            // 오른쪽도 같은 폭을 비워 두어 점이 가운데에 온다.
            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, ClayTheme.Spacing.m)
        .padding(.top, ClayTheme.Spacing.s)
    }

    // MARK: - 1. 로그인

    private var loginStep: some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.l) {
            appMark

            VStack(alignment: .leading, spacing: ClayTheme.Spacing.xs) {
                Text("매일 한 문장이 도착하는 하루")
                    .font(ClayFont.hero())
                    .foregroundStyle(ClayTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("일정을 등록하면 그 시간에 어울리는 명언이 알림으로 옵니다.")
                    .font(ClayFont.callout())
                    .foregroundStyle(ClayTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
                featureRow("quote.bubble.fill", "매일 바뀌는 오늘의 명언")
                featureRow("bell.badge.fill", "일정 시간에 맞춰 오는 명언 알림")
                featureRow("square.grid.2x2.fill", "홈 화면과 잠금화면 위젯")
            }
            .padding(ClayTheme.Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .clayCard()

            VStack(spacing: ClayTheme.Spacing.s) {
                AppleSignInButton(
                    onCredential: handleAppleCredential,
                    onFailure: { message in
                        guard let message else { return }
                        errorMessage = message
                    }
                )

                if let errorMessage {
                    Text(errorMessage)
                        .font(ClayFont.caption())
                        .foregroundStyle(ClayTheme.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: ClayTheme.Spacing.xs) {
                    Rectangle().fill(ClayTheme.separator).frame(height: 1)
                    Text("또는")
                        .font(ClayFont.caption())
                        .foregroundStyle(ClayTheme.textSecondary)
                    Rectangle().fill(ClayTheme.separator).frame(height: 1)
                }
                .padding(.vertical, ClayTheme.Spacing.xs)

                Button("로그인 없이 사용하기") {
                    profile.continueAsGuest()
                    goTo(.language)
                }
                .clayButton(.secondary, fullWidth: true)
            }

            Text("로그인 없이도 모든 기능을 쓸 수 있어요. 기록은 이 기기에만 저장됩니다.")
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var appMark: some View {
        HStack(spacing: ClayTheme.Spacing.s) {
            Image(systemName: "quote.opening")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(ClayTheme.textOnAccent)
                .frame(width: 46, height: 46)
                .background(
                    RoundedRectangle(cornerRadius: ClayTheme.Radius.control, style: .continuous)
                        .fill(ClayTheme.accent)
                )
            VStack(alignment: .leading, spacing: 1) {
                Text("QuoteDay")
                    .font(ClayFont.title())
                    .foregroundStyle(ClayTheme.textPrimary)
                Text("명언과 일정을 잇는 하루")
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.textSecondary)
            }
        }
    }

    private func featureRow(_ symbol: String, _ text: LocalizedStringKey) -> some View {
        HStack(spacing: ClayTheme.Spacing.s) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ClayTheme.accent)
                .frame(width: 22)
            Text(text)
                .font(ClayFont.callout())
                .foregroundStyle(ClayTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    // MARK: - 2. 언어

    private var languageStep: some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.l) {
            VStack(alignment: .leading, spacing: ClayTheme.Spacing.xs) {
                Text("언어를 선택하세요")
                    .font(ClayFont.hero())
                    .foregroundStyle(ClayTheme.textPrimary)
                Text("명언과 위젯도 고른 언어로 바뀝니다. 설정에서 언제든 다시 바꿀 수 있어요.")
                    .font(ClayFont.callout())
                    .foregroundStyle(ClayTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            LanguagePickerList(selection: Binding(
                get: { settings.language },
                set: { settings.language = $0 }
            ))

            Button("다음") {
                goTo(.nickname)
            }
            .clayButton(.primary, fullWidth: true)
            .padding(.top, ClayTheme.Spacing.xs)
        }
    }

    // MARK: - 3. 닉네임

    private var nicknameStep: some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.l) {
            VStack(alignment: .leading, spacing: ClayTheme.Spacing.xs) {
                Text("닉네임을 정해 주세요")
                    .font(ClayFont.hero())
                    .foregroundStyle(ClayTheme.textPrimary)
                Text("홈 화면 인사말에 쓰입니다. 설정에서 언제든 바꿀 수 있어요.")
                    .font(ClayFont.callout())
                    .foregroundStyle(ClayTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: ClayTheme.Spacing.xs) {
                TextField("닉네임", text: $nickname)
                    .font(ClayFont.headline())
                    .foregroundStyle(ClayTheme.textPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($isNicknameFocused)
                    .padding(.horizontal, ClayTheme.Spacing.m)
                    .padding(.vertical, ClayTheme.Spacing.s + 2)
                    .claySunken()
                    .onChange(of: nickname) { _, newValue in
                        // 길이는 입력하는 순간 자른다. 다 쓴 뒤에 알려 주면
                        // 사용자는 왜 안 되는지 모른 채 글자를 지우게 된다.
                        let cleaned = ProfileStore.cleaned(newValue)
                        if cleaned != newValue { nickname = cleaned }
                    }

                HStack {
                    Text("\(nickname.count) / \(ProfileStore.nicknameLimit)")
                        .font(ClayFont.caption())
                        .foregroundStyle(ClayTheme.textSecondary)
                    Spacer(minLength: 0)
                }
            }

            Button("시작하기") {
                profile.finishOnboarding(nickname: nickname)
            }
            .clayButton(.primary, fullWidth: true)
            .disabled(!ProfileStore.isValid(nickname: nickname))
            .padding(.top, ClayTheme.Spacing.xs)

            Text("언제든 설정에서 바꿀 수 있어요.")
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
        }
    }

    // MARK: - 진행

    private func handleAppleCredential(_ credential: AppleSignIn.Credential) {
        errorMessage = nil
        profile.applyAppleCredential(credential)
        goTo(.language)
    }

    private func goTo(_ next: Step) {
        step = next
    }

    private func goBack() {
        // 로그인으로 돌아갈 때는 로그인 상태를 남기지 않는다.
        // (돌아왔다가 다시 "로그인 없이"를 고를 수 있어야 한다.)
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        step = previous
    }
}

#Preview("첫 실행 안내") {
    OnboardingView()
        .injecting(AppEnvironment.preview())
        .environment(\.locale, Locale(identifier: "ko"))
}

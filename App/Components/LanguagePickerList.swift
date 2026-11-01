import SwiftUI

/// 언어를 고르는 목록. 첫 실행 안내와 설정에서 같은 모양으로 쓴다.
///
/// 언어 이름은 **그 언어로** 적는다. 지금 화면이 무슨 언어든 자기 언어를 찾을 수
/// 있어야 하기 때문이다. 고르면 즉시 반영되고, 목록의 나머지 글자도 그 자리에서
/// 바뀐다 — 미리보기가 곧 결과다.
struct LanguagePickerList: View {
    @Binding var selection: AppLanguage
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: ClayTheme.Spacing.s) {
            ForEach(AppLanguage.allCases) { language in
                row(language)
            }
        }
    }

    private func row(_ language: AppLanguage) -> some View {
        let isSelected = selection == language

        return Button {
            guard !isSelected else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                selection = language
            }
        } label: {
            HStack(spacing: ClayTheme.Spacing.s) {
                Text(language.badge)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? ClayTheme.textOnAccent : ClayTheme.textSecondary)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle().fill(isSelected ? ClayTheme.accent : ClayTheme.surfaceSunken)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: language.nativeName)
                        .font(ClayFont.headline())
                        .foregroundStyle(ClayTheme.textPrimary)
                    Text(verbatim: language.englishName)
                        .font(ClayFont.caption())
                        .foregroundStyle(ClayTheme.textSecondary)
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? ClayTheme.accent : ClayTheme.separator)
            }
            .padding(ClayTheme.Spacing.s + 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .clayCard(
                cornerRadius: ClayTheme.Radius.control,
                tint: isSelected ? ClayTheme.surfaceRaised : nil
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

private struct LanguagePickerPreview: View {
    @State private var language: AppLanguage = .korean

    var body: some View {
        LanguagePickerList(selection: $language)
            .padding()
            .clayBackground()
    }
}

#Preview("언어 목록") {
    LanguagePickerPreview()
}

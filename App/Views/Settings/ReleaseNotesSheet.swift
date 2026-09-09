import SwiftUI

/// 변경 이력. 1.0 부터 지금까지의 릴리스를 최신순으로 보여 준다.
///
/// 내용은 `CHANGELOG.md` 에서 생성한 것이라 깃허브 릴리스 노트와 같은 글이다.
/// 항목마다 붙은 근거·세부 사항은 싣지 않는다 — 한 번에 훑는 화면이라
/// 다 넣으면 아무도 끝까지 읽지 않는다. 각 릴리스에서 깃허브로 이어 준다.
struct ReleaseNotesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: ClayTheme.Spacing.m) {
                    ForEach(ReleaseHistory.all) { release in
                        releaseCard(release)
                    }
                    footer
                }
                .padding(ClayTheme.Spacing.m)
                .padding(.bottom, ClayTheme.Spacing.xl)
            }
            .scrollIndicators(.hidden)
            .clayBackground()
            .navigationTitle("변경 이력")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    // MARK: - 릴리스 하나

    private func releaseCard(_ release: Release) -> some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
            header(for: release)

            if let summary = release.summary {
                Text(summary)
                    .font(ClayFont.callout())
                    .foregroundStyle(ClayTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(release.sections, id: \.title) { section in
                VStack(alignment: .leading, spacing: ClayTheme.Spacing.xs) {
                    Text(section.title)
                        .font(ClayFont.caption())
                        .fontWeight(.semibold)
                        .foregroundStyle(ClayTheme.accent)

                    // 같은 문장이 두 번 실릴 수 있으므로 순번을 id 로 쓴다.
                    ForEach(Array(section.items.enumerated()), id: \.offset) { _, item in
                        bullet(item)
                    }
                }
            }

            if let url = release.releaseURL {
                Button {
                    openURL(url)
                } label: {
                    Label("깃허브에서 자세히 보기", systemImage: "arrow.up.right.square")
                        .font(ClayFont.caption())
                }
                .buttonStyle(.plain)
                .foregroundStyle(ClayTheme.accent)
                .padding(.top, 2)
            }
        }
        .padding(ClayTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clayCard()
    }

    private func header(for release: Release) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: ClayTheme.Spacing.xs) {
            Text(release.tag)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(ClayTheme.textPrimary)

            if release.version == AppVersion.marketing {
                Text("사용 중")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(ClayTheme.textOnAccent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: ClayTheme.Radius.chip, style: .continuous)
                            .fill(ClayTheme.accent)
                    )
            }

            Spacer()

            Text(release.displayDate)
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: ClayTheme.Spacing.xs) {
            Circle()
                .fill(ClayTheme.separator)
                .frame(width: 5, height: 5)
                .padding(.top, 7)
            Text(text)
                .font(ClayFont.callout())
                .foregroundStyle(ClayTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        Text("이 목록은 저장소의 CHANGELOG.md 에서 만들어지며, 각 항목의 태그는 깃허브 릴리스와 같습니다.")
            .font(ClayFont.caption())
            .foregroundStyle(ClayTheme.textSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, ClayTheme.Spacing.s)
    }
}

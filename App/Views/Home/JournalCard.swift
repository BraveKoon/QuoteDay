import SwiftUI

/// 홈의 "오늘 한 줄". v1.9 의 중심이다.
///
/// 기록 기능 자체는 1.4 부터 있었다. 문제는 **설정 → 스크롤 → 노트 모아 보기**
/// 라는 유일한 진입점이었다는 것이고, 그 자리를 찾아내는 사람은 거의 없다.
/// 이 카드는 새 기능이 아니라 **이사**다.
///
/// 마찰을 전부 걷어낸다. 시트로 띄우지 않고 그 자리에서 펼치며, 저장 버튼이
/// 없다. 버튼 하나가 습관 하나를 죽인다 — 매일 쓰게 하려면 매일 누르는 것이
/// 적을수록 좋다.
struct JournalCard: View {
    let presentation: QuotePresentation
    /// 오늘 고른 기분. 글과 함께 저장되어 월간 회고에서 세어진다.
    var mood: QuoteMood?

    @Environment(NoteStore.self) private var notes
    @Environment(StreakStore.self) private var streaks
    @Environment(AppRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase

    /// 편집 중인 글. 저장소가 아니라 여기에 있다가 조용히 내려간다.
    @State private var draft = ""
    @State private var isEditing = false
    /// 글이 멈춘 뒤에 저장하려고 미뤄 둔 일.
    @State private var saveTask: Task<Void, Never>?
    @FocusState private var isFocused: Bool

    private var today: QuoteNote? {
        notes.note(for: presentation.quote.slug)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
            header

            if isEditing {
                editor
            } else if let today, !today.isEmpty {
                written(today)
            } else {
                invitation
            }

            streakLine
        }
        .padding(ClayTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clayCard(cornerRadius: ClayTheme.Radius.card)
        .animation(.easeInOut(duration: 0.22), value: isEditing)
        .onAppear {
            // 알림의 "바로 기록하기" 로 들어왔으면 펼친 채로 연다.
            if router.wantsTodayCompose {
                router.wantsTodayCompose = false
                beginEditing()
            }
        }
        .onChange(of: router.wantsTodayCompose) { _, wants in
            guard wants else { return }
            router.wantsTodayCompose = false
            beginEditing()
        }
        .onChange(of: scenePhase) { _, phase in
            // 앱이 내려가면 미뤄 둔 저장을 기다릴 수 없다. 지금 쓴다.
            if phase != .active { commit() }
        }
        .onDisappear { commit() }
    }

    // MARK: - 조각들

    private var header: some View {
        HStack(spacing: ClayTheme.Spacing.xs) {
            Label("오늘 한 줄", systemImage: "square.and.pencil")
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
            Spacer(minLength: 0)
            if isEditing {
                Button("접기") { finishEditing() }
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.accent)
            } else if let today, !today.isEmpty {
                Button {
                    beginEditing()
                } label: {
                    Image(systemName: "pencil")
                        .font(ClayFont.caption())
                        .foregroundStyle(ClayTheme.accent)
                }
                .accessibilityLabel("오늘 쓴 글 고치기")
            }
        }
    }

    private var invitation: some View {
        Button {
            beginEditing()
        } label: {
            HStack {
                Text(Self.prompt(for: .now))
                    .font(ClayFont.callout())
                    .foregroundStyle(ClayTheme.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: ClayTheme.Spacing.xs)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(ClayTheme.textSecondary)
            }
            .padding(ClayTheme.Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .claySunken()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("오늘 한 줄 쓰기")
        .accessibilityHint(Self.prompt(for: .now))
    }

    private func written(_ note: QuoteNote) -> some View {
        Button {
            beginEditing()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(note.text)
                    .font(ClayFont.body())
                    .foregroundStyle(ClayTheme.textPrimary)
                    .lineSpacing(4)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("오늘 쓴 글: \(note.text)")
        .accessibilityHint("두 번 탭하면 고칠 수 있어요")
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.xs) {
            // 글자 수 제한은 두지 않는다. 쓰고 싶은 만큼 쓰게 둔다.
            TextEditor(text: $draft)
                .font(ClayFont.body())
                .foregroundStyle(ClayTheme.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 96)
                .padding(ClayTheme.Spacing.xs)
                .claySunken()
                .focused($isFocused)
                .accessibilityLabel("오늘 한 줄")
                .overlay(alignment: .topLeading) {
                    if draft.isEmpty {
                        Text(Self.prompt(for: .now))
                            .font(ClayFont.callout())
                            .foregroundStyle(ClayTheme.textSecondary)
                            .padding(.horizontal, ClayTheme.Spacing.xs + 5)
                            .padding(.vertical, ClayTheme.Spacing.xs + 8)
                            .allowsHitTesting(false)
                    }
                }

            Text("쓰는 대로 저장돼요.")
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
        }
        .onChange(of: draft) { _, _ in scheduleSave() }
    }

    /// 홈 구석에 작게. **크게 쓰지 않는다** — 압박이 아니라 배경이어야 한다.
    @ViewBuilder
    private var streakLine: some View {
        let streak = streaks.streak
        if !streak.homeText.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(streak.homeText)
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.textSecondary)
                if let note = streak.freezeNote {
                    Text(note)
                        .font(ClayFont.caption())
                        .foregroundStyle(ClayTheme.accent)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 쓰기

    private func beginEditing() {
        draft = today?.text ?? ""
        isEditing = true
        isFocused = true
    }

    private func finishEditing() {
        commit()
        isEditing = false
        isFocused = false
    }

    /// 글이 멈추고 나서 저장한다. 한 글자마다 저장하면 SwiftData 가 쉴 틈이 없다.
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            commit()
        }
    }

    private func commit() {
        saveTask?.cancel()
        saveTask = nil
        guard isEditing else { return }
        // 본문이 비면 NoteStore 가 그날 글을 지운다. 빈 껍데기를 남기지 않는다.
        notes.save(text: draft, for: presentation, source: .daily, mood: mood?.rawValue)

        // 연속 기록은 글이 실제로 남았을 때만 올린다. 썼다 지운 날까지 세면
        // 숫자가 거짓말이 되고, 사용자도 그걸 안다.
        if notes.notes(on: .now).isEmpty {
            streaks.undoToday()
        } else {
            streaks.recordEntry()
        }
    }

    // MARK: - 말 걸기

    /// 요일마다 다른 문구. 같은 물음이 매일 똑같이 오면 벽지가 된다.
    static func prompt(for date: Date, calendar: Calendar = .current) -> String {
        let weekday = calendar.component(.weekday, from: date)
        return prompts[(weekday - 1) % prompts.count]
    }

    private static let prompts = [
        "이 문장이 오늘 나에게 무슨 뜻인가요?",          // 일
        "한 주를 여는 오늘, 무엇을 붙잡고 싶나요?",      // 월
        "오늘 이 말이 필요한 순간이 있었나요?",          // 화
        "지금 머릿속에 남아 있는 한 가지는?",            // 수
        "오늘의 나에게 한 문장을 남긴다면?",             // 목
        "이번 주에 잘한 일 하나를 적어 볼까요?",         // 금
        "오늘은 어떤 하루였나요?"                        // 토
    ]
}

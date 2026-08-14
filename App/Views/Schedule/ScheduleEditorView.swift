import SwiftUI

/// 일정 편집 시트가 어떤 모드로 열렸는지.
enum ScheduleEditorTarget: Identifiable, Hashable {
    case create(date: Date)
    case edit(id: UUID)

    var id: String {
        switch self {
        case .create(let date): "create-\(date.timeIntervalSince1970)"
        case .edit(let id): "edit-\(id.uuidString)"
        }
    }
}

/// 일정 추가 / 수정 / 삭제 화면.
struct ScheduleEditorView: View {
    let target: ScheduleEditorTarget

    @Environment(ScheduleStore.self) private var store
    @Environment(NotificationService.self) private var notifications
    @Environment(\.dismiss) private var dismiss

    @State private var draft: ScheduleStore.Draft
    @State private var errorMessage: String?
    @State private var showsNotificationPermissionPrompt = false
    @State private var showsDeleteConfirmation = false
    /// 권한이 거부된 상태에서 알림을 켜려 할 때 안내를 띄운다.
    @State private var showsDeniedNotice = false

    private let quoteService = QuoteService.shared

    init(target: ScheduleEditorTarget) {
        self.target = target
        switch target {
        case .create(let date):
            _draft = State(initialValue: ScheduleStore.Draft.makeNew(on: date))
        case .edit:
            // 실제 값은 onAppear 에서 저장소를 보고 채운다.
            _draft = State(initialValue: ScheduleStore.Draft.makeNew(on: .now))
        }
    }

    private var editingItem: ScheduleItem? {
        guard case .edit(let id) = target else { return nil }
        return store.item(id: id)
    }

    private var isEditing: Bool { editingItem != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ClayTheme.Spacing.m) {
                    titleField
                    timeCard
                    categoryCard
                    notificationCard
                    memoCard
                    quotePreview

                    if isEditing {
                        Button(role: .destructive) {
                            showsDeleteConfirmation = true
                        } label: {
                            Label("일정 삭제", systemImage: "trash")
                        }
                        .clayButton(.destructive, fullWidth: true)
                        .padding(.top, ClayTheme.Spacing.xs)
                    }
                }
                .padding(ClayTheme.Spacing.m)
                .padding(.bottom, ClayTheme.Spacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
            .clayBackground(showsBlobs: false)
            .navigationTitle(isEditing ? "일정 수정" : "새 일정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .fontWeight(.bold)
                }
            }
            .alert("확인해 주세요", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("확인") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .alert("일정 시간에 명언을 알려드릴까요?", isPresented: $showsNotificationPermissionPrompt) {
                Button("알림 허용") {
                    Task {
                        let granted = await notifications.requestAuthorizationIfNeeded()
                        if !granted {
                            draft.isQuoteNotificationEnabled = false
                            showsDeniedNotice = true
                        }
                    }
                }
                Button("나중에", role: .cancel) {
                    draft.isQuoteNotificationEnabled = false
                }
            } message: {
                Text("일정이 시작될 때 카테고리에 어울리는 명언을 보내 드려요.")
            }
            .alert("알림이 꺼져 있어요", isPresented: $showsDeniedNotice) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("설정 앱 > QuoteDay > 알림에서 허용하면 명언 알림을 받을 수 있어요. 알림 없이도 일정은 정상적으로 저장됩니다.")
            }
            .confirmationDialog(
                "이 일정을 삭제할까요?",
                isPresented: $showsDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("삭제", role: .destructive) {
                    if let item = editingItem {
                        store.delete(item)
                    }
                    dismiss()
                }
                Button("취소", role: .cancel) {}
            }
            .onAppear(perform: loadIfEditing)
        }
    }

    // MARK: - 섹션

    private var titleField: some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.xs) {
            fieldLabel("일정 제목")
            TextField("예: 수학 공부", text: $draft.title)
                .font(ClayFont.body())
                .foregroundStyle(ClayTheme.textPrimary)
                .textInputAutocapitalization(.never)
                .padding(ClayTheme.Spacing.s + 2)
                .claySunken()
        }
    }

    private var timeCard: some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
            fieldLabel("날짜와 시간")
            DatePicker("시작", selection: $draft.startDate)
                .font(ClayFont.callout())
                .onChange(of: draft.startDate) { oldValue, newValue in
                    // 시작을 옮기면 길이를 유지한 채 종료도 함께 옮긴다.
                    let duration = draft.endDate.timeIntervalSince(oldValue)
                    draft.endDate = newValue.addingTimeInterval(max(duration, 0))
                }
            Divider().opacity(0.2)
            DatePicker("종료", selection: $draft.endDate, in: draft.startDate...)
                .font(ClayFont.callout())
        }
        .tint(ClayTheme.accent)
        .foregroundStyle(ClayTheme.textPrimary)
        .padding(ClayTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clayCard()
    }

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
            fieldLabel("카테고리")
            CategoryPicker(selection: $draft.category)
                .onChange(of: draft.category) { _, _ in
                    // 카테고리를 바꾸면 자동 배정된 명언도 다시 계산되도록 초기화한다.
                    draft.quoteSlug = nil
                }
        }
        .padding(ClayTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clayCard()
    }

    private var notificationCard: some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.xs) {
            Toggle(isOn: Binding(
                get: { draft.isQuoteNotificationEnabled },
                set: { newValue in
                    draft.isQuoteNotificationEnabled = newValue
                    guard newValue else { return }
                    if notifications.isDenied {
                        draft.isQuoteNotificationEnabled = false
                        showsDeniedNotice = true
                    } else if !notifications.isAuthorized {
                        showsNotificationPermissionPrompt = true
                    }
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("명언 알림")
                        .font(ClayFont.headline())
                        .foregroundStyle(ClayTheme.textPrimary)
                    Text("시작 시간에 이 카테고리의 명언을 보내 드려요.")
                        .font(ClayFont.caption())
                        .foregroundStyle(ClayTheme.textSecondary)
                }
            }
            .tint(ClayTheme.accent)

            if draft.startDate <= .now && draft.isQuoteNotificationEnabled {
                Text("이미 지난 시간이라 알림은 예약되지 않아요.")
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.danger)
            }
        }
        .padding(ClayTheme.Spacing.m)
        .clayCard()
    }

    private var memoCard: some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.xs) {
            fieldLabel("메모")
            TextEditor(text: $draft.memo)
                .font(ClayFont.body())
                .foregroundStyle(ClayTheme.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 84)
                .padding(ClayTheme.Spacing.xs)
                .claySunken()
        }
    }

    /// 저장하기 전에 어떤 명언이 붙을지 보여 준다.
    private var quotePreview: some View {
        let quote = resolvedPreviewQuote
        let presentation = quoteService.presentation(for: quote)

        return VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
            HStack {
                fieldLabel("배정될 명언")
                Spacer()
                Button {
                    cyclePreviewQuote()
                } label: {
                    Label("바꾸기", systemImage: "arrow.triangle.2.circlepath")
                        .font(ClayFont.caption())
                }
                .buttonStyle(.plain)
                .foregroundStyle(ClayTheme.accent)
                .accessibilityLabel("다른 명언으로 바꾸기")
            }

            Text("\u{201C}\(presentation.quote.text)\u{201D}")
                .font(ClayFont.body())
                .foregroundStyle(ClayTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("— \(presentation.author.displayName)")
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
        }
        .padding(ClayTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clayCard(tint: draft.category.tint.opacity(0.35))
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(ClayFont.caption())
            .foregroundStyle(ClayTheme.textSecondary)
    }

    // MARK: - 동작

    private var resolvedPreviewQuote: Quote {
        if let slug = draft.quoteSlug, let quote = quoteService.quote(slug: slug) {
            return quote
        }
        let seed = editingItem?.id.uuidString ?? "draft"
        return quoteService.quote(
            for: draft.category,
            seed: "\(seed):\(Int(draft.startDate.timeIntervalSince1970))"
        )
    }

    private func cyclePreviewQuote() {
        let pool = quoteService.candidatePool(for: draft.category)
        guard !pool.isEmpty else { return }
        let current = resolvedPreviewQuote
        let index = pool.firstIndex { $0.slug == current.slug } ?? -1
        withAnimation(.easeInOut(duration: 0.25)) {
            draft.quoteSlug = pool[(index + 1) % pool.count].slug
        }
    }

    private func loadIfEditing() {
        guard case .edit = target, let item = editingItem else { return }
        draft = ScheduleStore.Draft(item: item)
    }

    private func save() {
        do {
            if let item = editingItem {
                try store.update(item, with: draft)
            } else {
                try store.create(draft)
            }
            dismiss()
        } catch let failure as ScheduleValidator.Failure {
            errorMessage = failure.errorDescription
        } catch {
            errorMessage = "일정을 저장하지 못했습니다. 다시 시도해 주세요."
        }
    }
}

#Preview("일정 추가") {
    ScheduleEditorView(target: .create(date: .now))
        .injecting(AppEnvironment.preview())
}

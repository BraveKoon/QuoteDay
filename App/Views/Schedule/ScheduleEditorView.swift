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
                    repeatCard
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
            .clayBackground()
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
                deleteConfirmationTitle,
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
                    // 시작이 반복 종료일을 지나가면 종료일도 밀어 준다.
                    if let repeatEnd = draft.recurrence.endDate, repeatEnd < newValue {
                        draft.recurrence.endDate = defaultRepeatEndDate
                    }
                }
            ClayDivider()
            DatePicker("종료", selection: $draft.endDate, in: draft.startDate...)
                .font(ClayFont.callout())
        }
        .tint(ClayTheme.accent)
        .foregroundStyle(ClayTheme.textPrimary)
        .padding(ClayTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clayCard()
    }

    private var repeatCard: some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
            fieldLabel("반복")
            RecurrencePicker(selection: frequencyBinding)

            if draft.recurrence.isRepeating {
                ClayDivider()

                Toggle(isOn: repeatEndEnabledBinding) {
                    Text("반복 종료일 정하기")
                        .font(ClayFont.callout())
                        .foregroundStyle(ClayTheme.textPrimary)
                }
                .tint(ClayTheme.accent)

                if draft.recurrence.endDate != nil {
                    DatePicker(
                        "종료 날짜",
                        selection: repeatEndDateBinding,
                        in: draft.startDate...,
                        displayedComponents: .date
                    )
                    .font(ClayFont.callout())
                    .tint(ClayTheme.accent)
                    .foregroundStyle(ClayTheme.textPrimary)
                }

                Text(draft.recurrence.summary(anchor: draft.startDate))
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.textSecondary)

                if startsOnWeekendWithWeekdayRepeat {
                    Text("주말에 시작하는 주중 반복은 다음 평일부터 시작해요.")
                        .font(ClayFont.caption())
                        .foregroundStyle(ClayTheme.textSecondary)
                }

                if isEditing {
                    Text("반복 일정을 고치면 모든 회차에 함께 적용돼요.")
                        .font(ClayFont.caption())
                        .foregroundStyle(ClayTheme.textSecondary)
                }
            }
        }
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
                    Text(notificationDescription)
                        .font(ClayFont.caption())
                        .foregroundStyle(ClayTheme.textSecondary)
                }
            }
            .tint(ClayTheme.accent)

            if draft.isQuoteNotificationEnabled && !hasUpcomingOccurrence {
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

    /// 반복 일정은 회차 하나가 아니라 시리즈 전체가 지워진다.
    private var deleteConfirmationTitle: String {
        editingItem?.isRecurring == true ? "반복되는 회차를 모두 삭제할까요?" : "이 일정을 삭제할까요?"
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(ClayFont.caption())
            .foregroundStyle(ClayTheme.textSecondary)
    }

    // MARK: - 동작

    /// 주기를 바꾸면 종료일도 함께 정리한다(반복 안 함 → 종료일 없음).
    private var frequencyBinding: Binding<RecurrenceFrequency> {
        Binding(
            get: { draft.recurrence.frequency },
            set: { newValue in
                draft.recurrence = RecurrenceRule(
                    frequency: newValue,
                    endDate: draft.recurrence.endDate
                )
            }
        )
    }

    private var repeatEndEnabledBinding: Binding<Bool> {
        Binding(
            get: { draft.recurrence.endDate != nil },
            set: { isOn in draft.recurrence.endDate = isOn ? defaultRepeatEndDate : nil }
        )
    }

    private var repeatEndDateBinding: Binding<Date> {
        Binding(
            get: { draft.recurrence.endDate ?? defaultRepeatEndDate },
            set: { draft.recurrence.endDate = $0 }
        )
    }

    /// 종료일을 처음 켤 때 제안하는 날짜.
    private var defaultRepeatEndDate: Date {
        Calendar.current.date(byAdding: .month, value: 3, to: draft.startDate) ?? draft.startDate
    }

    /// 주말에 시작하는 "주중 매일" 은 그날 회차가 없다. 저장이 안 된 것처럼 보이지 않게 알려 준다.
    private var startsOnWeekendWithWeekdayRepeat: Bool {
        guard draft.recurrence.frequency == .weekday else { return false }
        let weekday = Calendar.current.component(.weekday, from: draft.startDate)
        return weekday == 1 || weekday == 7
    }

    private var notificationDescription: String {
        draft.recurrence.isRepeating
            ? "반복되는 회차마다 이 카테고리의 명언을 새로 골라 보내 드려요."
            : "시작 시간에 이 카테고리의 명언을 보내 드려요."
    }

    /// 앞으로 알림을 보낼 회차가 남아 있는지. 반복 일정은 시작이 지났어도 남아 있을 수 있다.
    private var hasUpcomingOccurrence: Bool {
        if draft.startDate > .now { return true }
        guard draft.recurrence.isRepeating else { return false }

        let now = Date.now
        let calendar = Calendar.current
        guard
            let horizon = calendar.date(
                byAdding: .day,
                value: NotificationService.scheduleHorizonDays,
                to: now
            )
        else { return false }

        return !draft.recurrence.occurrenceStarts(
            anchor: draft.startDate,
            from: now,
            to: horizon,
            limit: 1,
            calendar: calendar
        ).isEmpty
    }

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

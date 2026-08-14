import EventKit
import Foundation

/// iOS 기본 캘린더(EventKit) 연동.
///
/// 앱 내부 일정만으로도 모든 기능이 동작하므로, 이 서비스는 **선택 기능**이다.
/// 권한이 없거나 거부되어도 호출부는 `false` / 빈 배열만 받고 정상 동작한다.
@MainActor
@Observable
final class CalendarService {
    /// 읽기(가져오기)에 필요한 권한 상태.
    private(set) var authorizationStatus: EKAuthorizationStatus
    private(set) var lastErrorMessage: String?

    private let store: EKEventStore

    init(store: EKEventStore = EKEventStore()) {
        self.store = store
        self.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    /// 일정을 iOS 캘린더에 쓰기만 할 수 있으면 되는 경우.
    var canWrite: Bool {
        authorizationStatus == .fullAccess || authorizationStatus == .writeOnly
    }

    /// iOS 캘린더의 일정을 읽어 오려면 전체 접근이 필요하다.
    var canRead: Bool {
        authorizationStatus == .fullAccess
    }

    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    // MARK: - 권한 요청

    @discardableResult
    func requestWriteAccess() async -> Bool {
        refreshAuthorizationStatus()
        if canWrite { return true }
        if isDenied { return false }

        do {
            let granted = try await store.requestWriteOnlyAccessToEvents()
            refreshAuthorizationStatus()
            return granted
        } catch {
            record(error)
            refreshAuthorizationStatus()
            return false
        }
    }

    @discardableResult
    func requestFullAccess() async -> Bool {
        refreshAuthorizationStatus()
        if canRead { return true }
        if isDenied { return false }

        do {
            let granted = try await store.requestFullAccessToEvents()
            refreshAuthorizationStatus()
            return granted
        } catch {
            record(error)
            refreshAuthorizationStatus()
            return false
        }
    }

    // MARK: - 읽기

    /// 지정한 날짜의 iOS 캘린더 일정. 권한이 없으면 빈 배열.
    func systemEvents(on date: Date, calendar: Calendar = .current) -> [ImportedEvent] {
        guard canRead else { return [] }
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
            .sorted { ($0.startDate ?? start) < ($1.startDate ?? start) }
            .map(ImportedEvent.init(event:))
    }

    // MARK: - 쓰기

    /// 앱 일정을 iOS 캘린더에 내보낸다.
    /// - Returns: 생성된 EKEvent 식별자. 실패하면 nil.
    func export(
        title: String,
        start: Date,
        end: Date,
        notes: String?
    ) async -> String? {
        guard await requestWriteAccess() else { return nil }
        guard let target = store.defaultCalendarForNewEvents else {
            lastErrorMessage = "기본 캘린더를 찾을 수 없습니다."
            return nil
        }

        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = start
        event.endDate = max(end, start)
        event.notes = notes
        event.calendar = target

        do {
            try store.save(event, span: .thisEvent, commit: true)
            return event.eventIdentifier
        } catch {
            record(error)
            return nil
        }
    }

    /// 내보낸 일정을 갱신한다. 원본이 사라졌으면 새로 만든다.
    func updateExported(
        identifier: String,
        title: String,
        start: Date,
        end: Date,
        notes: String?
    ) async -> String? {
        guard await requestWriteAccess() else { return nil }
        guard let event = store.event(withIdentifier: identifier) else {
            return await export(title: title, start: start, end: end, notes: notes)
        }

        event.title = title
        event.startDate = start
        event.endDate = max(end, start)
        event.notes = notes

        do {
            try store.save(event, span: .thisEvent, commit: true)
            return event.eventIdentifier
        } catch {
            record(error)
            return nil
        }
    }

    func removeExported(identifier: String) {
        guard canWrite, let event = store.event(withIdentifier: identifier) else { return }
        do {
            try store.remove(event, span: .thisEvent, commit: true)
        } catch {
            record(error)
        }
    }

    private func record(_ error: Error) {
        lastErrorMessage = error.localizedDescription
        AppLog.calendar.error("EventKit 오류: \(error.localizedDescription, privacy: .public)")
    }
}

/// iOS 캘린더에서 읽어 온 일정의 표시용 값 타입.
///
/// `EKEvent` 를 뷰까지 끌고 가지 않기 위해 필요한 값만 복사한다.
struct ImportedEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let calendarTitle: String

    init(event: EKEvent) {
        self.id = event.eventIdentifier ?? UUID().uuidString
        self.title = event.title ?? "제목 없음"
        self.start = event.startDate ?? .now
        self.end = event.endDate ?? event.startDate ?? .now
        self.calendarTitle = event.calendar?.title ?? ""
    }
}

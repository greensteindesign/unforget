import Foundation
import EventKit
import Combine

@MainActor
final class CalendarService: ObservableObject {
    let store = EKEventStore()

    @Published var events: [ScheduledOccurrence] = []
    @Published var authStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)

    /// Calendar IDs the user has deselected.
    var excludedCalendarIDs: Set<String> = [] {
        didSet { refresh() }
    }

    /// Title keywords that should not trigger an alarm (e.g. "focus time").
    var excludeKeywords: [String] = [] {
        didSet { refresh() }
    }

    private var observer: NSObjectProtocol?
    private var refreshWork: DispatchWorkItem?

    init() {
        // EKEventStoreChanged fires in bursts during sync runs → debounce
        // so we don't fetch ten times in a row.
        observer = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: store, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.scheduleDebouncedRefresh() }
        }
    }

    private func scheduleDebouncedRefresh() {
        refreshWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.refresh() }
        }
        refreshWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }

    var hasFullAccess: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    func requestAccess() async {
        do {
            _ = try await store.requestFullAccessToEvents()
        } catch {
            NSLog("Unforget: calendar access failed: \(error)")
        }
        authStatus = EKEventStore.authorizationStatus(for: .event)
        refresh()
    }

    func allCalendars() -> [EKCalendar] {
        guard hasFullAccess else { return [] }
        return store.calendars(for: .event).sorted { $0.title < $1.title }
    }

    /// Loads events for the next 48 h (plus the past hour for "already running" alerts).
    func refresh() {
        // Always keep the authorization status current (the user can change it at any time).
        authStatus = EKEventStore.authorizationStatus(for: .event)
        guard hasFullAccess else {
            events = []
            return
        }
        let calendars = store.calendars(for: .event)
            .filter { !excludedCalendarIDs.contains($0.calendarIdentifier) }
        guard !calendars.isEmpty else {
            events = []
            return
        }
        let predicate = store.predicateForEvents(
            withStart: Date().addingTimeInterval(-3600),
            end: Date().addingTimeInterval(48 * 3600),
            calendars: calendars
        )
        let keywords = excludeKeywords
        let ekEvents = store.events(matching: predicate)
            .filter { !$0.isAllDay && $0.status != .canceled }
            .filter { ev in
                // Declined invitations don't trigger an alarm.
                if let attendees = ev.attendees,
                   let me = attendees.first(where: { $0.isCurrentUser }),
                   me.participantStatus == .declined {
                    return false
                }
                // Keyword filter ("focus time", "blocker", …).
                if !keywords.isEmpty {
                    let title = (ev.title ?? "").lowercased()
                    if keywords.contains(where: { title.contains($0) }) {
                        return false
                    }
                }
                return true
            }

        events = ekEvents.compactMap { ev in
            guard let start = ev.startDate, let end = ev.endDate else { return nil }
            let identifier = ev.eventIdentifier ?? "\(ev.calendarItemIdentifier)"
            return ScheduledOccurrence(
                id: "\(identifier)#\(Int(start.timeIntervalSince1970))",
                title: ev.title ?? "—",
                startDate: start,
                endDate: end,
                location: ev.location?.trimmingCharacters(in: .whitespacesAndNewlines),
                meetingURL: MeetingLinkParser.find(in: ev),
                isCustom: false,
                notes: Self.cleanNotes(ev.notes)
            )
        }
        .sorted { $0.startDate < $1.startDate }
    }

    /// Meeting invitations often contain pages of boilerplate — we show
    /// only the first real lines of text, without URLs.
    private static func cleanNotes(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        let lines = raw
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { line in
                guard !line.isEmpty else { return false }
                if line.lowercased().hasPrefix("http") { return false }
                if line.range(of: #"^[-—_=~•]+$"#, options: .regularExpression) != nil { return false }
                return true
            }
        let joined = lines.prefix(2).joined(separator: " · ")
        guard !joined.isEmpty else { return nil }
        return joined.count > 160 ? String(joined.prefix(159)) + "…" : joined
    }
}

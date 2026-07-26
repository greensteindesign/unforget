import Foundation
import Combine

/// Custom reminders (without the calendar) — stored locally as JSON, no account, no cloud.
@MainActor
final class ReminderStore: ObservableObject {
    @Published private(set) var reminders: [CustomReminder] = []

    private var fileURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("Unforget", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("reminders.json")
        // One-time migration of existing data from before the rebrand ("LosJetzt").
        let legacy = support.appendingPathComponent("LosJetzt/reminders.json")
        if !FileManager.default.fileExists(atPath: url.path),
           FileManager.default.fileExists(atPath: legacy.path) {
            try? FileManager.default.moveItem(at: legacy, to: url)
        }
        return url
    }

    init() {
        load()
        prune()
    }

    var occurrences: [ScheduledOccurrence] {
        reminders.map(\.occurrence)
    }

    func add(title: String, fireDate: Date) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        reminders.append(CustomReminder(
            id: UUID(),
            title: trimmed.isEmpty ? L.s("quick.fallbackTitle") : trimmed,
            fireDate: fireDate
        ))
        save()
    }

    func remove(occurrenceID: String) {
        reminders.removeAll { $0.occurrence.id == occurrenceID }
        save()
    }

    /// Silently clean up reminders older than 1 h.
    func prune() {
        let cutoff = Date().addingTimeInterval(-3600)
        let before = reminders.count
        reminders.removeAll { $0.fireDate < cutoff }
        if reminders.count != before { save() }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([CustomReminder].self, from: data) else { return }
        reminders = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(reminders) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

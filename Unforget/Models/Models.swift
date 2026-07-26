import Foundation

/// An upcoming alert candidate — from the calendar or a custom reminder.
struct ScheduledOccurrence: Identifiable, Equatable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let meetingURL: URL?
    let isCustom: Bool
    /// Cleaned-up notes preview (max. 2 lines in the overlay).
    var notes: String? = nil
    /// Custom reminders fire exactly at the chosen time (stage 0),
    /// calendar events follow the global escalation stages.
    var stagesOverride: [Int]? { isCustom ? [0] : nil }
}

struct CustomReminder: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var fireDate: Date

    var occurrence: ScheduledOccurrence {
        ScheduledOccurrence(
            id: "custom-\(id.uuidString)",
            title: title,
            startDate: fireDate,
            endDate: fireDate.addingTimeInterval(300),
            location: nil,
            meetingURL: nil,
            isCustom: true
        )
    }
}

/// Quick pick for the stages. The source of truth is `AppSettings.enabledStages` —
/// a preset merely sets them all in one go.
enum EscalationPreset: String, CaseIterable, Identifiable {
    case single, standard, ramp
    var id: String { rawValue }

    var label: String {
        switch self {
        case .single: return L.s("preset.single")
        case .standard: return L.s("preset.standard")
        case .ramp: return L.s("preset.ramp")
        }
    }

    /// Minutes before start. The smallest stage is always the fullscreen alert.
    var stages: Set<Int> {
        switch self {
        case .single: return [1]
        case .standard: return [5, 1]
        case .ramp: return [15, 5, 1]
        }
    }
}

struct Trigger {
    enum Kind { case preWarn, final, missed, snoozeReturn, hardStop }
    let occurrence: ScheduledOccurrence
    let stage: Int
    let kind: Kind
    let fireDate: Date
    /// For .hardStop: title of the event that follows immediately.
    var followerTitle: String? = nil
    /// Follow-up after the event has started — its own flag so it doesn't
    /// clash with the caught-up main alert.
    var isFollowUp: Bool = false
}

/// When Unforget is allowed to remind at all. Chosen in the setup assistant
/// and checked in the scheduler at the same spot as quiet hours.
enum AlertProfile: String, CaseIterable, Identifiable {
    case always, daytime, days
    var id: String { rawValue }
    var label: String { L.s("profile.\(rawValue)") }
    var note: String { L.s("profile.\(rawValue).note") }
}

/// Graphic style of the alert. The same eight also live on unforget-app.de,
/// so people can try them before downloading. The color and shape values
/// sit as tokens in `Theme.swift` — this is only identity and labeling.
enum AlarmStyle: String, CaseIterable, Identifiable {
    case modern, business, playful, kids, pink, mono, terminal, sunset
    var id: String { rawValue }
    var label: String { L.s("style.\(rawValue)") }
    var note: String { L.s("style.\(rawValue).note") }
}

enum Intensity: Int, CaseIterable, Identifiable {
    case sachlich = 0, freundlich = 1, frech = 2
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .sachlich: return L.s("intensity.plain")
        case .freundlich: return L.s("intensity.friendly")
        case .frech: return L.s("intensity.cheeky")
        }
    }
}

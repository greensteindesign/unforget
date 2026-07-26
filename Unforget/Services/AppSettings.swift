import Foundation
import Combine
import ServiceManagement

@MainActor
final class AppSettings: ObservableObject {
    private let d = UserDefaults.standard

    /// Active alarm stages in minutes before the event. The smallest stage is the
    /// fullscreen alarm, larger ones are quiet pre-warnings.
    /// Factory default deliberately just `[1]`: one alarm is enough, anything more is annoying.
    @Published var enabledStages: Set<Int> {
        didSet { d.set(enabledStages.sorted(), forKey: "enabledStages") }
    }
    /// Follow up when the event is running and nobody has reacted.
    @Published var followUpEnabled: Bool {
        didSet { d.set(followUpEnabled, forKey: "followUpEnabled") }
    }
    /// Minutes after event start for the follow-up.
    @Published var followUpMinutes: Int {
        didSet { d.set(followUpMinutes, forKey: "followUpMinutes") }
    }
    @Published var soundEnabled: Bool {
        didSet { d.set(soundEnabled, forKey: "soundEnabled") }
    }
    @Published var soundName: String {
        didSet { d.set(soundName, forKey: "soundName") }
    }
    @Published var nagRepeat: Bool {
        didSet { d.set(nagRepeat, forKey: "nagRepeat") }
    }
    @Published var intensity: Intensity {
        didSet { d.set(intensity.rawValue, forKey: "intensity") }
    }
    @Published var excludedCalendarIDs: Set<String> {
        didSet { d.set(Array(excludedCalendarIDs), forKey: "excludedCalendarIDs") }
    }
    @Published var quietHoursEnabled: Bool {
        didSet { d.set(quietHoursEnabled, forKey: "quietHoursEnabled") }
    }
    /// Minutes since midnight (default 22:00–07:00).
    @Published var quietStartMinutes: Int {
        didSet { d.set(quietStartMinutes, forKey: "quietStartMinutes") }
    }
    @Published var quietEndMinutes: Int {
        didSet { d.set(quietEndMinutes, forKey: "quietEndMinutes") }
    }
    @Published var language: AppLanguage {
        didSet { d.set(language.rawValue, forKey: "language") }
    }
    @Published var presence: AppPresence {
        didSet { d.set(presence.rawValue, forKey: "presence") }
    }
    /// Comma-separated title keywords that don't trigger an alarm.
    @Published var excludeKeywordsRaw: String {
        didSet { d.set(excludeKeywordsRaw, forKey: "excludeKeywordsRaw") }
    }
    /// During running video meetings, show only banners instead of fullscreen.
    @Published var presentationGuard: Bool {
        didSet { d.set(presentationGuard, forKey: "presentationGuard") }
    }
    /// Read the event title aloud on alarm.
    @Published var speechEnabled: Bool {
        didSet { d.set(speechEnabled, forKey: "speechEnabled") }
    }
    /// Visual style of the alarm (the same eight as on the website).
    @Published var alarmStyle: AlarmStyle {
        didSet { d.set(alarmStyle.rawValue, forKey: "alarmStyle") }
    }
    /// Custom accent color as "#rrggbb"; empty = the style's color.
    @Published var accentHex: String {
        didSet { d.set(accentHex, forKey: "accentHex") }
    }
    /// File name of the custom logo in the sandbox container; empty = none.
    @Published var logoFileName: String {
        didSet { d.set(logoFileName, forKey: "logoFileName") }
    }
    /// When Unforget is allowed to remind (Always / Daytime / Specific days).
    @Published var alertProfile: AlertProfile {
        didSet { d.set(alertProfile.rawValue, forKey: "alertProfile") }
    }
    /// Time window for the "Daytime" and "Specific days" profiles, minutes since midnight.
    @Published var activeFromMinutes: Int {
        didSet { d.set(activeFromMinutes, forKey: "activeFromMinutes") }
    }
    @Published var activeToMinutes: Int {
        didSet { d.set(activeToMinutes, forKey: "activeToMinutes") }
    }
    /// Weekdays for "Specific days" — Calendar numbering, 1 = Sunday.
    @Published var activeWeekdays: Set<Int> {
        didSet { d.set(Array(activeWeekdays).sorted(), forKey: "activeWeekdays") }
    }

    var excludeKeywords: [String] {
        excludeKeywordsRaw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }

    static let availableSounds = ["Glass", "Submarine", "Ping", "Hero", "Funk", "Blow", "Sosumi"]

    /// Selectable stages, descending — exactly the three from the setup assistant.
    static let availableStages = [15, 5, 1]

    /// Sorted descending; empty is not allowed, otherwise no alarm would ever fire.
    var stages: [Int] {
        enabledStages.isEmpty ? [1] : enabledStages.sorted(by: >)
    }

    /// Smallest active stage = the fullscreen alarm (for the test alarm and the menu).
    var leadMinutes: Int { stages.last ?? 1 }

    /// If the current selection matches a preset, returns it — otherwise nil (= "Custom").
    var matchingPreset: EscalationPreset? {
        EscalationPreset.allCases.first { $0.stages == enabledStages }
    }

    init() {
        // Migration: whoever deliberately picked a preset in 1.0 keeps their stages.
        // Everyone else gets the new, calmer default.
        if let saved = d.array(forKey: "enabledStages") as? [Int], !saved.isEmpty {
            enabledStages = Set(saved)
        } else if let oldPreset = d.string(forKey: "preset") {
            let lead = d.object(forKey: "leadMinutes") as? Int ?? 1
            let pre: [Int] = oldPreset == "ramp" ? [15, 5] : (oldPreset == "standard" ? [5] : [])
            enabledStages = Set(pre.filter { $0 > lead } + [lead])
        } else {
            enabledStages = [1]
        }
        followUpEnabled = d.object(forKey: "followUpEnabled") as? Bool ?? true
        followUpMinutes = d.object(forKey: "followUpMinutes") as? Int ?? 1
        soundEnabled = d.object(forKey: "soundEnabled") as? Bool ?? true
        soundName = d.string(forKey: "soundName") ?? "Submarine"
        nagRepeat = d.object(forKey: "nagRepeat") as? Bool ?? true
        intensity = Intensity(rawValue: d.object(forKey: "intensity") as? Int ?? 1) ?? .freundlich
        excludedCalendarIDs = Set(d.stringArray(forKey: "excludedCalendarIDs") ?? [])
        quietHoursEnabled = d.object(forKey: "quietHoursEnabled") as? Bool ?? false
        quietStartMinutes = d.object(forKey: "quietStartMinutes") as? Int ?? 22 * 60
        quietEndMinutes = d.object(forKey: "quietEndMinutes") as? Int ?? 7 * 60
        language = AppLanguage(rawValue: d.string(forKey: "language") ?? "") ?? .system
        presence = AppPresence(rawValue: d.string(forKey: "presence") ?? "") ?? .menuBar
        excludeKeywordsRaw = d.string(forKey: "excludeKeywordsRaw") ?? ""
        presentationGuard = d.object(forKey: "presentationGuard") as? Bool ?? true
        speechEnabled = d.object(forKey: "speechEnabled") as? Bool ?? false
        alarmStyle = AlarmStyle(rawValue: d.string(forKey: "alarmStyle") ?? "") ?? .modern
        accentHex = d.string(forKey: "accentHex") ?? ""
        logoFileName = d.string(forKey: "logoFileName") ?? ""
        alertProfile = AlertProfile(rawValue: d.string(forKey: "alertProfile") ?? "") ?? .always
        activeFromMinutes = d.object(forKey: "activeFromMinutes") as? Int ?? 8 * 60
        activeToMinutes = d.object(forKey: "activeToMinutes") as? Int ?? 18 * 60
        let savedDays = d.array(forKey: "activeWeekdays") as? [Int]
        activeWeekdays = Set(savedDays ?? [2, 3, 4, 5, 6]) // Mon–Fri
    }

    /// Are reminders allowed at this point in time at all? (Profile check.)
    func isActive(at date: Date) -> Bool {
        guard alertProfile != .always else { return true }
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute, .weekday], from: date)
        let minute = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        let weekday = comps.weekday ?? 1

        let days: Set<Int> = alertProfile == .daytime ? [2, 3, 4, 5, 6] : activeWeekdays
        guard days.contains(weekday) else { return false }
        guard activeFromMinutes != activeToMinutes else { return true }
        return activeFromMinutes < activeToMinutes
            ? (minute >= activeFromMinutes && minute < activeToMinutes)
            : (minute >= activeFromMinutes || minute < activeToMinutes) // across midnight
    }

    /// Next point in time when the profile is active again. Needed so the
    /// scheduler knows when it should recompute.
    private func nextActiveDate(after date: Date) -> Date? {
        let cal = Calendar.current
        // Look ahead in quarter-hour steps for up to eight days — enough
        // even for a profile with a single weekday.
        var probe = date
        let limit = date.addingTimeInterval(8 * 24 * 3600)
        while probe < limit {
            guard let next = cal.date(byAdding: .minute, value: 15, to: probe) else { return nil }
            if isActive(at: next) { return next }
            probe = next
        }
        return nil
    }

    /// Quiet hours AND profile in one value: until when does it stay quiet?
    /// nil = reminders may fire immediately.
    func suppressedUntil(for date: Date) -> Date? {
        let quiet = quietHoursEnd(for: date)
        let profile = isActive(at: date) ? nil : nextActiveDate(after: date)
        switch (quiet, profile) {
        case (nil, nil): return nil
        case let (q?, nil): return q
        case let (nil, p?): return p
        case let (q?, p?): return max(q, p)
        }
    }

    /// If `date` falls within quiet hours, returns the end of the quiet period — otherwise nil.
    func quietHoursEnd(for date: Date) -> Date? {
        guard quietHoursEnabled, quietStartMinutes != quietEndMinutes else { return nil }
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: date)
        let nowMin = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        let start = quietStartMinutes, end = quietEndMinutes
        let inQuiet = start < end
            ? (nowMin >= start && nowMin < end)
            : (nowMin >= start || nowMin < end) // window spanning midnight
        guard inQuiet else { return nil }
        var endDate = cal.date(bySettingHour: end / 60, minute: end % 60, second: 0, of: date) ?? date
        if endDate <= date {
            endDate = cal.date(byAdding: .day, value: 1, to: endDate) ?? endDate
        }
        return endDate
    }

    // MARK: - Launch at Login

    var launchAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Unforget: LaunchAtLogin failed: \(error)")
        }
        objectWillChange.send()
    }
}

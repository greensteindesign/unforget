import AppKit
import SwiftUI
import Combine

/// Central coordinator: wires up calendar, scheduler, overlay, sound & quips.
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    let settings = AppSettings()
    let calendar = CalendarService()
    let reminderStore = ReminderStore()
    let scheduler = AlarmScheduler()
    let overlay = OverlayController()
    let banner = BannerController()
    let sound = SoundService()
    let speech = SpeechService()
    let personality = PersonalityEngine()

    @Published var menuTitle: String = ""
    /// Short countdown next to the menu bar icon — only when things get serious soon.
    @Published var menuBadge: String = ""
    @Published var pausedUntil: Date?
    /// Controls whether the menu bar icon is inserted (the "Show in" setting).
    @Published var menuBarInserted = true
    /// Counts language switches. `L` is not an ObservableObject source — without
    /// this signal, already-built windows (Welcome/Quick Reminder/Feedback)
    /// would stay stuck in the old language after a language switch.
    @Published private(set) var languageTick = 0

    private var pendingTriggers: [Trigger] = []
    private var cancellables = Set<AnyCancellable>()
    private var menuTimer: Timer?
    private var welcomeWindow: NSWindow?
    private var quickReminderWindow: NSWindow?
    private var feedbackWindow: NSWindow?

    /// Apply the language and let open SwiftUI windows re-render.
    private func applyLanguage() {
        let code = settings.language.effectiveCode
        guard L.code != code else { return }
        L.code = code
        languageTick &+= 1
    }

    /// Mirror the appearance into the static `Theme` table. The overlay is built
    /// by AppKit and has no access to `@EnvironmentObject` — hence the same
    /// pattern as with `L.code`.
    private func applyAppearance() {
        Theme.style = settings.alarmStyle
        Theme.userAccentHex = settings.accentHex
        Theme.logoFileName = settings.logoFileName
    }

    private init() {
        L.code = settings.language.effectiveCode
        Theme.style = settings.alarmStyle
        Theme.userAccentHex = settings.accentHex
        Theme.logoFileName = settings.logoFileName
        menuBarInserted = settings.presence != .dock
        scheduler.stages = settings.stages
        scheduler.followUpMinutes = settings.followUpEnabled ? settings.followUpMinutes : nil
        calendar.excludedCalendarIDs = settings.excludedCalendarIDs
        calendar.excludeKeywords = settings.excludeKeywords
        // Quiet hours AND the profile ("Always" / "Daytime" / "Specific days")
        // go through the same valve — the scheduler only knows "quiet until".
        scheduler.quietUntil = { [weak self] date in
            self?.settings.suppressedUntil(for: date)
        }

        scheduler.onFire = { [weak self] trigger in
            self?.handleFire(trigger)
        }

        // Calendar events + custom reminders → scheduler
        Publishers.CombineLatest(calendar.$events, reminderStore.$reminders)
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { [weak self] events, reminders in
                guard let self else { return }
                self.scheduler.occurrences = events + reminders.map(\.occurrence)
                self.updateMenuTitle()
            }
            .store(in: &cancellables)

        // Settings changes → propagate stages & calendar filters
        settings.objectWillChange
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.applyLanguage()
                self.applyAppearance()
                if self.scheduler.stages != self.settings.stages {
                    self.scheduler.stages = self.settings.stages
                }
                let follow = self.settings.followUpEnabled ? self.settings.followUpMinutes : nil
                if self.scheduler.followUpMinutes != follow {
                    self.scheduler.followUpMinutes = follow
                }
                if self.calendar.excludedCalendarIDs != self.settings.excludedCalendarIDs {
                    self.calendar.excludedCalendarIDs = self.settings.excludedCalendarIDs
                }
                if self.calendar.excludeKeywords != self.settings.excludeKeywords {
                    self.calendar.excludeKeywords = self.settings.excludeKeywords
                }
                let inserted = self.settings.presence != .dock
                if self.menuBarInserted != inserted {
                    self.menuBarInserted = inserted
                }
                self.applyPresence()
                self.updateMenuTitle()
            }
            .store(in: &cancellables)

        menuTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { _ in
            Task { @MainActor in AppState.shared.updateMenuTitle() }
        }

        calendar.refresh()
        updateMenuTitle()
    }

    // MARK: - Alarm flow

    private func handleFire(_ trigger: Trigger) {
        guard trigger.kind == .preWarn || !overlayBusy(with: trigger) else { return }

        switch trigger.kind {
        case .preWarn:
            let minutes = max(1, Int(trigger.occurrence.startDate.timeIntervalSinceNow / 60))
            banner.show(
                title: trigger.occurrence.title,
                message: personality.message(for: .preWarn, intensity: settings.intensity, minutes: minutes),
                style: .preWarn
            )
            if settings.soundEnabled {
                sound.playOnce(name: settings.soundName, rampUp: true)
            }

        case .hardStop:
            banner.show(
                title: trigger.occurrence.title,
                message: L.f("banner.hardstop", trigger.followerTitle ?? "…"),
                style: .preWarn,
                seconds: 15
            )
            if settings.soundEnabled {
                sound.playOnce(name: settings.soundName, rampUp: true)
            }

        case .final, .missed, .snoozeReturn:
            // Presentation guard: anyone currently in a video call doesn't get a
            // fullscreen takeover in front of the whole room — just a subtle banner.
            // The alarm comes back automatically, without snooze escalation.
            if settings.presentationGuard, isPresentationActive(excluding: trigger.occurrence.id) {
                banner.show(
                    title: trigger.occurrence.title,
                    message: L.s("banner.guarded"),
                    style: .preWarn,
                    seconds: 12
                )
                scheduler.requeue(trigger.occurrence.id, minutes: 3)
                return
            }
            if overlay.isShowing {
                pendingTriggers.append(trigger)
            } else {
                presentOverlay(for: trigger)
            }
        }
    }

    /// Is a video meeting running right now? (An acknowledged calendar meeting with
    /// a link, or a running link meeting + an active conferencing app.)
    private static let conferenceBundleIDs: Set<String> = [
        "us.zoom.xos", "com.microsoft.teams2", "com.microsoft.teams",
        "Cisco-Systems.Spark", "com.webex.meetingmanager",
        "com.skype.skype", "com.apple.FaceTime", "com.hnc.Discord",
    ]

    private func isPresentationActive(excluding occurrenceID: String) -> Bool {
        let now = Date()
        let runningMeetings = scheduler.occurrences.filter {
            $0.id != occurrenceID && $0.meetingURL != nil
                && $0.startDate <= now && now < $0.endDate
        }
        guard !runningMeetings.isEmpty else { return false }
        if runningMeetings.contains(where: { scheduler.isAcknowledged($0.id) }) {
            return true
        }
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        return !running.isDisjoint(with: Self.conferenceBundleIDs)
    }

    private func overlayBusy(with trigger: Trigger) -> Bool {
        overlay.isShowing && overlay.current?.occurrence.id == trigger.occurrence.id
    }

    private func presentOverlay(for trigger: Trigger) {
        let context: PersonalityEngine.Context
        switch trigger.kind {
        case .missed: context = .missed
        case .snoozeReturn: context = .snoozeReturn
        default: context = .final
        }

        let occ = trigger.occurrence
        let presentation = AlarmPresentation(
            occurrence: occ,
            kind: trigger.kind,
            message: personality.message(for: context, intensity: settings.intensity),
            snoozeLabel: L.s("overlay.snooze"),
            onConfirm: { [weak self] in self?.finish(occ, celebrate: true) },
            onSnooze: { [weak self] in self?.snooze(occ) },
            onIgnore: { [weak self] in self?.finish(occ, celebrate: false) },
            onJoin: { [weak self] url in
                NSWorkspace.shared.open(url)
                self?.finish(occ, celebrate: true)
            }
        )
        overlay.present(presentation)
        if settings.soundEnabled {
            sound.startNagging(name: settings.soundName, repeats: settings.nagRepeat)
        }
        if settings.speechEnabled {
            let key = trigger.kind == .missed ? "speech.missed" : "speech.final"
            speech.announce(L.f(key, occ.title))
        }
    }

    /// Apply the presence mode: menu bar, Dock, or both.
    func applyPresence() {
        switch settings.presence {
        case .menuBar:
            if NSApp.activationPolicy() != .accessory {
                NSApp.setActivationPolicy(.accessory)
            }
        case .dock, .both:
            if NSApp.activationPolicy() != .regular {
                NSApp.setActivationPolicy(.regular)
            }
        }
    }

    private func finish(_ occ: ScheduledOccurrence, celebrate: Bool) {
        sound.stop()
        speech.stop()
        overlay.dismiss()
        scheduler.acknowledge(occ.id)
        if occ.isCustom {
            reminderStore.remove(occurrenceID: occ.id)
        }
        if celebrate {
            banner.show(
                title: L.s("banner.success.title"),
                message: personality.message(for: .confirm, intensity: settings.intensity),
                style: .success,
                seconds: 4
            )
        }
        updateMenuTitle()
        showNextPendingIfAny()
    }

    private func snooze(_ occ: ScheduledOccurrence) {
        sound.stop()
        speech.stop()
        overlay.dismiss()
        let minutes = scheduler.snooze(occ.id)
        banner.show(
            title: occ.title,
            message: L.f("banner.snoozed", minutes),
            style: .preWarn,
            seconds: 5
        )
        showNextPendingIfAny()
    }

    private func showNextPendingIfAny() {
        guard !pendingTriggers.isEmpty else { return }
        let next = pendingTriggers.removeFirst()
        if !scheduler.isAcknowledged(next.occurrence.id) {
            presentOverlay(for: next)
        } else {
            showNextPendingIfAny()
        }
    }

    // MARK: - Menu bar

    func updateMenuTitle() {
        guard let next = scheduler.nextUpcoming else {
            setIfChanged(\.menuTitle, "")
            setIfChanged(\.menuBadge, "")
            return
        }
        let minutes = Int(next.startDate.timeIntervalSinceNow / 60)
        let newBadge: String
        if minutes < 1 {
            newBadge = L.s("badge.now")
        } else if minutes < 60 {
            newBadge = L.f("badge.inMin", minutes)
        } else {
            newBadge = ""
        }
        setIfChanged(\.menuBadge, newBadge)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let rel: String
        if minutes >= 120 {
            rel = L.f("badge.inH", minutes / 60)
        } else if minutes >= 1 {
            rel = L.f("menu.rel.inMin", minutes)
        } else {
            rel = L.s("menu.rel.now")
        }
        let title = next.title.count > 22 ? String(next.title.prefix(21)) + "…" : next.title
        setIfChanged(\.menuTitle, "\(formatter.string(from: next.startDate)) \(title) · \(rel)")
    }

    /// @Published fires even when the value is identical — we avoid that so
    /// MenuBarExtra scene updates aren't triggered unnecessarily.
    private func setIfChanged<T: Equatable>(_ keyPath: ReferenceWritableKeyPath<AppState, T>, _ value: T) {
        if self[keyPath: keyPath] != value {
            self[keyPath: keyPath] = value
        }
    }

    // MARK: - Pause

    func pause(until date: Date) {
        pausedUntil = date
        scheduler.pausedUntil = date
    }

    func resume() {
        pausedUntil = nil
        scheduler.pausedUntil = nil
    }

    // MARK: - Upcoming events (menu)

    var upcomingOccurrences: [ScheduledOccurrence] {
        scheduler.upcoming(limit: 5)
    }

    /// Show the alarm for an event immediately (e.g. to join a meeting early).
    func previewAlarm(_ occ: ScheduledOccurrence) {
        sound.stop()
        overlay.dismiss()
        presentOverlay(for: Trigger(occurrence: occ, stage: settings.leadMinutes, kind: .final, fireDate: Date()))
    }

    /// Mute the next event without any drama.
    func skipNext() {
        guard let next = scheduler.nextUpcoming else { return }
        scheduler.acknowledge(next.id)
        banner.show(
            title: next.title,
            message: L.s("banner.skipped"),
            style: .success,
            seconds: 4
        )
        updateMenuTitle()
    }

    // MARK: - Demo mode (for store screenshots, via --demo-alarm=…)

    func runDemo(_ kind: String) {
        Theme.overlayOpacity = 1.0
        let occ: ScheduledOccurrence
        var triggerKind: Trigger.Kind = .final
        switch kind {
        case "custom":
            occ = ScheduledOccurrence(
                id: "demo-custom", title: L.s("demo.custom.title"),
                startDate: Date().addingTimeInterval(48), endDate: Date().addingTimeInterval(348),
                location: nil, meetingURL: nil, isCustom: true
            )
        case "missed":
            occ = ScheduledOccurrence(
                id: "demo-missed", title: L.s("demo.missed.title"),
                startDate: Date().addingTimeInterval(-150), endDate: Date().addingTimeInterval(1650),
                location: nil, meetingURL: URL(string: "https://meet.google.com/abc-defg-hij"),
                isCustom: false, notes: L.s("demo.missed.notes")
            )
            triggerKind = .missed
        default:
            occ = ScheduledOccurrence(
                id: "demo-meeting", title: L.s("demo.meeting.title"),
                startDate: Date().addingTimeInterval(58), endDate: Date().addingTimeInterval(1858),
                location: nil, meetingURL: URL(string: "https://meet.google.com/abc-defg-hij"),
                isCustom: false, notes: L.s("demo.meeting.notes")
            )
        }
        sound.stop()
        overlay.dismiss()
        presentOverlay(for: Trigger(occurrence: occ, stage: 1, kind: triggerKind, fireDate: Date()))
        sound.stop() // screenshots don't need sound
    }

    // MARK: - Test alarm

    func triggerTestAlarm() {
        let occ = ScheduledOccurrence(
            id: "test-\(UUID().uuidString)",
            title: L.s("test.title"),
            startDate: Date().addingTimeInterval(45),
            endDate: Date().addingTimeInterval(345),
            location: L.s("test.location"),
            meetingURL: nil,
            isCustom: true
        )
        presentOverlay(for: Trigger(occurrence: occ, stage: 0, kind: .final, fireDate: Date()))
    }

    // MARK: - Windows

    func requestCalendarAccess() {
        Task { await calendar.requestAccess() }
    }

    func showWelcomeWindowIfNeeded() {
        // Show it even when access is granted, as long as the assistant never
        // ran to completion — otherwise nobody ever sees the profile and stage selection.
        let done = UserDefaults.standard.bool(forKey: "setupCompleted")
        guard !calendar.hasFullAccess || !done else { return }
        showWelcomeWindow()
    }

    func closeWelcomeWindow() {
        welcomeWindow?.orderOut(nil)
    }

    /// Builds the small utility windows (Welcome/Quick Reminder/Feedback).
    ///
    /// IMPORTANT: By default `NSHostingController` also reports min/max size
    /// to the window (`.minSize`/`.maxSize`). With multi-line, centered text
    /// this negotiation oscillates back and forth endlessly — AppKit then throws
    /// "more Update Constraints in Window passes than there are views" as an
    /// NSGenericException and the app dies on first launch (crash in the
    /// TestFlight build 0.6.1). Report only `.preferredContentSize`: the window
    /// still grows with its content, but without the min/max endless loop.
    private func makeUtilityWindow(_ root: some View) -> NSWindow {
        let hosting = NSHostingController(rootView: root)
        hosting.sizingOptions = [.preferredContentSize]
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }

    func showWelcomeWindow() {
        if welcomeWindow == nil {
            welcomeWindow = makeUtilityWindow(
                WelcomeView(calendar: calendar, settings: settings).environmentObject(self)
            )
        }
        welcomeWindow?.title = L.s("welcome.windowTitle")
        welcomeWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showQuickReminderWindow() {
        if quickReminderWindow == nil {
            quickReminderWindow = makeUtilityWindow(QuickReminderView().environmentObject(self))
        }
        quickReminderWindow?.title = L.s("quick.windowTitle")
        quickReminderWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeQuickReminderWindow() {
        quickReminderWindow?.orderOut(nil)
    }

    func showFeedbackWindow() {
        if feedbackWindow == nil {
            feedbackWindow = makeUtilityWindow(FeedbackView().environmentObject(self))
        }
        feedbackWindow?.title = L.s("feedback.windowTitle")
        feedbackWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeFeedbackWindow() {
        feedbackWindow?.orderOut(nil)
    }

    // MARK: - System events (from the AppDelegate)

    func systemDidWake() {
        calendar.refresh()
        reminderStore.prune()
        scheduler.recompute()
        updateMenuTitle()
    }

    func screensChanged() {
        overlay.rebuildIfNeeded()
    }

    func spaceChanged() {
        overlay.refront()
    }
}

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        TabView {
            GeneralSettingsTab(settings: app.settings)
                .tabItem { Label(L.s("settings.tab.general"), systemImage: "gearshape") }
            AppearanceSettingsTab(settings: app.settings)
                .tabItem { Label(L.s("settings.tab.appearance"), systemImage: "paintbrush") }
            CalendarSettingsTab(settings: app.settings, calendar: app.calendar)
                .tabItem { Label(L.s("settings.tab.calendars"), systemImage: "calendar") }
            PersonalitySettingsTab(settings: app.settings)
                .tabItem { Label(L.s("settings.tab.personality"), systemImage: "face.smiling") }
            AboutTab()
                .tabItem { Label(L.s("settings.tab.about"), systemImage: "heart") }
        }
        .frame(width: 500)
    }
}

private struct GeneralSettingsTab: View {
    @EnvironmentObject var app: AppState
    @ObservedObject var settings: AppSettings
    @State private var launchAtLogin = false

    var body: some View {
        Form {
            Section(L.s("settings.timing")) {
                ForEach(AppSettings.availableStages, id: \.self) { minutes in
                    Toggle(minutes == 1 ? L.s("settings.stage.1") : L.f("settings.stage.n", minutes), isOn: stageBinding(minutes))
                }
                Toggle(L.s("settings.followUp"), isOn: $settings.followUpEnabled)

                Picker(L.s("settings.escalation"), selection: presetBinding) {
                    Text(L.s("preset.custom")).tag(EscalationPreset?.none)
                    ForEach(EscalationPreset.allCases) { preset in
                        Text(preset.label).tag(EscalationPreset?.some(preset))
                    }
                }
                Text(L.s("settings.escalation.hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(L.s("settings.sound")) {
                Toggle(L.s("settings.sound.enable"), isOn: $settings.soundEnabled)
                Picker(L.s("settings.sound.pick"), selection: $settings.soundName) {
                    ForEach(AppSettings.availableSounds, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .disabled(!settings.soundEnabled)
                Toggle(L.s("settings.sound.nag"), isOn: $settings.nagRepeat)
                    .disabled(!settings.soundEnabled)
                Toggle(L.s("settings.speech"), isOn: $settings.speechEnabled)
                Button(L.s("settings.sound.preview")) {
                    app.sound.playOnce(name: settings.soundName)
                    if settings.speechEnabled {
                        app.speech.announce(L.f("speech.final", L.s("test.title")))
                    }
                }
                Text(L.s("settings.sound.hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(L.s("settings.guard")) {
                Toggle(L.s("settings.guard.enable"), isOn: $settings.presentationGuard)
                Text(L.s("settings.guard.hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(L.s("setup.when.title")) {
                Picker(L.s("settings.profile"), selection: $settings.alertProfile) {
                    ForEach(AlertProfile.allCases) { profile in
                        Text(profile.label).tag(profile)
                    }
                }
                if settings.alertProfile != .always {
                    DatePicker(L.s("setup.when.from"), selection: minutesBinding($settings.activeFromMinutes), displayedComponents: [.hourAndMinute])
                    DatePicker(L.s("setup.when.to"), selection: minutesBinding($settings.activeToMinutes), displayedComponents: [.hourAndMinute])
                }
                if settings.alertProfile == .days {
                    HStack(spacing: 6) {
                        ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { day in
                            weekdayToggle(day)
                        }
                    }
                }
                Text(settings.alertProfile.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(L.s("settings.quiet")) {
                Toggle(L.s("settings.quiet.enable"), isOn: $settings.quietHoursEnabled)
                if settings.quietHoursEnabled {
                    DatePicker(L.s("settings.quiet.from"), selection: minutesBinding($settings.quietStartMinutes), displayedComponents: [.hourAndMinute])
                    DatePicker(L.s("settings.quiet.to"), selection: minutesBinding($settings.quietEndMinutes), displayedComponents: [.hourAndMinute])
                }
                Text(L.s("settings.quiet.hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(L.s("settings.system")) {
                Toggle(L.s("settings.launchAtLogin"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        settings.setLaunchAtLogin(newValue)
                    }
                Picker(L.s("settings.presence"), selection: $settings.presence) {
                    ForEach(AppPresence.allCases) { presence in
                        Text(presence.label).tag(presence)
                    }
                }
                Picker(L.s("settings.language"), selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.label).tag(lang)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            launchAtLogin = settings.launchAtLogin
        }
    }

    /// Enable or disable a stage. The last remaining one stays on —
    /// a reminder app with no alarm at all would be pointless.
    private func stageBinding(_ minutes: Int) -> Binding<Bool> {
        Binding<Bool>(
            get: { settings.enabledStages.contains(minutes) },
            set: { on in
                var next = settings.enabledStages
                if on {
                    next.insert(minutes)
                } else {
                    next.remove(minutes)
                    guard !next.isEmpty else { return }
                }
                settings.enabledStages = next
            }
        )
    }

    /// Quick pick: sets the stages in one go, otherwise shows "Custom".
    private var presetBinding: Binding<EscalationPreset?> {
        Binding<EscalationPreset?>(
            get: { settings.matchingPreset },
            set: { preset in
                guard let preset else { return }
                settings.enabledStages = preset.stages
            }
        )
    }

    /// Toggle a weekday on/off — at least one must remain selected.
    private func weekdayToggle(_ day: Int) -> some View {
        let active = settings.activeWeekdays.contains(day)
        let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
        return Button {
            if active {
                var next = settings.activeWeekdays
                next.remove(day)
                if !next.isEmpty { settings.activeWeekdays = next }
            } else {
                settings.activeWeekdays.insert(day)
            }
        } label: {
            Text(symbols.indices.contains(day - 1) ? symbols[day - 1] : "?")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 30, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(active ? Theme.greenDeep.opacity(0.22) : Color.gray.opacity(0.12))
                )
                .foregroundStyle(active ? Theme.greenDeep : .secondary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? [.isSelected] : [])
    }

    /// Minutes-since-midnight ↔ Date for DatePicker.
    private func minutesBinding(_ source: Binding<Int>) -> Binding<Date> {
        Binding<Date>(
            get: {
                Calendar.current.date(
                    bySettingHour: source.wrappedValue / 60,
                    minute: source.wrappedValue % 60,
                    second: 0, of: Date()
                ) ?? Date()
            },
            set: { date in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
                source.wrappedValue = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
            }
        )
    }
}

/// Alarm appearance: eight styles, free accent color, custom logo.
private struct AppearanceSettingsTab: View {
    @EnvironmentObject var app: AppState
    @ObservedObject var settings: AppSettings
    @State private var logoError = ""

    private let columns = [GridItem(.adaptive(minimum: 108), spacing: 10)]

    var body: some View {
        Form {
            Section(L.s("settings.style")) {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(AlarmStyle.allCases) { style in
                        styleChip(style)
                    }
                }
                .padding(.vertical, 4)

                Text(settings.alarmStyle.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(L.s("settings.accent")) {
                ColorPicker(L.s("settings.accent.pick"), selection: accentBinding, supportsOpacity: false)
                Button(L.s("settings.accent.reset")) { settings.accentHex = "" }
                    .disabled(settings.accentHex.isEmpty)
                Text(L.s("settings.accent.hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(L.s("settings.logo")) {
                HStack(spacing: 12) {
                    if let logo = Theme.logoImage {
                        Image(nsImage: logo)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 96, height: 34)
                    }
                    Button(L.s("settings.logo.pick")) { pickLogo() }
                    Button(L.s("settings.logo.clear")) { clearLogo() }
                        .disabled(settings.logoFileName.isEmpty)
                }
                if !logoError.isEmpty {
                    Text(logoError)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Text(L.s("settings.logo.hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button(L.s("settings.style.preview")) { app.triggerTestAlarm() }
            }
        }
        .formStyle(.grouped)
    }

    private func styleChip(_ style: AlarmStyle) -> some View {
        let active = settings.alarmStyle == style
        return Button {
            settings.alarmStyle = style
        } label: {
            HStack(spacing: 7) {
                Circle()
                    .fill(style.swatch)
                    .frame(width: 12, height: 12)
                Text(style.label)
                    .font(.system(size: 12, weight: active ? .semibold : .regular))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(active ? style.swatch.opacity(0.16) : Color.gray.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(active ? style.swatch.opacity(0.7) : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? [.isSelected] : [])
    }

    private var accentBinding: Binding<Color> {
        Binding<Color>(
            get: { Color(hex: settings.accentHex) ?? settings.alarmStyle.swatch },
            set: { settings.accentHex = $0.hexString }
        )
    }

    /// The image is copied into the sandbox container — access to the
    /// original path would otherwise not survive a restart.
    private func pickLogo() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let source = panel.url,
              let dir = Theme.supportDirectory else { return }

        let attributes = try? FileManager.default.attributesOfItem(atPath: source.path)
        let size = (attributes?[.size] as? NSNumber)?.intValue ?? 0
        guard size <= 3 * 1024 * 1024 else {
            logoError = L.f("settings.logo.tooBig", Double(size) / 1_048_576)
            return
        }

        let target = dir.appendingPathComponent("logo." + source.pathExtension.lowercased())
        try? FileManager.default.removeItem(at: target)
        do {
            try FileManager.default.copyItem(at: source, to: target)
            logoError = ""
            settings.logoFileName = target.lastPathComponent
            Theme.logoFileName = settings.logoFileName
        } catch {
            logoError = L.s("settings.logo.failed")
        }
    }

    private func clearLogo() {
        if let dir = Theme.supportDirectory, !settings.logoFileName.isEmpty {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent(settings.logoFileName))
        }
        settings.logoFileName = ""
        Theme.logoFileName = ""
        logoError = ""
    }
}

private struct CalendarSettingsTab: View {
    @EnvironmentObject var app: AppState
    @ObservedObject var settings: AppSettings
    /// Observe directly — via `app` the permission grant would never arrive (see WelcomeView).
    @ObservedObject var calendar: CalendarService

    var body: some View {
        Form {
            if calendar.authStatus == .fullAccess {
                Section(L.s("settings.calendars.title")) {
                    ForEach(calendar.allCalendars(), id: \.calendarIdentifier) { cal in
                        Toggle(cal.title, isOn: Binding(
                            get: { !settings.excludedCalendarIDs.contains(cal.calendarIdentifier) },
                            set: { include in
                                if include {
                                    settings.excludedCalendarIDs.remove(cal.calendarIdentifier)
                                } else {
                                    settings.excludedCalendarIDs.insert(cal.calendarIdentifier)
                                }
                            }
                        ))
                    }
                }
                Section(L.s("settings.exclude")) {
                    TextField(L.s("settings.exclude.keywords"), text: $settings.excludeKeywordsRaw, prompt: Text(L.s("settings.exclude.placeholder")))
                    Text(L.s("settings.exclude.hint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section {
                    Text(L.s("settings.calendars.hint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    Text(L.s("settings.calendars.noAccess"))
                    Button(L.s("settings.calendars.allow")) {
                        app.requestCalendarAccess()
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct PersonalitySettingsTab: View {
    @EnvironmentObject var app: AppState
    @ObservedObject var settings: AppSettings
    @State private var preview = ""

    var body: some View {
        Form {
            Section(L.s("settings.personality.title")) {
                Picker(L.s("settings.personality.tone"), selection: $settings.intensity) {
                    ForEach(Intensity.allCases) { level in
                        Text(level.label).tag(level)
                    }
                }
                .pickerStyle(.segmented)

                LabeledContent(L.s("settings.personality.sample")) {
                    Text("„\(preview)“")
                        .italic()
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
                Button(L.s("settings.personality.more")) {
                    preview = app.personality.message(for: .final, intensity: settings.intensity)
                }
            }
            Section {
                Text(L.s("settings.personality.hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            if preview.isEmpty {
                preview = app.personality.message(for: .final, intensity: settings.intensity)
            }
        }
    }
}

private struct AboutTab: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)

            Text("Unforget")
                .font(.system(size: 24, weight: .heavy))
            Text(L.f("about.version", Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"))
                .font(.callout)
                .foregroundStyle(.secondary)

            Divider().padding(.horizontal, 60)

            Text(.init(L.s("about.by")))
                .font(.body)
            Text(L.s("about.claim"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Link("greenstein.design", destination: URL(string: "https://www.greenstein.design")!)
                .font(.callout.weight(.semibold))

            Button(L.s("about.feedback")) {
                AppState.shared.showFeedbackWindow()
            }
            .padding(.top, 2)

            Text(L.s("about.tagline"))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
}

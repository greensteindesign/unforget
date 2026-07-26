import SwiftUI
import EventKit

/// Setup assistant in the brand look: dark hero area (like the overlay),
/// with one step after another below. Deliberately multi-step — a single
/// packed page is the worse choice for ADHD brains.
///
/// IMPORTANT for layout: The content area has a FIXED height. Without it,
/// the window jumps in size on every step, and `NSHostingController` can
/// oscillate endlessly while negotiating the size (that's what crashed 1.0,
/// see `AppState.makeUtilityWindow`).
struct WelcomeView: View {
    @EnvironmentObject var app: AppState
    /// The authorization status lives in `CalendarService`. A nested
    /// ObservableObject does NOT notify through the outer `AppState` — anyone
    /// observing only `app` never sees the grant, and the window stays stuck
    /// on "Grant calendar access" forever.
    @ObservedObject var calendar: CalendarService
    @ObservedObject var settings: AppSettings

    @AppStorage("hasAnsweredAutostart") private var hasAnsweredAutostart = false
    @AppStorage("setupCompleted") private var setupCompleted = false

    @State private var step = 0
    @State private var launchAtLogin = false

    private let steps = 6
    private let contentHeight: CGFloat = 330

    var body: some View {
        VStack(spacing: 0) {
            hero
            content
            footer
        }
        .frame(width: 520)
        .id(app.languageTick) // re-render on language change (the window is cached)
        .onAppear { launchAtLogin = settings.launchAtLogin }
    }

    // MARK: - Steps

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch step {
            case 0: stepIntro
            case 1: stepCalendar
            case 2: stepProfile
            case 3: stepStages
            case 4: stepLook
            default: stepFinish
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: contentHeight, alignment: .top)
        .padding(.horizontal, 30)
        .padding(.top, 22)
    }

    private var stepIntro: some View {
        VStack(alignment: .leading, spacing: 14) {
            bullet(icon: "bolt.fill", text: L.s("welcome.b1"))
            bullet(icon: "face.smiling.inverse", text: L.s("welcome.b2"))
            bullet(icon: "lock.fill", text: L.s("welcome.b3"))
            Text(L.s("setup.intro.hint"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
        }
    }

    @ViewBuilder
    private var stepCalendar: some View {
        stepHead(L.s("setup.calendar.title"), L.s("setup.calendar.lead"))

        switch calendar.authStatus {
        case .fullAccess:
            Label(L.s("welcome.granted"), systemImage: "checkmark.circle.fill")
                .foregroundStyle(Theme.greenDeep)
                .font(.body.weight(.semibold))
            Button(L.s("welcome.testButton")) { app.triggerTestAlarm() }
                .buttonStyle(.borderedProminent)
                .tint(Theme.greenDeep)

        case .denied, .restricted, .writeOnly:
            Label(L.s("welcome.denied"), systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(L.s("welcome.denied.hint"))
                .font(.callout)
                .foregroundStyle(.secondary)
            Button(L.s("welcome.openSettings")) {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                    NSWorkspace.shared.open(url)
                }
            }

        default:
            Button(L.s("welcome.allow")) { app.requestCalendarAccess() }
                .buttonStyle(.borderedProminent)
                .tint(Theme.greenDeep)
                .controlSize(.large)
        }
    }

    @ViewBuilder
    private var stepProfile: some View {
        stepHead(L.s("setup.when.title"), L.s("setup.when.lead"))

        Picker("", selection: $settings.alertProfile) {
            ForEach(AlertProfile.allCases) { profile in
                Text(profile.label).tag(profile)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()

        Text(settings.alertProfile.note)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

        if settings.alertProfile != .always {
            HStack(spacing: 14) {
                DatePicker(L.s("setup.when.from"), selection: minutesBinding($settings.activeFromMinutes), displayedComponents: [.hourAndMinute])
                DatePicker(L.s("setup.when.to"), selection: minutesBinding($settings.activeToMinutes), displayedComponents: [.hourAndMinute])
            }
            .datePickerStyle(.field)
        }

        if settings.alertProfile == .days {
            HStack(spacing: 6) {
                ForEach(Self.weekdayOrder, id: \.self) { day in
                    weekdayToggle(day)
                }
            }
        }
    }

    @ViewBuilder
    private var stepStages: some View {
        stepHead(L.s("setup.stages.title"), L.s("setup.stages.lead"))

        ForEach(AppSettings.availableStages, id: \.self) { minutes in
            Toggle(minutes == 1 ? L.s("settings.stage.1") : L.f("settings.stage.n", minutes), isOn: stageBinding(minutes))
                .toggleStyle(.checkbox)
        }
        Toggle(L.s("settings.followUp"), isOn: $settings.followUpEnabled)
            .toggleStyle(.checkbox)

        Text(L.s("setup.stages.hint"))
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var stepLook: some View {
        stepHead(L.s("setup.look.title"), L.s("setup.look.lead"))

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 8)], spacing: 8) {
            ForEach(AlarmStyle.allCases) { style in
                styleChip(style)
            }
        }

        HStack(spacing: 12) {
            ColorPicker(L.s("settings.accent.pick"), selection: accentBinding, supportsOpacity: false)
                .labelsHidden()
            Text(settings.alarmStyle.note)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }

        Button(L.s("welcome.testButton")) { app.triggerTestAlarm() }
            .disabled(!calendar.hasFullAccess && calendar.authStatus != .notDetermined)
    }

    @ViewBuilder
    private var stepFinish: some View {
        stepHead(L.s("setup.done.title"), L.s("setup.done.lead"))

        Toggle(L.s("settings.launchAtLogin"), isOn: $launchAtLogin)
            .toggleStyle(.switch)
            .tint(Theme.greenDeep)
            .onChange(of: launchAtLogin) { _, value in
                settings.setLaunchAtLogin(value)
                hasAnsweredAutostart = true
            }

        Text(L.s("welcome.done"))
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

        Picker(L.s("settings.language"), selection: $settings.language) {
            ForEach(AppLanguage.allCases) { lang in
                Text(lang.label).tag(lang)
            }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: 260)
    }

    // MARK: - Footer with step indicator

    private var footer: some View {
        HStack(spacing: 10) {
            Text(L.f("setup.step", step + 1, steps))
                .font(.caption)
                .foregroundStyle(.tertiary)

            HStack(spacing: 5) {
                ForEach(0..<steps, id: \.self) { index in
                    Circle()
                        .fill(index == step ? Theme.greenDeep : Color.secondary.opacity(0.25))
                        .frame(width: 6, height: 6)
                }
            }

            Spacer()

            if step > 0 {
                Button(L.s("setup.back")) { step -= 1 }
            }

            if step < steps - 1 {
                Button(nextTitle) { step += 1 }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.greenDeep)
                    .disabled(step == 1 && calendar.authStatus == .notDetermined)
            } else {
                Button(L.s("setup.finish")) {
                    setupCompleted = true
                    app.closeWelcomeWindow()
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.greenDeep)
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 16)
        .background(.quaternary.opacity(0.35))
    }

    /// In the calendar step, the button reads "Later" as long as nothing has been decided.
    private var nextTitle: String {
        step == 1 && calendar.authStatus != .fullAccess ? L.s("setup.skip") : L.s("setup.next")
    }

    // MARK: - Building blocks

    private func stepHead(_ title: String, _ lead: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 19, weight: .bold))
            Text(lead)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func bullet(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.greenDeep)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Theme.greenDeep.opacity(0.12)))
            Text(text)
                .font(.callout)
        }
    }

    private func styleChip(_ style: AlarmStyle) -> some View {
        let active = settings.alarmStyle == style
        return Button {
            settings.alarmStyle = style
        } label: {
            HStack(spacing: 6) {
                Circle().fill(style.swatch).frame(width: 10, height: 10)
                Text(style.label)
                    .font(.system(size: 11, weight: active ? .semibold : .regular))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(active ? style.swatch.opacity(0.16) : Color.gray.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(active ? style.swatch.opacity(0.7) : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    /// Monday first — Calendar counts from Sunday (1).
    private static let weekdayOrder = [2, 3, 4, 5, 6, 7, 1]

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

    private func stageBinding(_ minutes: Int) -> Binding<Bool> {
        Binding<Bool>(
            get: { settings.enabledStages.contains(minutes) },
            set: { on in
                var next = settings.enabledStages
                if on {
                    next.insert(minutes)
                } else {
                    next.remove(minutes)
                    guard !next.isEmpty else { return } // one stage must remain
                }
                settings.enabledStages = next
            }
        )
    }

    private var accentBinding: Binding<Color> {
        Binding<Color>(
            get: { Color(hex: settings.accentHex) ?? settings.alarmStyle.swatch },
            set: { settings.accentHex = $0.hexString }
        )
    }

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

    // MARK: - Hero (dark, green glow — the brand stage)

    /// IMPORTANT: Fills (Color/Gradient) belong in `.background` — as
    /// ZStack siblings they are infinitely flexible, and `NSHostingView`
    /// then oscillates endlessly between two layouts while determining the
    /// window's minimum size ("more Update Constraints passes than views" → crash).
    private var hero: some View {
        VStack(spacing: 8) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 68, height: 68)
                .shadow(color: Theme.greenDark.opacity(0.5), radius: 24, y: 4)

            Text(L.s("welcome.title"))
                .font(.system(size: 21, weight: .heavy))
                .foregroundStyle(.white)

            Text(L.s("welcome.tagline"))
                .font(.system(size: 13, weight: .semibold))
                .kerning(0.5)
                .foregroundStyle(Theme.greenDark)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background {
            Color.black
            RadialGradient(
                colors: [Theme.greenDark.opacity(0.28), .clear],
                center: .init(x: 0.5, y: 0.0),
                startRadius: 0, endRadius: 420
            )
        }
    }
}

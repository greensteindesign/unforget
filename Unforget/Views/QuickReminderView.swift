import SwiftUI

struct QuickReminderView: View {
    @EnvironmentObject var app: AppState

    @State private var title = ""
    @State private var minutes = 30
    @State private var useCustomTime = false
    @State private var customTime = Date().addingTimeInterval(1800)
    @State private var detected: (date: Date, range: NSRange)?

    private let minuteOptions = [5, 10, 15, 20, 30, 45, 60, 90, 120]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.greenDeep)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Theme.greenDeep.opacity(0.12)))
                Text(L.s("quick.title"))
                    .font(.title3.weight(.bold))
            }

            TextField(L.s("quick.placeholder"), text: $title)
                .textFieldStyle(.roundedBorder)
                .onSubmit(save)
                .onChange(of: title) { _, newValue in
                    detected = Self.detectDate(in: newValue)
                }

            // Natural-language detection: "tomorrow 2 pm dentist", "in 20 min laundry"
            if let detected {
                Label(
                    L.f("quick.detected", detected.date.formatted(date: .abbreviated, time: .shortened)),
                    systemImage: "wand.and.stars"
                )
                .font(.callout.weight(.semibold))
                .foregroundStyle(Theme.greenDeep)
            }

            Picker("", selection: $useCustomTime) {
                Text(L.s("quick.in")).tag(false)
                Text(L.s("quick.at")).tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if useCustomTime {
                DatePicker(L.s("quick.time"), selection: $customTime, displayedComponents: [.hourAndMinute])
                    .datePickerStyle(.compact)
            } else {
                Picker("", selection: $minutes) {
                    ForEach(minuteOptions, id: \.self) { m in
                        Text(minuteLabel(m)).tag(m)
                    }
                }
                .labelsHidden()
            }

            HStack {
                Spacer()
                Button(L.s("quick.cancel")) {
                    app.closeQuickReminderWindow()
                }
                Button(L.s("quick.save")) {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.greenDeep)
                .disabled(fireDate.timeIntervalSinceNow < 30)
            }
        }
        .padding(24)
        .frame(width: 380)
    }

    private func minuteLabel(_ m: Int) -> String {
        if m < 60 { return L.f("quick.minutes", m) }
        if m == 60 { return L.s("quick.hour") }
        return L.f("quick.hours", Double(m) / 60)
    }

    /// "in 20 min/hrs" via regex (DE/EN/ES), otherwise NSDataDetector for date expressions.
    static func detectDate(in text: String) -> (date: Date, range: NSRange)? {
        let ns = text as NSString

        // "in 20 min" (DE/EN) and "en 15 minutos" / "dentro de 2 horas" (ES).
        let relPattern = #"(?i)\b(?:in|en|dentro\s+de)\s+(\d{1,3})\s*(min|minuten?|minutes?|minutos?|m\b|std|stunden?|hours?|horas?|h\b)"#
        if let regex = try? NSRegularExpression(pattern: relPattern),
           let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
           let amount = Int(ns.substring(with: match.range(at: 1))) {
            let unit = ns.substring(with: match.range(at: 2)).lowercased()
            let isHours = unit.hasPrefix("st") || unit.hasPrefix("h") || unit.hasPrefix("hor") || unit.hasPrefix("hou")
            let seconds = TimeInterval(amount * (isHours ? 3600 : 60))
            return (Date().addingTimeInterval(seconds), match.range)
        }

        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return nil }
        let matches = detector.matches(in: text, range: NSRange(location: 0, length: ns.length))
        for match in matches {
            if let date = match.date, date > Date().addingTimeInterval(30) {
                return (date, match.range)
            }
        }
        return nil
    }

    private var fireDate: Date {
        if let detected {
            return detected.date
        }
        if useCustomTime {
            var date = customTime
            if date < Date() {
                date = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
            }
            return date
        }
        return Date().addingTimeInterval(TimeInterval(minutes * 60))
    }

    private func save() {
        guard fireDate.timeIntervalSinceNow >= 30 else { return }
        let fallback = L.s("quick.fallbackTitle")
        var cleanTitle = title
        if let detected, let range = Range(detected.range, in: cleanTitle) {
            cleanTitle.removeSubrange(range) // strip the detected time expression from the title
        }
        let trimmed = cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        app.reminderStore.add(title: trimmed.isEmpty ? fallback : trimmed, fireDate: fireDate)
        title = ""
        detected = nil
        app.closeQuickReminderWindow()
        app.banner.show(
            title: L.s("banner.reminderSet.title"),
            message: L.f("banner.reminderSet", fireDate.formatted(date: .omitted, time: .shortened)),
            style: .success,
            seconds: 4
        )
    }
}

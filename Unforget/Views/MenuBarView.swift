import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        if !app.menuTitle.isEmpty {
            Text(app.menuTitle)
        } else if app.calendar.hasFullAccess {
            Text(L.s("menu.noEvents"))
        }

        if !app.calendar.hasFullAccess {
            Button(L.s("menu.setupCalendar")) {
                app.showWelcomeWindow()
            }
        }

        if !app.upcomingOccurrences.isEmpty {
            Menu(L.s("menu.upcoming")) {
                ForEach(app.upcomingOccurrences, id: \.id) { occ in
                    Button("\(occ.startDate.formatted(date: .omitted, time: .shortened))  \(occ.title)") {
                        app.previewAlarm(occ)
                    }
                }
                Divider()
                Text(L.s("menu.upcomingHint"))
            }
            Button(L.s("menu.skipNext")) {
                app.skipNext()
            }
        }

        Divider()

        Button(L.s("menu.quickReminder")) {
            app.showQuickReminderWindow()
        }
        .keyboardShortcut("n")

        Button(L.s("menu.testAlarm")) {
            app.triggerTestAlarm()
        }

        Divider()

        if let paused = app.pausedUntil, paused > Date() {
            Button(L.f("menu.resume", paused.formatted(date: .omitted, time: .shortened))) {
                app.resume()
            }
        } else {
            Menu(L.s("menu.pause")) {
                Button(L.s("menu.pause1h")) {
                    app.pause(until: Date().addingTimeInterval(3600))
                }
                Button(L.s("menu.pauseTomorrow")) {
                    var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date().addingTimeInterval(86400))
                    comps.hour = 6
                    app.pause(until: Calendar.current.date(from: comps) ?? Date().addingTimeInterval(43200))
                }
            }
        }

        Divider()

        SettingsLink {
            Text(L.s("menu.settings"))
        }
        .keyboardShortcut(",")

        Button(L.s("menu.feedback")) {
            app.showFeedbackWindow()
        }

        Button(L.s("menu.quit")) {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

import SwiftUI
import AppKit

@main
struct UnforgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var app = AppState.shared

    /// IMPORTANT: MenuBarExtra writes back into this binding on every scene
    /// update. A direct $app.menuBarInserted therefore triggers an endless
    /// objectWillChange loop (beachball). Hence: only write through on an
    /// actual change.
    private var menuBarInsertedBinding: Binding<Bool> {
        Binding(
            get: { app.menuBarInserted },
            set: { newValue in
                if app.menuBarInserted != newValue {
                    app.menuBarInserted = newValue
                }
            }
        )
    }

    var body: some Scene {
        MenuBarExtra(isInserted: menuBarInsertedBinding) {
            MenuBarView()
                .environmentObject(app)
        } label: {
            // Keep it compact: with a crowded menu bar/notch, wide items get hidden.
            if app.menuBadge.isEmpty {
                Image(systemName: "bolt.fill")
            } else {
                HStack(spacing: 3) {
                    Image(systemName: "bolt.fill")
                    Text(app.menuBadge)
                }
            }
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(app)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        let workspace = NSWorkspace.shared.notificationCenter

        workspace.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in AppState.shared.systemDidWake() }
        }

        workspace.addObserver(
            forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in AppState.shared.systemDidWake() }
        }

        workspace.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in AppState.shared.spaceChanged() }
        }

        // Daily full refresh + date jumps (midnight, time zone changes).
        NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in AppState.shared.systemDidWake() }
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in AppState.shared.screensChanged() }
        }

        NotificationCenter.default.addObserver(
            forName: .NSSystemClockDidChange, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in AppState.shared.systemDidWake() }
        }

        Task { @MainActor in
            AppState.shared.applyPresence()

            // Demo mode for store screenshots: --demo-lang=en --demo-alarm=meeting
            let args = ProcessInfo.processInfo.arguments
            if let langArg = args.first(where: { $0.hasPrefix("--demo-lang=") }) {
                let code = String(langArg.dropFirst("--demo-lang=".count))
                AppState.shared.settings.language = AppLanguage(rawValue: code) ?? .system
                L.code = AppState.shared.settings.language.effectiveCode
            }
            if let demoArg = args.first(where: { $0.hasPrefix("--demo-alarm=") }) {
                let kind = String(demoArg.dropFirst("--demo-alarm=".count))
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                AppState.shared.runDemo(kind)
                return
            }

            AppState.shared.showWelcomeWindowIfNeeded()
        }
    }

    /// Dock icon click (with presence "Dock"/"Both"): show the welcome window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            Task { @MainActor in AppState.shared.showWelcomeWindow() }
        }
        return true
    }
}

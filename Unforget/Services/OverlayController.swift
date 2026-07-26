import AppKit
import SwiftUI

/// What is currently on screen — including callbacks for the buttons.
@MainActor
final class AlarmPresentation: ObservableObject, Identifiable {
    let id = UUID()
    let occurrence: ScheduledOccurrence
    let kind: Trigger.Kind
    let message: String
    let onConfirm: () -> Void
    let onSnooze: () -> Void
    let onIgnore: () -> Void
    let onJoin: (URL) -> Void

    @Published var snoozeLabel: String

    init(occurrence: ScheduledOccurrence,
         kind: Trigger.Kind,
         message: String,
         snoozeLabel: String,
         onConfirm: @escaping () -> Void,
         onSnooze: @escaping () -> Void,
         onIgnore: @escaping () -> Void,
         onJoin: @escaping (URL) -> Void) {
        self.occurrence = occurrence
        self.kind = kind
        self.message = message
        self.snoozeLabel = snoozeLabel
        self.onConfirm = onConfirm
        self.onSnooze = onSnooze
        self.onIgnore = onIgnore
        self.onJoin = onJoin
    }
}

/// Borderless panel that is allowed to become key (for buttons + Esc).
final class OverlayPanel: NSPanel {
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Esc
            onEscape?()
        } else {
            super.keyDown(with: event)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }
}

/// Shows the fullscreen alert on ALL monitors, even above fullscreen apps.
@MainActor
final class OverlayController {
    private var panels: [OverlayPanel] = []
    private(set) var current: AlarmPresentation?

    var isShowing: Bool { current != nil }

    func present(_ presentation: AlarmPresentation) {
        dismiss()
        current = presentation

        for screen in NSScreen.screens {
            let panel = OverlayPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.hasShadow = false
            panel.onEscape = { [weak presentation] in
                presentation?.onSnooze() // Esc = an honest snooze, never a silent disappearance
            }
            panel.contentView = NSHostingView(
                rootView: AlertOverlayView(presentation: presentation)
            )
            panel.setFrame(screen.frame, display: true)
            panel.orderFrontRegardless()
            panels.append(panel)
        }

        panels.first?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }

    func dismiss() {
        for panel in panels {
            panel.orderOut(nil)
            panel.contentView = nil
        }
        panels = []
        current = nil
    }

    /// Monitor plugged in/unplugged while an alert is visible → rebuild.
    func rebuildIfNeeded() {
        guard let showing = current else { return }
        present(showing)
    }

    /// Bring back to the front after Space switches (known AppKit quirk
    /// with .canJoinAllSpaces: content can otherwise end up behind the Space).
    func refront() {
        guard !panels.isEmpty else { return }
        for panel in panels {
            panel.orderFrontRegardless()
        }
    }
}

// MARK: - Banner (pre-warnings + success toast)

@MainActor
final class BannerController {
    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?

    func show(title: String, message: String, style: BannerView.Style, seconds: TimeInterval = 20) {
        hide()

        guard let screen = NSScreen.main else { return }
        let width: CGFloat = 460
        let height: CGFloat = 92
        let rect = NSRect(
            x: screen.visibleFrame.midX - width / 2,
            y: screen.visibleFrame.maxY - height - 12,
            width: width, height: height
        )

        let p = NSPanel(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.level = .statusBar
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hidesOnDeactivate = false
        p.isReleasedWhenClosed = false
        p.hasShadow = true
        p.contentView = NSHostingView(
            rootView: BannerView(title: title, message: message, style: style) { [weak self] in
                self?.hide()
            }
        )
        p.orderFrontRegardless()
        panel = p

        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            if !Task.isCancelled {
                self?.hide()
            }
        }
    }

    func hide() {
        dismissTask?.cancel()
        dismissTask = nil
        panel?.orderOut(nil)
        panel?.contentView = nil
        panel = nil
    }
}

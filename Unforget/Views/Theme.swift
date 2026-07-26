import SwiftUI
import AppKit

/// Greenstein design system: black/white, green accent.
/// On dark backgrounds ALWAYS #44ff00 (never #3ec00f — it looks too dull there).
///
/// Beyond that, the alarm knows eight visual styles plus a free accent color and
/// a custom logo. These three values live — like `L.code` — as static
/// variables here and are mirrored from the settings by `AppState`.
/// Reason: The overlay is built by AppKit, not from the SwiftUI tree, and
/// therefore has no access to `@EnvironmentObject`.
enum Theme {
    /// Demo/screenshot mode sets 1.0 (fully opaque, nothing shining through).
    nonisolated(unsafe) static var overlayOpacity: Double = 0.94

    nonisolated(unsafe) static var style: AlarmStyle = .modern
    /// User-chosen accent color as hex (#rrggbb); empty = style default.
    nonisolated(unsafe) static var userAccentHex: String = ""
    /// Filename of the custom logo in the sandbox container; empty = none.
    nonisolated(unsafe) static var logoFileName: String = ""

    static let greenDark = Color(red: 0x44 / 255.0, green: 1.0, blue: 0.0)      // #44ff00
    static let greenLight = Color(red: 0x3e / 255.0, green: 0xc0 / 255.0, blue: 0x0f / 255.0) // #3ec00f
    static let greenDeep = Color(red: 0x2e / 255.0, green: 0x9a / 255.0, blue: 0x0b / 255.0)  // #2e9a0b

    static var tokens: StyleTokens { style.tokens }

    /// The user's own color trumps the style color.
    static var accent: Color {
        Color(hex: userAccentHex) ?? tokens.accent
    }

    static var accentDeep: Color {
        Color(hex: userAccentHex)?.opacity(0.75) ?? tokens.accentDeep
    }

    /// Directory for user-provided files (logo) in the sandbox container.
    static var supportDirectory: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else { return nil }
        let dir = base.appendingPathComponent("Unforget", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var logoImage: NSImage? {
        guard !logoFileName.isEmpty, let dir = supportDirectory else { return nil }
        let url = dir.appendingPathComponent(logoFileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return NSImage(contentsOf: url)
    }
}

/// Everything a style changes about the alarm.
struct StyleTokens {
    let accent: Color
    let accentDeep: Color
    /// Base color behind the gradient.
    let backdrop: Color
    let cardRadius: CGFloat
    let cardFill: Double
    let borderStrength: Double
    let fontDesign: Font.Design
    let titleWeight: Font.Weight
    /// Scanlines like on a CRT — terminal style only.
    let scanlines: Bool
}

extension AlarmStyle {
    var tokens: StyleTokens {
        switch self {
        case .modern:
            return StyleTokens(accent: Color(hex: "#44ff00")!, accentDeep: Color(hex: "#2e9a0b")!,
                               backdrop: .black, cardRadius: 30, cardFill: 0.045, borderStrength: 0.55,
                               fontDesign: .default, titleWeight: .black, scanlines: false)
        case .business:
            return StyleTokens(accent: Color(hex: "#8fb4ff")!, accentDeep: Color(hex: "#2f5fd0")!,
                               backdrop: Color(hex: "#060a14")!, cardRadius: 4, cardFill: 0.05, borderStrength: 0.40,
                               fontDesign: .serif, titleWeight: .bold, scanlines: false)
        case .playful:
            return StyleTokens(accent: Color(hex: "#ffd23f")!, accentDeep: Color(hex: "#d99b00")!,
                               backdrop: Color(hex: "#140f04")!, cardRadius: 40, cardFill: 0.07, borderStrength: 0.55,
                               fontDesign: .rounded, titleWeight: .black, scanlines: false)
        case .kids:
            return StyleTokens(accent: Color(hex: "#37e5ff")!, accentDeep: Color(hex: "#0aa7c4")!,
                               backdrop: Color(hex: "#02121a")!, cardRadius: 44, cardFill: 0.10, borderStrength: 0.85,
                               fontDesign: .rounded, titleWeight: .black, scanlines: false)
        case .pink:
            return StyleTokens(accent: Color(hex: "#ff6fd8")!, accentDeep: Color(hex: "#c62ba0")!,
                               backdrop: Color(hex: "#16060f")!, cardRadius: 34, cardFill: 0.07, borderStrength: 0.60,
                               fontDesign: .rounded, titleWeight: .black, scanlines: false)
        case .mono:
            return StyleTokens(accent: .white, accentDeep: Color(white: 0.62),
                               backdrop: .black, cardRadius: 0, cardFill: 0.04, borderStrength: 0.45,
                               fontDesign: .default, titleWeight: .heavy, scanlines: false)
        case .terminal:
            return StyleTokens(accent: Color(hex: "#4dff88")!, accentDeep: Color(hex: "#0f7a34")!,
                               backdrop: Color(hex: "#02100a")!, cardRadius: 2, cardFill: 0.06, borderStrength: 0.60,
                               fontDesign: .monospaced, titleWeight: .bold, scanlines: true)
        case .sunset:
            return StyleTokens(accent: Color(hex: "#ffb26b")!, accentDeep: Color(hex: "#c9702a")!,
                               backdrop: Color(hex: "#170c04")!, cardRadius: 24, cardFill: 0.06, borderStrength: 0.45,
                               fontDesign: .rounded, titleWeight: .heavy, scanlines: false)
        }
    }

    /// Color swatch for the picker in the settings.
    var swatch: Color { tokens.accent }
}

extension Color {
    /// "#rrggbb" → Color. An empty or invalid string yields nil.
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xff) / 255.0,
            green: Double((value >> 8) & 0xff) / 255.0,
            blue: Double(value & 0xff) / 255.0
        )
    }

    /// Color → "#rrggbb" (for storage in the settings).
    var hexString: String {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? .white
        let r = Int((ns.redComponent * 255).rounded())
        let g = Int((ns.greenComponent * 255).rounded())
        let b = Int((ns.blueComponent * 255).rounded())
        return String(format: "#%02x%02x%02x", r, g, b)
    }
}

/// Big accent pill — the one way forward.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let radius = Theme.tokens.cardRadius == 0 ? 0.0 : 999.0
        return configuration.label
            .font(.system(size: 19, weight: .bold, design: Theme.tokens.fontDesign))
            .foregroundStyle(.black)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Theme.accent))
            .shadow(color: Theme.accent.opacity(configuration.isPressed ? 0.1 : 0.45), radius: 18, y: 2)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

/// Quiet outline pill for the secondary path.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let radius = Theme.tokens.cardRadius == 0 ? 0.0 : 999.0
        return configuration.label
            .font(.system(size: 16, weight: .semibold, design: Theme.tokens.fontDesign))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 26)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(Color.white.opacity(configuration.isPressed ? 0.12 : 0.04))
                    )
            )
    }
}

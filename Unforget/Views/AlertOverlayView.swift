import SwiftUI

/// The fullscreen alert in a "boarding pass" look: a ticket card with a
/// countdown ring that visibly drains the remaining time (externalizing time).
/// Deliberately NOT a sober system dialog à la In Your Face.
struct AlertOverlayView: View {
    @ObservedObject var presentation: AlarmPresentation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var appeared = false
    @State private var holdingIgnore = false
    @State private var presentedAt = Date()

    private var occ: ScheduledOccurrence { presentation.occurrence }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                Spacer(minLength: 20)

                statusPill

                ticketCard
                    .padding(.top, 26)

                actionRow
                    .padding(.top, 40)

                holdToIgnore
                    .padding(.top, 26)

                Spacer(minLength: 20)

                Text(L.s("overlay.footer"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.28))
                    .padding(.bottom, 22)
            }
            .buttonStyle(.plain)
        }
        .opacity(appeared ? 1 : 0)
        .onAppear {
            presentedAt = Date()
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.easeOut(duration: 0.35)) { appeared = true }
            }
        }
    }

    // MARK: - Background: deep black with a green aurora

    private var background: some View {
        ZStack {
            Theme.tokens.backdrop.opacity(Theme.overlayOpacity)
            RadialGradient(
                colors: [Theme.accent.opacity(0.16), .clear],
                center: .init(x: 0.5, y: -0.1),
                startRadius: 0, endRadius: 900
            )
            RadialGradient(
                colors: [Theme.accentDeep.opacity(0.10), .clear],
                center: .init(x: 0.9, y: 1.1),
                startRadius: 0, endRadius: 700
            )
            // Retro terminal: fine scanlines like on a CRT.
            if Theme.tokens.scanlines {
                Canvas { context, size in
                    var y: CGFloat = 0
                    while y < size.height {
                        context.fill(
                            Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                            with: .color(.black.opacity(0.28))
                        )
                        y += 3
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Status pill with pulsing dot

    private var statusLabel: String {
        switch presentation.kind {
        case .missed: return L.s("overlay.status.missed")
        case .snoozeReturn: return L.s("overlay.status.snooze")
        default: return L.s("overlay.status.final")
        }
    }

    private var statusPill: some View {
        HStack(spacing: 10) {
            PulsingDot(reduceMotion: reduceMotion)
            Text(statusLabel)
                .font(.system(size: 13, weight: .heavy))
                .kerning(3.5)
                .foregroundStyle(Theme.accent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Theme.accent.opacity(0.08))
                .overlay(Capsule().stroke(Theme.accent.opacity(0.35), lineWidth: 1))
        )
    }

    // MARK: - Ticket

    private var ticketCard: some View {
        VStack(spacing: 0) {
            // Upper section: (logo) + quip + title + context chip
            VStack(spacing: 16) {
                if let logo = Theme.logoImage {
                    Image(nsImage: logo)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 220, maxHeight: 64)
                        .accessibilityHidden(true)
                }

                Text(presentation.message)
                    .font(.system(size: 21, weight: .medium))
                    .italic()
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)

                Text(occ.title)
                    .font(.system(size: 52, weight: Theme.tokens.titleWeight, design: Theme.tokens.fontDesign))
                    .kerning(-0.5)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.45)

                contextChip

                if let notes = occ.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 560)
                }
            }
            .padding(.horizontal, 56)
            .padding(.top, 40)
            .padding(.bottom, 30)

            NotchedDivider()

            // Lower section: countdown ring + target time
            HStack(spacing: 44) {
                CountdownRing(startDate: occ.startDate, presentedAt: presentedAt)

                VStack(alignment: .leading, spacing: 10) {
                    ticketRow(label: L.s("overlay.label.time"), value: occ.startDate.formatted(date: .omitted, time: .shortened))
                    if let url = occ.meetingURL {
                        ticketRow(label: L.s("overlay.label.place"), value: MeetingLinkParser.providerName(for: url))
                    } else if let location = occ.location, !location.isEmpty {
                        ticketRow(label: L.s("overlay.label.place"), value: String(location.prefix(28)))
                    } else {
                        ticketRow(label: L.s("overlay.label.mission"), value: L.s("overlay.mission.value"))
                    }
                }
            }
            .padding(.horizontal, 56)
            .padding(.vertical, 34)
        }
        .frame(width: 760)
        .background(
            RoundedRectangle(cornerRadius: Theme.tokens.cardRadius, style: .continuous)
                .fill(Color.white.opacity(Theme.tokens.cardFill))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.tokens.cardRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Theme.accent.opacity(Theme.tokens.borderStrength), Color.white.opacity(0.10)],
                                startPoint: .top, endPoint: .bottom
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: Theme.accent.opacity(0.18), radius: 60, y: 10)
        )
    }

    private func ticketRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .kerning(2)
                .foregroundStyle(.white.opacity(0.4))
            Text(value)
                .font(.system(size: 26, weight: .bold, design: Theme.tokens.fontDesign))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var contextChip: some View {
        if let url = occ.meetingURL {
            HStack(spacing: 7) {
                Image(systemName: "video.fill")
                Text(L.f("overlay.chip.video", MeetingLinkParser.providerName(for: url)))
            }
            .chipStyle()
        } else if let location = occ.location, !location.isEmpty {
            HStack(spacing: 7) {
                Image(systemName: "mappin.and.ellipse")
                Text(location)
                    .lineLimit(1)
            }
            .chipStyle()
        }
    }

    // MARK: - Buttons

    private var actionRow: some View {
        HStack(spacing: 16) {
            if let url = occ.meetingURL {
                Button {
                    presentation.onJoin(url)
                } label: {
                    Label(L.f("overlay.join", MeetingLinkParser.providerName(for: url)), systemImage: "video.fill")
                }
                .buttonStyle(PrimaryButtonStyle())

                Button {
                    presentation.onConfirm()
                } label: {
                    Label(confirmTitle, systemImage: "figure.walk")
                }
                .buttonStyle(SecondaryButtonStyle())
            } else {
                Button {
                    presentation.onConfirm()
                } label: {
                    Label(confirmTitle, systemImage: "figure.walk")
                }
                .buttonStyle(PrimaryButtonStyle())
            }

            Button(presentation.snoozeLabel) { presentation.onSnooze() }
                .buttonStyle(SecondaryButtonStyle())
        }
    }

    private var confirmTitle: String {
        switch presentation.kind {
        case .missed: return L.s("overlay.confirm.missed")
        default: return L.s("overlay.confirm")
        }
    }

    private var holdToIgnore: some View {
        Text(L.s("overlay.ignore"))
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white.opacity(holdingIgnore ? 0.9 : 0.4))
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .contentShape(Rectangle())
            .scaleEffect(holdingIgnore && !reduceMotion ? 1.06 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: holdingIgnore)
            .onLongPressGesture(minimumDuration: 1.4) {
                presentation.onIgnore()
            } onPressingChanged: { pressing in
                holdingIgnore = pressing
            }
            .accessibilityLabel(L.s("overlay.ignore.a11y"))
    }
}

// MARK: - Building blocks

private extension View {
    func chipStyle() -> some View {
        self
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white.opacity(0.75))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.white.opacity(0.07)))
    }
}

struct PulsingDot: View {
    let reduceMotion: Bool
    @State private var pulsing = false

    var body: some View {
        Circle()
            .fill(Theme.accent)
            .frame(width: 10, height: 10)
            .overlay(
                Circle()
                    .stroke(Theme.accent.opacity(0.5), lineWidth: 2)
                    .scaleEffect(pulsing && !reduceMotion ? 2.2 : 1)
                    .opacity(pulsing && !reduceMotion ? 0 : 0.8)
            )
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                    pulsing = true
                }
            }
    }
}

/// Boarding-pass divider: dashed, with "notches" on the left and right.
struct NotchedDivider: View {
    var body: some View {
        HStack(spacing: 0) {
            Circle().fill(Theme.tokens.backdrop).frame(width: 22, height: 22).offset(x: -11)
            Line()
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [7, 7]))
                .foregroundStyle(.white.opacity(0.18))
                .frame(height: 1.5)
            Circle().fill(Theme.tokens.backdrop).frame(width: 22, height: 22).offset(x: 11)
        }
        .frame(height: 22)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }
}

/// Countdown with a ring that drains toward the event start — time made tangible.
struct CountdownRing: View {
    let startDate: Date
    let presentedAt: Date

    private var totalWindow: TimeInterval {
        max(60, startDate.timeIntervalSince(presentedAt))
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let remaining = startDate.timeIntervalSince(context.date)
            let progress = max(0, min(1, remaining / totalWindow))
            let running = remaining < 0

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 11)

                Circle()
                    .trim(from: 0, to: running ? 1 : progress)
                    .stroke(
                        Theme.accent,
                        style: StrokeStyle(lineWidth: 11, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .opacity(running ? 0.35 : 1)
                    .animation(.linear(duration: 0.5), value: progress)

                VStack(spacing: 4) {
                    Text(formatted(remaining))
                        .font(.system(size: 54, weight: .black, design: Theme.tokens.fontDesign))
                        .monospacedDigit()
                        .foregroundStyle(running ? .white : Theme.accent)
                        .contentTransition(.numericText())
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)

                    Text(running ? L.s("overlay.running") : L.s("overlay.untilStart"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .padding(.horizontal, 18)
            }
            .frame(width: 230, height: 230)
        }
    }

    private func formatted(_ interval: TimeInterval) -> String {
        let t = Int(abs(interval).rounded())
        let h = t / 3600, m = (t % 3600) / 60, s = t % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}

/// Small banner at the top center — pre-warnings and success toasts.
struct BannerView: View {
    enum Style { case preWarn, success }

    let title: String
    let message: String
    let style: Style
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Theme.accent)
                .frame(width: 5)

            HStack(spacing: 13) {
                Image(systemName: style == .preWarn ? "clock.badge.exclamationmark" : "party.popper.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Theme.accent.opacity(0.12)))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .frame(width: 460, height: 92, alignment: .leading)
        .background(Color.black.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

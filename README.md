<div align="center">

# ⚡ Unforget

**The meeting alert you can't miss.**
Full-screen calendar reminders for macOS — built for ADHD & neurodivergent brains.

[![Platform](https://img.shields.io/badge/macOS-14%2B-black)](#build-it-yourself)
[![Price](https://img.shields.io/badge/price-free_forever-44ff00)](https://unforget-app.de)
[![Privacy](https://img.shields.io/badge/tracking-none-black)](#privacy)
[![License](https://img.shields.io/badge/license-PolyForm_Noncommercial-blue)](LICENSE.md)

[**unforget-app.de**](https://unforget-app.de) · [English](https://unforget-app.de/en/) · [Español](https://unforget-app.de/es/)

</div>

---

## Why this exists

Small notification banners often don't land with ADHD brains. You see them, think *"right after this one thing"* — and thirty minutes later the meeting has happened without you.

Unforget takes over **the entire screen, on every monitor**, right before things kick off. A countdown ring makes the remaining time physical. One click joins the meeting. And if you're already late, it says so — kindly, never with guilt.

Screenshots and a live simulator: [unforget-app.de](https://unforget-app.de).

## What it does

- ⚡ **Unmissable** — full-screen takeover on all displays, even above fullscreen apps
- 📅 **Reads your calendar** — the next 48 h via EventKit, entirely on your Mac
- 🎯 **One alert by default** — 1 minute before start; add 5/15-minute pre-warnings only if you want them
- 🔁 **Follows up** — if the meeting started and nobody reacted; snooze escalates 2 → 5 → 10 min
- 🎥 **Meeting links** — detects Zoom, Google Meet, Teams & Co. and offers one-click join
- 🤫 **Presentation guard** — while you're in a video call, further alerts stay a quiet banner
- 🌙 **Quiet hours & profiles** — evenings and weekends stay silent; your *own* reminders still ring (you asked for them on purpose)
- ✍️ **Quick reminders in natural language** — *“in 20 min take the pizza out”* just works (DE/EN/ES)
- 🗣️ **Optional speech** — reads the event title out loud
- 🎨 **8 alarm styles** + free accent color + your own logo
- 🌍 **Trilingual** — German, English, Spanish (runtime dictionary, 200+ keys per language)
- 💬 **Personality** — three tones from matter-of-fact to cheeky; jokes about the situation, never about you

## Privacy

There is nothing to configure because there is nothing to disclose:

- **No network connection.** The app never talks to a server.
- **No account, no cloud, no analytics, no tracking.**
- Calendar access stays on your Mac (sandboxed, EventKit read-only usage).
- Feedback is a plain `mailto:` — you see exactly what you send.

App Store privacy label: **“Data Not Collected.”**

## Build it yourself

```bash
brew install xcodegen
git clone https://github.com/greensteindesign/unforget.git
cd unforget
xcodegen generate
xcodebuild -project Unforget.xcodeproj -scheme Unforget -configuration Release build
```

Requires Xcode 16+ and macOS 14 (Sonoma) or newer. The Xcode project is generated from [`project.yml`](project.yml); Swift 6, SwiftUI plus targeted AppKit (`NSPanel` overlays), zero third-party dependencies.

## How it's built

| Piece | Approach |
|---|---|
| Scheduling | One precise `DispatchSourceTimer`, recomputed on change/wake/clock-jump — no polling ([`AlarmScheduler`](Unforget/Services/AlarmScheduler.swift)) |
| Overlay | Borderless `NSPanel` at screen-saver level on every screen, `.canJoinAllSpaces` ([`OverlayController`](Unforget/Services/OverlayController.swift)) |
| Calendar | EventKit, next 48 h, declined invites & keyword-excluded events filtered ([`CalendarService`](Unforget/Services/CalendarService.swift)) |
| Localization | Runtime string table, no `.lproj` gymnastics ([`Localization.swift`](Unforget/Services/Localization.swift)) |
| Design | Token-based theming, 8 styles from one table ([`Theme.swift`](Unforget/Views/Theme.swift)) |

## Dependencies & acknowledgements

**None.** Unforget uses no third-party libraries, packages, fonts or assets — nothing to attribute, no licenses to inherit. It builds exclusively on Apple system frameworks that ship with macOS:

[SwiftUI](https://developer.apple.com/documentation/swiftui) · [AppKit](https://developer.apple.com/documentation/appkit) · [Foundation](https://developer.apple.com/documentation/foundation) · [Combine](https://developer.apple.com/documentation/combine) · [EventKit](https://developer.apple.com/documentation/eventkit) · [AVFoundation](https://developer.apple.com/documentation/avfoundation) (speech) · [ServiceManagement](https://developer.apple.com/documentation/servicemanagement) (launch at login) · [UniformTypeIdentifiers](https://developer.apple.com/documentation/uniformtypeidentifiers)

The only bundled resource is the app's own icon. Alert sounds are the system sounds already on your Mac.

## Why is this repository public?

Because an app that reads your calendar should let you check what it does with it. Unforget is free, has no business model attached, and its users deserve to verify the privacy claims instead of trusting them. Read the code — that's the point.

## License

[PolyForm Noncommercial 1.0.0](LICENSE.md) — read it, build it, modify it, share it. **Just don't sell it.** Unforget is free and stays free. Name, logo and app icon are trademarks of Greenstein Designagentur.

---

<div align="center">

Built with 💚 by [**Greenstein.Design**](https://www.greenstein.design) — *Wir bauen Marken, die bleiben.*
Made by [Rene Grebenstein](https://renegrebenstein.de) · Feedback: [rene@greenstein.design](mailto:rene@greenstein.design)

</div>

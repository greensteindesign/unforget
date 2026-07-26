import Foundation
import EventKit

/// Finds video call links in an event's URL, location and notes.
enum MeetingLinkParser {

    private static let patterns: [String] = [
        #"https?://[\w.-]*zoom\.(?:us|com)/(?:j|my|s|w)/[^\s<>"')\]]+"#,
        #"https?://meet\.google\.com/[a-z0-9-]+"#,
        #"https?://teams\.(?:microsoft|live)\.com/[^\s<>"')\]]+"#,
        #"https?://[\w.-]*webex\.com/[^\s<>"')\]]+"#,
        #"https?://[\w.-]*whereby\.com/[^\s<>"')\]]+"#,
        #"https?://meet\.jit\.si/[^\s<>"')\]]+"#,
        #"https?://[\w.-]*gotomeet(?:ing)?\.com/[^\s<>"')\]]+"#,
        #"https?://[\w.-]*bluejeans\.com/[^\s<>"')\]]+"#,
        #"https?://(?:www\.)?around\.co/[^\s<>"')\]]+"#,
        #"https?://discord(?:app)?\.com/channels/[^\s<>"')\]]+"#,
        #"https?://[\w.-]*skype\.com/[^\s<>"')\]]+"#,
        #"facetime://[^\s<>"')\]]+"#,
    ]

    static func find(in event: EKEvent) -> URL? {
        var haystack = ""
        if let url = event.url?.absoluteString { haystack += url + "\n" }
        if let loc = event.location { haystack += loc + "\n" }
        if let notes = event.notes { haystack += notes }
        return find(in: haystack)
    }

    static func find(in text: String) -> URL? {
        for pattern in patterns {
            if let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let match = String(text[range])
                if let url = URL(string: match) { return url }
            }
        }
        return nil
    }

    /// Display name of the conferencing service for the "Join …" button.
    static func providerName(for url: URL) -> String {
        let host = (url.host ?? "").lowercased()
        if host.contains("zoom") { return "Zoom" }
        if host.contains("meet.google") { return "Google Meet" }
        if host.contains("teams.") { return "Teams" }
        if host.contains("webex") { return "Webex" }
        if host.contains("whereby") { return "Whereby" }
        if host.contains("jit.si") { return "Jitsi" }
        if host.contains("gotomeet") { return "GoToMeeting" }
        if host.contains("bluejeans") { return "BlueJeans" }
        if host.contains("around.co") { return "Around" }
        if host.contains("discord") { return "Discord" }
        if host.contains("skype") { return "Skype" }
        if url.scheme == "facetime" { return "FaceTime" }
        return "Meeting"
    }
}

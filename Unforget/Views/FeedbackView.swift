import SwiftUI
import AppKit

/// Feedback form: builds a prefilled email to rene@greenstein.design.
/// Deliberately backend-free — no tracking, no servers, no privacy concerns.
struct FeedbackView: View {
    @EnvironmentObject var app: AppState

    @State private var categoryIndex = 0
    @State private var text = ""

    private let categoryKeys = ["feedback.cat.idea", "feedback.cat.bug", "feedback.cat.love", "feedback.cat.other"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.greenDeep)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Theme.greenDeep.opacity(0.12)))
                Text(L.s("feedback.title"))
                    .font(.title3.weight(.bold))
            }
            Text(L.s("feedback.subtitle"))
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("", selection: $categoryIndex) {
                ForEach(categoryKeys.indices, id: \.self) { i in
                    Text(L.s(categoryKeys[i])).tag(i)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            TextEditor(text: $text)
                .font(.body)
                .frame(height: 130)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
                .overlay(
                    RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3))
                )
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(L.s("feedback.placeholder"))
                            .font(.callout)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 12)
                            .padding(.leading, 12)
                            .allowsHitTesting(false)
                    }
                }

            Text(L.s("feedback.diagnostics"))
                .font(.caption2)
                .foregroundStyle(.tertiary)

            HStack {
                Spacer()
                Button(L.s("feedback.cancel")) {
                    app.closeFeedbackWindow()
                }
                Button(L.s("feedback.send")) {
                    send()
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.greenDeep)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    private var diagnostics: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        return "Unforget \(version) · \(ProcessInfo.processInfo.operatingSystemVersionString) · \(L.code)"
    }

    private func send() {
        let subject = "[Unforget Feedback] \(L.s(categoryKeys[categoryIndex]))"
        let body = text + "\n\n—\n" + diagnostics

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "rene@greenstein.design"
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body),
        ]

        if let url = components.url, NSWorkspace.shared.open(url) {
            app.closeFeedbackWindow()
            app.banner.show(
                title: L.s("feedback.sent.title"),
                message: L.s("feedback.sent"),
                style: .success,
                seconds: 4
            )
            text = ""
        } else {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString("\(subject)\n\n\(body)\n\nAn: rene@greenstein.design", forType: .string)
            app.closeFeedbackWindow()
            app.banner.show(
                title: L.s("feedback.copied.title"),
                message: L.s("feedback.copied"),
                style: .success,
                seconds: 6
            )
            text = ""
        }
    }
}

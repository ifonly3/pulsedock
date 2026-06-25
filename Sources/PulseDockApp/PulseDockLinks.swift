import AppKit
import Foundation

enum PulseDockLinks {
    static let privacyPolicyInfoKey = "PulseDockPrivacyPolicyURL"
    static let supportInfoKey = "PulseDockSupportURL"

    static var privacyPolicyURL: URL? {
        url(forInfoKey: privacyPolicyInfoKey)
    }

    static var supportURL: URL? {
        url(forInfoKey: supportInfoKey)
    }

    @MainActor
    static func openPrivacyPolicy() {
        open(privacyPolicyURL)
    }

    @MainActor
    static func openSupport() {
        open(supportURL)
    }

    @MainActor
    static func open(_ url: URL?) {
        guard let url else {
            NSSound.beep()
            return
        }

        NSWorkspace.shared.open(url)
    }

    private static func url(forInfoKey key: String) -> URL? {
        guard
            let rawValue = Bundle.main.object(forInfoDictionaryKey: key) as? String,
            let url = URL(string: rawValue),
            let scheme = url.scheme?.lowercased(),
            scheme == "https" || scheme == "http"
        else {
            return nil
        }

        return url
    }
}

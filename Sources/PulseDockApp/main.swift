import AppKit

@MainActor
final class PulseDockApplication {
    private let app = NSApplication.shared
    private let delegate = AppDelegate()

    func run() {
        app.delegate = delegate
        app.run()
    }
}

PulseDockApplication().run()

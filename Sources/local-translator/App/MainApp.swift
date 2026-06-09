import AppKit

@main
final class MainApp: NSObject, NSApplicationDelegate {
    private var coordinator: AppCoordinator?

    static func main() {
        let app = NSApplication.shared
        let delegate = MainApp()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        coordinator = AppCoordinator()
        coordinator?.start()
    }
}

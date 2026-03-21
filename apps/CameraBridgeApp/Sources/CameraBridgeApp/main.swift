import AppKit
import Foundation

@main
struct CameraBridgeAppMain {
    static func main() {
        let application = NSApplication.shared
        let delegate = CameraBridgeStatusBarDelegate()
        application.setActivationPolicy(.accessory)
        application.delegate = delegate
        application.run()
    }
}

final class CameraBridgeStatusBarDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "CameraBridge"
        statusItem.menu = makeMenu()
        self.statusItem = statusItem
    }

    @objc
    private func quitApplication(_ sender: Any?) {
        NSApp.terminate(sender)
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let shellItem = NSMenuItem(
            title: "CameraBridge menu bar shell",
            action: nil,
            keyEquivalent: ""
        )
        shellItem.isEnabled = false
        menu.addItem(shellItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit CameraBridge",
            action: #selector(quitApplication(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }
}

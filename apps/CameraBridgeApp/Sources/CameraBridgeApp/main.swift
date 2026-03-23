import AppKit
import Carbon

let application = NSApplication.shared
let delegate = MainActor.assumeIsolated {
    let delegate = CameraBridgeStatusBarDelegate()
    delegate.registerDeepLinkHandler()
    return delegate
}
application.setActivationPolicy(.accessory)
application.delegate = delegate
application.run()

@MainActor
final class CameraBridgeStatusBarDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, CameraBridgeAppStatusPresenting, CameraBridgeAppStatusMenuDriving {
    private let model: CameraBridgeAppModel
    private let statusMenu: NSMenu
    private lazy var statusMenuPresenter = CameraBridgeAppStatusMenuPresenter(driver: self)
    private lazy var deepLinkRouter = CameraBridgeAppDeepLinkRouter(
        statusRefresher: model,
        statusPresenter: self,
        logger: { message in
            print(message)
        }
    )
    private var statusItem: NSStatusItem?
    private var terminationRequested = false

    override init() {
        self.model = CameraBridgeAppModel()
        self.statusMenu = NSMenu()
        super.init()
        statusMenu.delegate = self
    }

    func registerDeepLinkHandler() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "CameraBridge"
        statusItem.menu = statusMenu
        self.statusItem = statusItem

        model.onChange = { [weak self] in
            self?.reloadMenu()
        }

        reloadMenu()
        model.start()
        statusMenuPresenter.statusMenuPresentationDidBecomeAvailable()
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !terminationRequested else {
            return .terminateNow
        }

        terminationRequested = true
        Task { @MainActor in
            await model.prepareForTermination()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    @objc
    private func startService(_ sender: Any?) {
        model.startService()
    }

    @objc
    private func stopService(_ sender: Any?) {
        model.stopService()
    }

    @objc
    private func requestCameraAccess(_ sender: Any?) {
        model.requestCameraAccess()
    }

    @objc
    private func quitApplication(_ sender: Any?) {
        NSApp.terminate(sender)
    }

    func menuWillOpen(_ menu: NSMenu) {
        guard menu === statusMenu else {
            return
        }

        statusMenuPresenter.statusMenuWillOpen()
    }

    func menuDidClose(_ menu: NSMenu) {
        guard menu === statusMenu else {
            return
        }

        statusMenuPresenter.statusMenuDidClose()
    }

    func presentStatusMenuForDeepLink() {
        reloadMenu()
        statusMenuPresenter.presentStatusMenu()
    }

    var canPresentStatusMenu: Bool {
        statusItem?.button != nil
    }

    func activateAppForStatusMenu() {
        NSApp.activate(ignoringOtherApps: true)
    }

    func openStatusMenu() {
        statusItem?.button?.performClick(nil)
    }

    @objc
    private func handleGetURLEvent(
        _ event: NSAppleEventDescriptor,
        withReplyEvent replyEvent: NSAppleEventDescriptor
    ) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue else {
            return
        }

        Task { @MainActor in
            _ = await deepLinkRouter.handle(urlString)
        }
    }

    private func reloadMenu() {
        statusMenu.removeAllItems()
        populateMenu(statusMenu)
    }

    private func populateMenu(_ menu: NSMenu) {
        menu.addItem(disabledItem(title: "CameraBridge"))
        menu.addItem(disabledItem(title: model.statusSummaryTitle))
        menu.addItem(.separator())

        menu.addItem(disabledItem(title: "Service: \(model.serviceStatusTitle)"))
        menu.addItem(disabledItem(title: "Permission: \(model.permissionStatusTitle)"))
        menu.addItem(disabledItem(title: model.guidanceMessage))

        if let lastError = model.lastErrorMessage {
            menu.addItem(.separator())
            menu.addItem(disabledItem(title: "Last error: \(lastError)"))
        }

        menu.addItem(.separator())

        let startServiceItem = NSMenuItem(
            title: "Start CameraBridge Service",
            action: #selector(startService(_:)),
            keyEquivalent: ""
        )
        startServiceItem.target = self
        startServiceItem.isEnabled = model.canStartService
        menu.addItem(startServiceItem)

        let stopServiceItem = NSMenuItem(
            title: "Stop CameraBridge Service",
            action: #selector(stopService(_:)),
            keyEquivalent: ""
        )
        stopServiceItem.target = self
        stopServiceItem.isEnabled = model.canStopService
        menu.addItem(stopServiceItem)

        let requestPermissionItem = NSMenuItem(
            title: "Request Camera Access",
            action: #selector(requestCameraAccess(_:)),
            keyEquivalent: ""
        )
        requestPermissionItem.target = self
        requestPermissionItem.isEnabled = model.canRequestCameraAccess
        menu.addItem(requestPermissionItem)

        menu.addItem(.separator())
        menu.addItem(disabledItem(title: "Base URL: \(model.developerBaseURL)"))
        menu.addItem(disabledItem(title: "Token: \(model.developerTokenPath)"))
        menu.addItem(disabledItem(title: "Log: \(model.developerLogPath)"))
        menu.addItem(disabledItem(title: "Captures: \(model.developerCapturesPath)"))

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit CameraBridge",
            action: #selector(quitApplication(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func disabledItem(title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }
}

import Foundation

@MainActor
protocol CameraBridgeAppStatusRefreshing {
    func refreshNow() async
}

extension CameraBridgeAppModel: CameraBridgeAppStatusRefreshing {}

@MainActor
protocol CameraBridgeAppStatusPresenting {
    func presentStatusMenuForDeepLink()
}

@MainActor
protocol CameraBridgeAppStatusMenuDriving {
    var canPresentStatusMenu: Bool { get }

    func activateAppForStatusMenu()
    func openStatusMenu()
}

@MainActor
final class CameraBridgeAppStatusMenuPresenter {
    private let driver: any CameraBridgeAppStatusMenuDriving
    private var isStatusMenuOpen = false
    private var pendingPresentation = false

    init(driver: any CameraBridgeAppStatusMenuDriving) {
        self.driver = driver
    }

    func presentStatusMenu() {
        driver.activateAppForStatusMenu()

        guard driver.canPresentStatusMenu else {
            pendingPresentation = true
            return
        }

        pendingPresentation = false

        guard !isStatusMenuOpen else {
            return
        }

        driver.openStatusMenu()
    }

    func statusMenuWillOpen() {
        isStatusMenuOpen = true
    }

    func statusMenuDidClose() {
        isStatusMenuOpen = false
    }

    func statusMenuPresentationDidBecomeAvailable() {
        guard pendingPresentation else {
            return
        }

        presentStatusMenu()
    }
}

enum CameraBridgeAppDeepLink: Equatable {
    case permission

    init?(url: URL) {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        components.scheme = components.scheme?.lowercased()
        components.host = components.host?.lowercased()

        guard components.scheme == "camerabridge" else {
            return nil
        }

        guard components.host == "permission" else {
            return nil
        }

        guard components.user == nil, components.password == nil, components.port == nil else {
            return nil
        }

        guard components.path.isEmpty else {
            return nil
        }

        guard components.query == nil, components.fragment == nil else {
            return nil
        }

        self = .permission
    }

    init?(string: String) {
        guard let url = URL(string: string) else {
            return nil
        }

        self.init(url: url)
    }
}

@MainActor
final class CameraBridgeAppDeepLinkRouter {
    typealias Logger = @Sendable (String) -> Void

    private let statusRefresher: any CameraBridgeAppStatusRefreshing
    private let statusPresenter: any CameraBridgeAppStatusPresenting
    private let logger: Logger

    init(
        statusRefresher: any CameraBridgeAppStatusRefreshing,
        statusPresenter: any CameraBridgeAppStatusPresenting,
        logger: @escaping Logger = { _ in }
    ) {
        self.statusRefresher = statusRefresher
        self.statusPresenter = statusPresenter
        self.logger = logger
    }

    @discardableResult
    func handle(_ urlString: String) async -> Bool {
        guard let deepLink = CameraBridgeAppDeepLink(string: urlString) else {
            logger("CameraBridgeApp ignored unsupported URL: \(urlString)")
            return false
        }

        return await handle(deepLink)
    }

    @discardableResult
    func handle(_ url: URL) async -> Bool {
        guard let deepLink = CameraBridgeAppDeepLink(url: url) else {
            logger("CameraBridgeApp ignored unsupported URL: \(url.absoluteString)")
            return false
        }

        return await handle(deepLink)
    }

    @discardableResult
    private func handle(_ deepLink: CameraBridgeAppDeepLink) async -> Bool {
        switch deepLink {
        case .permission:
            await statusRefresher.refreshNow()
            statusPresenter.presentStatusMenuForDeepLink()
            return true
        }
    }
}

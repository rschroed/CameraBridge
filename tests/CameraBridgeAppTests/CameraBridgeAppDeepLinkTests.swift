import Foundation
import CameraBridgeClientSwift
import CameraBridgeSupport
import Testing
@testable import CameraBridgeApp

@Test
func deepLinkParserAcceptsTheCanonicalPermissionURL() {
    #expect(CameraBridgeAppDeepLink(string: "camerabridge://permission") == .permission)
}

@Test
func deepLinkParserRejectsUnsupportedAndMalformedInputs() {
    #expect(CameraBridgeAppDeepLink(string: "camera-bridge://permission") == nil)
    #expect(CameraBridgeAppDeepLink(string: "camerabridge://open") == nil)
    #expect(CameraBridgeAppDeepLink(string: "camerabridge://permission/status") == nil)
    #expect(CameraBridgeAppDeepLink(string: "camerabridge://permission?prompt=true") == nil)
    #expect(CameraBridgeAppDeepLink(string: "://permission") == nil)
}

@Test
@MainActor
func supportedDeepLinkRefreshesStateAndPreservesExplicitActionBoundaries() async {
    let client = DeepLinkTestCameraBridgeAppClient()
    await client.setServiceIsRunning(false)
    let permissionController = DeepLinkTestPermissionController(currentStatus: .notDetermined)
    let serviceController = DeepLinkTestServiceController(state: .stopped)
    let model = CameraBridgeAppModel(
        client: client,
        runtimeConfigurationStore: DeepLinkTestRuntimeConfigurationStore(configuration: .init(host: "127.0.0.1", port: 9100)),
        runtimeInfoStore: DeepLinkTestRuntimeInfoStore(runtimeInfo: nil),
        permissionController: permissionController,
        serviceController: serviceController
    )
    let presenter = FakeStatusPresenter()
    let router = CameraBridgeAppDeepLinkRouter(statusRefresher: model, statusPresenter: presenter)

    let handled = await router.handle("camerabridge://permission")

    #expect(handled)
    #expect(model.statusSummaryTitle == "Local service is stopped")
    #expect(model.permissionStatusTitle == "Not Determined")
    #expect(presenter.presentCount == 1)
    #expect(serviceController.startCount == 0)
    #expect(serviceController.stopCount == 0)
    #expect(permissionController.requestCount == 0)
}

@Test
@MainActor
func unsupportedDeepLinkIsIgnoredWithoutPresentation() async {
    let refresher = FakeStatusRefresher()
    let presenter = FakeStatusPresenter()
    let router = CameraBridgeAppDeepLinkRouter(statusRefresher: refresher, statusPresenter: presenter)

    let handled = await router.handle("camerabridge://open")

    #expect(!handled)
    #expect(refresher.refreshCount == 0)
    #expect(presenter.presentCount == 0)
}

@Test
@MainActor
func menuPresenterQueuesColdLaunchPresentationUntilStatusItemExists() {
    let driver = FakeStatusMenuDriver(canPresentStatusMenu: false)
    let presenter = CameraBridgeAppStatusMenuPresenter(driver: driver)

    presenter.presentStatusMenu()

    #expect(driver.activateCount == 1)
    #expect(driver.openCount == 0)

    driver.canPresentStatusMenu = true
    presenter.statusMenuPresentationDidBecomeAvailable()

    #expect(driver.activateCount == 2)
    #expect(driver.openCount == 1)
}

@Test
@MainActor
func menuPresenterDoesNotToggleTheMenuClosedOnRepeatedOpens() {
    let driver = FakeStatusMenuDriver(canPresentStatusMenu: true)
    let presenter = CameraBridgeAppStatusMenuPresenter(driver: driver)

    presenter.presentStatusMenu()
    presenter.statusMenuWillOpen()
    presenter.presentStatusMenu()

    #expect(driver.activateCount == 2)
    #expect(driver.openCount == 1)

    presenter.statusMenuDidClose()
    presenter.presentStatusMenu()

    #expect(driver.openCount == 2)
}

@MainActor
private final class FakeStatusPresenter: CameraBridgeAppStatusPresenting {
    private(set) var presentCount = 0

    func presentStatusMenuForDeepLink() {
        presentCount += 1
    }
}

@MainActor
private final class FakeStatusRefresher: CameraBridgeAppStatusRefreshing {
    private(set) var refreshCount = 0

    func refreshNow() async {
        refreshCount += 1
    }
}

@MainActor
private final class FakeStatusMenuDriver: CameraBridgeAppStatusMenuDriving {
    var canPresentStatusMenu: Bool
    private(set) var activateCount = 0
    private(set) var openCount = 0

    init(canPresentStatusMenu: Bool) {
        self.canPresentStatusMenu = canPresentStatusMenu
    }

    func activateAppForStatusMenu() {
        activateCount += 1
    }

    func openStatusMenu() {
        openCount += 1
    }
}

private actor DeepLinkTestCameraBridgeAppClient: CameraBridgeAppClient {
    private var isRunning = false

    func setServiceIsRunning(_ value: Bool) {
        isRunning = value
    }

    func serviceIsRunning() async -> Bool {
        isRunning
    }
}

private struct DeepLinkTestRuntimeConfigurationStore: CameraBridgeRuntimeConfigurationReading {
    var configuration: CameraBridgeRuntimeConfiguration

    func loadConfiguration() throws -> CameraBridgeRuntimeConfiguration {
        configuration
    }
}

private struct DeepLinkTestRuntimeInfoStore: CameraBridgeRuntimeInfoReading {
    let runtimeInfo: CameraBridgeRuntimeInfo?

    func loadRuntimeInfo() throws -> CameraBridgeRuntimeInfo? {
        runtimeInfo
    }
}

@MainActor
private final class DeepLinkTestPermissionController: CameraBridgeAppPermissionControlling {
    private(set) var requestCount = 0
    var currentStatus: CameraBridgePermissionStatus

    init(currentStatus: CameraBridgePermissionStatus) {
        self.currentStatus = currentStatus
    }

    func currentPermissionStatus() -> CameraBridgePermissionStatus {
        currentStatus
    }

    func requestPermission() async -> CameraBridgePermissionRequestResult {
        requestCount += 1
        return .init(status: currentStatus, prompted: false)
    }
}

@MainActor
private final class DeepLinkTestServiceController: CameraBridgeServiceControlling {
    var state: CameraBridgeManagedServiceState
    private(set) var startCount = 0
    private(set) var stopCount = 0

    init(state: CameraBridgeManagedServiceState) {
        self.state = state
    }

    func startIfNeeded() async throws {
        startCount += 1
    }

    func stopIfManaged() async throws {
        stopCount += 1
    }

    func currentManagementState() async -> CameraBridgeManagedServiceState {
        state
    }
}

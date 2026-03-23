import CameraBridgeClientSwift
import CameraBridgeSupport
import Foundation
import Testing
@testable import CameraBridgeApp

@Test
@MainActor
func stoppedServiceStateShowsLocalPermissionGuidanceAndDeveloperInfo() async {
    let client = FakeCameraBridgeAppClient()
    await client.setServiceIsRunning(false)
    let permissionController = FakeCameraBridgeAppPermissionController(currentStatus: .notDetermined)
    let configurationStore = FakeRuntimeConfigurationStore(
        configuration: .init(host: "127.0.0.1", port: 9100)
    )
    let runtimeInfoStore = FakeRuntimeInfoStore(runtimeInfo: nil)
    let model = CameraBridgeAppModel(
        client: client,
        runtimeConfigurationStore: configurationStore,
        runtimeInfoStore: runtimeInfoStore,
        permissionController: permissionController,
        serviceController: FakeServiceController()
    )

    await model.refreshNow()

    #expect(model.statusSummaryTitle == "Local service is stopped")
    #expect(model.serviceStatusTitle == "Stopped")
    #expect(model.permissionStatusTitle == "Not Determined")
    #expect(
        model.guidanceMessage ==
        "Request camera access from CameraBridge, then start the local service to finish onboarding."
    )
    #expect(model.canStartService)
    #expect(!model.canStopService)
    #expect(model.canRequestCameraAccess)
    #expect(model.developerBaseURL == "http://127.0.0.1:9100")
}

@Test
@MainActor
func runningManagedServiceShowsReadyStateAndAllowsStop() async {
    let client = FakeCameraBridgeAppClient()
    await client.setServiceIsRunning(true)
    let permissionController = FakeCameraBridgeAppPermissionController(currentStatus: .authorized)
    let runtimeInfoStore = FakeRuntimeInfoStore(
        runtimeInfo: .init(
            pid: 42,
            host: "127.0.0.1",
            port: 9101,
            tokenFileURL: URL(fileURLWithPath: "/tmp/auth-token"),
            logFileURL: URL(fileURLWithPath: "/tmp/camd.log"),
            capturesDirectoryURL: URL(fileURLWithPath: "/tmp/Captures", isDirectory: true),
            ownership: .appManaged
        )
    )
    let serviceController = FakeServiceController(state: .runningManaged)
    let model = CameraBridgeAppModel(
        client: client,
        runtimeConfigurationStore: FakeRuntimeConfigurationStore(configuration: .init(host: "127.0.0.1", port: 9101)),
        runtimeInfoStore: runtimeInfoStore,
        permissionController: permissionController,
        serviceController: serviceController
    )

    await model.refreshNow()

    #expect(model.serviceStatusTitle == "Running")
    #expect(model.statusSummaryTitle == "CameraBridge is ready")
    #expect(model.guidanceMessage == "The managed CameraBridge service is running and camera access is available.")
    #expect(!model.canStartService)
    #expect(model.canStopService)
    #expect(model.developerBaseURL == "http://127.0.0.1:9101")
    #expect(model.developerTokenPath == "/tmp/auth-token")
}

@Test
@MainActor
func runningExternalServiceShowsExternalStateAndDisablesStop() async {
    let client = FakeCameraBridgeAppClient()
    await client.setServiceIsRunning(true)
    let permissionController = FakeCameraBridgeAppPermissionController(currentStatus: .authorized)
    let serviceController = FakeServiceController(state: .runningExternal)
    let model = CameraBridgeAppModel(
        client: client,
        runtimeConfigurationStore: FakeRuntimeConfigurationStore(configuration: .init(host: "127.0.0.1", port: 8731)),
        runtimeInfoStore: FakeRuntimeInfoStore(runtimeInfo: nil),
        permissionController: permissionController,
        serviceController: serviceController
    )

    await model.refreshNow()

    #expect(model.serviceStatusTitle == "Running (External)")
    #expect(model.statusSummaryTitle == "External CameraBridge service detected")
    #expect(!model.canStartService)
    #expect(!model.canStopService)
    #expect(
        model.guidanceMessage ==
        "A local CameraBridge service is already running outside this app and camera access is available."
    )
}

@Test
@MainActor
func startServiceDisablesActionWhileLaunchIsInFlight() async {
    let client = FakeCameraBridgeAppClient()
    await client.setServiceIsRunning(false)
    let permissionController = FakeCameraBridgeAppPermissionController(currentStatus: .authorized)
    let controller = FakeServiceController()
    let model = CameraBridgeAppModel(
        client: client,
        runtimeConfigurationStore: FakeRuntimeConfigurationStore(configuration: .init()),
        runtimeInfoStore: FakeRuntimeInfoStore(runtimeInfo: nil),
        permissionController: permissionController,
        serviceController: controller
    )

    let task = Task {
        await model.startServiceNow()
    }
    await Task.yield()

    #expect(model.serviceStatusTitle == "Starting")
    #expect(model.statusSummaryTitle == "CameraBridge is starting")
    #expect(!model.canStartService)

    await client.setServiceIsRunning(true)
    controller.state = .runningManaged
    controller.finishStart()
    await task.value

    #expect(model.serviceStatusTitle == "Running")
    #expect(model.canStopService)
}

@Test
@MainActor
func stopServiceTransitionsThroughStoppingAndStopsManagedService() async {
    let client = FakeCameraBridgeAppClient()
    await client.setServiceIsRunning(true)
    let permissionController = FakeCameraBridgeAppPermissionController(currentStatus: .authorized)
    let controller = FakeServiceController(state: .runningManaged)
    let model = CameraBridgeAppModel(
        client: client,
        runtimeConfigurationStore: FakeRuntimeConfigurationStore(configuration: .init()),
        runtimeInfoStore: FakeRuntimeInfoStore(runtimeInfo: nil),
        permissionController: permissionController,
        serviceController: controller
    )

    await model.refreshNow()
    let task = Task {
        await model.stopServiceNow()
    }
    await Task.yield()

    #expect(model.serviceStatusTitle == "Stopping")
    #expect(model.statusSummaryTitle == "CameraBridge is stopping")

    await client.setServiceIsRunning(false)
    controller.state = .stopped
    controller.finishStop()
    await task.value

    #expect(model.serviceStatusTitle == "Stopped")
    #expect(model.canStartService)
    #expect(!model.canStopService)
}

@Test
@MainActor
func permissionRequestDisablesActionWhilePromptIsInFlightAndSyncsAuthorizedState() async {
    let client = FakeCameraBridgeAppClient()
    await client.setServiceIsRunning(true)
    let permissionController = FakeCameraBridgeAppPermissionController(currentStatus: .notDetermined)
    let model = CameraBridgeAppModel(
        client: client,
        runtimeConfigurationStore: FakeRuntimeConfigurationStore(configuration: .init()),
        runtimeInfoStore: FakeRuntimeInfoStore(runtimeInfo: nil),
        permissionController: permissionController,
        serviceController: FakeServiceController(state: .runningManaged)
    )

    await model.refreshNow()
    let task = Task {
        await model.requestCameraAccessNow()
    }
    await Task.yield()

    #expect(model.permissionStatusTitle == "Requesting Access")
    #expect(model.statusSummaryTitle == "Waiting for camera access")
    #expect(!model.canRequestCameraAccess)

    permissionController.finishRequest(with: .init(status: .authorized, prompted: true))
    await task.value

    #expect(model.permissionStatusTitle == "Authorized")
    #expect(model.statusSummaryTitle == "CameraBridge is ready")
    #expect(model.guidanceMessage == "The managed CameraBridge service is running and camera access is available.")
    #expect(permissionController.requestCount == 1)
}

private actor FakeCameraBridgeAppClient: CameraBridgeAppClient {
    private var isRunning = false

    func setServiceIsRunning(_ value: Bool) {
        isRunning = value
    }

    func serviceIsRunning() async -> Bool {
        isRunning
    }
}

private struct FakeRuntimeConfigurationStore: CameraBridgeRuntimeConfigurationReading {
    var configuration: CameraBridgeRuntimeConfiguration

    func loadConfiguration() throws -> CameraBridgeRuntimeConfiguration {
        configuration
    }
}

private struct FakeRuntimeInfoStore: CameraBridgeRuntimeInfoReading {
    var runtimeInfo: CameraBridgeRuntimeInfo?

    func loadRuntimeInfo() throws -> CameraBridgeRuntimeInfo? {
        runtimeInfo
    }
}

@MainActor
private final class FakeCameraBridgeAppPermissionController: CameraBridgeAppPermissionControlling {
    private(set) var requestCount = 0
    private var requestResult: CameraBridgePermissionRequestResult?
    var currentStatus: CameraBridgePermissionStatus

    init(currentStatus: CameraBridgePermissionStatus) {
        self.currentStatus = currentStatus
    }

    func currentPermissionStatus() -> CameraBridgePermissionStatus {
        currentStatus
    }

    func requestPermission() async -> CameraBridgePermissionRequestResult {
        requestCount += 1

        while requestResult == nil {
            await Task.yield()
        }

        let result = requestResult!
        currentStatus = result.status
        requestResult = nil
        return result
    }

    func finishRequest(with result: CameraBridgePermissionRequestResult) {
        requestResult = result
        currentStatus = result.status
    }
}

@MainActor
private final class FakeServiceController: CameraBridgeServiceControlling {
    var state: CameraBridgeManagedServiceState
    var startError: Error?
    var stopError: Error?
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private var startContinuation: CheckedContinuation<Void, Never>?
    private var stopContinuation: CheckedContinuation<Void, Never>?

    init(state: CameraBridgeManagedServiceState = .stopped) {
        self.state = state
    }

    func startIfNeeded() async throws {
        startCount += 1

        if let startError {
            throw startError
        }

        await withCheckedContinuation { continuation in
            startContinuation = continuation
        }
    }

    func stopIfManaged() async throws {
        stopCount += 1

        if let stopError {
            throw stopError
        }

        await withCheckedContinuation { continuation in
            stopContinuation = continuation
        }
    }

    func currentManagementState() async -> CameraBridgeManagedServiceState {
        state
    }

    func finishStart() {
        startContinuation?.resume()
        startContinuation = nil
    }

    func finishStop() {
        stopContinuation?.resume()
        stopContinuation = nil
    }
}

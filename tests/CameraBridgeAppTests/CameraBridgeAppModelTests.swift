import CameraBridgeClientSwift
import Foundation
import Testing
@testable import CameraBridgeApp

@Test
@MainActor
func stoppedServiceStateShowsLocalPermissionGuidance() async {
    let client = FakeCameraBridgeAppClient()
    await client.setServiceIsRunning(false)
    let permissionController = FakeCameraBridgeAppPermissionController(currentStatus: .notDetermined)
    let model = CameraBridgeAppModel(
        client: client,
        permissionController: permissionController,
        serviceLauncher: FakeServiceLauncher()
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
    #expect(model.canRequestCameraAccess)
    #expect(model.lastErrorMessage == nil)
}

@Test(arguments: [
    (
        CameraBridgePermissionStatus.notDetermined,
        "Camera access setup is incomplete",
        "Request camera access from CameraBridge to continue."
    ),
    (
        CameraBridgePermissionStatus.restricted,
        "Camera access is unavailable",
        "Camera access is restricted on this Mac and cannot be granted from CameraBridge."
    ),
    (
        CameraBridgePermissionStatus.denied,
        "Camera access is unavailable",
        "Camera access was denied. Re-enable it in System Settings > Privacy & Security > Camera."
    ),
    (
        CameraBridgePermissionStatus.authorized,
        "CameraBridge is ready",
        "The service is running and camera access is available."
    ),
])
@MainActor
func runningServiceShowsAppLocalPermissionGuidance(
    permissionStatus: CameraBridgePermissionStatus,
    expectedSummary: String,
    expectedGuidance: String
) async {
    let client = FakeCameraBridgeAppClient()
    await client.setServiceIsRunning(true)
    let permissionController = FakeCameraBridgeAppPermissionController(currentStatus: permissionStatus)
    let model = CameraBridgeAppModel(
        client: client,
        permissionController: permissionController,
        serviceLauncher: FakeServiceLauncher()
    )

    await model.refreshNow()

    #expect(model.serviceStatusTitle == "Running")
    #expect(model.permissionStatusTitle == permissionStatusTitle(permissionStatus))
    #expect(model.statusSummaryTitle == expectedSummary)
    #expect(model.guidanceMessage == expectedGuidance)
}

@Test
@MainActor
func startServiceFailurePreservesLocalPermissionState() async {
    let client = FakeCameraBridgeAppClient()
    await client.setServiceIsRunning(false)
    let permissionController = FakeCameraBridgeAppPermissionController(currentStatus: .notDetermined)
    let launcher = FakeServiceLauncher()
    launcher.error = CameraBridgeServiceLaunchError.failedToStartService
    let model = CameraBridgeAppModel(
        client: client,
        permissionController: permissionController,
        serviceLauncher: launcher
    )

    await model.startServiceNow()

    #expect(model.serviceStatusTitle == "Needs Attention")
    #expect(model.permissionStatusTitle == "Not Determined")
    #expect(
        model.guidanceMessage ==
        "Request camera access from CameraBridge, then start the local service to finish onboarding."
    )
    #expect(model.lastErrorMessage == "Service did not become healthy after launch")
    #expect(model.canStartService)
}

@Test
@MainActor
func startServiceDisablesActionWhileLaunchIsInFlight() async {
    let client = FakeCameraBridgeAppClient()
    await client.setServiceIsRunning(false)
    let permissionController = FakeCameraBridgeAppPermissionController(currentStatus: .authorized)
    let launcher = FakeServiceLauncher()
    let model = CameraBridgeAppModel(
        client: client,
        permissionController: permissionController,
        serviceLauncher: launcher
    )

    let task = Task {
        await model.startServiceNow()
    }
    await Task.yield()

    #expect(model.serviceStatusTitle == "Starting")
    #expect(model.statusSummaryTitle == "CameraBridge is starting")
    #expect(!model.canStartService)

    await client.setServiceIsRunning(true)
    launcher.finish()
    await task.value

    #expect(model.serviceStatusTitle == "Running")
    #expect(!model.canRequestCameraAccess)
}

@Test
@MainActor
func permissionRequestDisablesActionWhilePromptIsInFlightAndSyncsAuthorizedState() async {
    let client = FakeCameraBridgeAppClient()
    await client.setServiceIsRunning(true)
    let permissionController = FakeCameraBridgeAppPermissionController(currentStatus: .notDetermined)
    let model = CameraBridgeAppModel(
        client: client,
        permissionController: permissionController,
        serviceLauncher: FakeServiceLauncher()
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
    #expect(model.guidanceMessage == "The service is running and camera access is available.")
    #expect(model.lastErrorMessage == nil)
    #expect(permissionController.requestCount == 1)
    #expect(!model.canRequestCameraAccess)
}

private func permissionStatusTitle(_ status: CameraBridgePermissionStatus) -> String {
    switch status {
    case .notDetermined:
        return "Not Determined"
    case .restricted:
        return "Restricted"
    case .denied:
        return "Denied"
    case .authorized:
        return "Authorized"
    }
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
private final class FakeServiceLauncher: CameraBridgeServiceLaunching {
    var error: Error?
    private var continuation: CheckedContinuation<Void, Never>?

    func startIfNeeded() async throws {
        if let error {
            throw error
        }

        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func finish() {
        continuation?.resume()
        continuation = nil
    }
}

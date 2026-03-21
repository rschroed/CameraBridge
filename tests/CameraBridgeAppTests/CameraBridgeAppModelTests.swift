import CameraBridgeClientSwift
import Foundation
import Testing
@testable import CameraBridgeApp

@Test
@MainActor
func stoppedServiceStateShowsStartGuidance() async {
    let client = FakeCameraBridgeAppClient()
    await client.setServiceIsRunning(false)
    let model = CameraBridgeAppModel(client: client, serviceLauncher: FakeServiceLauncher())

    await model.refreshNow()

    #expect(model.statusSummaryTitle == "Local service is stopped")
    #expect(model.serviceStatusTitle == "Stopped")
    #expect(model.permissionStatusTitle == "Unavailable")
    #expect(model.guidanceMessage == "Start the local service to check camera permissions and finish onboarding.")
    #expect(model.canStartService)
    #expect(!model.canRequestCameraAccess)
    #expect(model.lastErrorMessage == nil)
}

@Test(arguments: [
    (
        CameraBridgePermissionStatus.notDetermined,
        "Camera access setup is incomplete",
        "Request camera access to complete the app-owned onboarding flow."
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
func runningServiceShowsPermissionSpecificGuidance(
    permissionStatus: CameraBridgePermissionStatus,
    expectedSummary: String,
    expectedGuidance: String
) async {
    let client = FakeCameraBridgeAppClient()
    await client.setServiceIsRunning(true)
    await client.setPermissionStatus(.success(permissionStatus))
    let model = CameraBridgeAppModel(client: client, serviceLauncher: FakeServiceLauncher())

    await model.refreshNow()

    #expect(model.serviceStatusTitle == "Running")
    #expect(model.permissionStatusTitle == permissionStatusTitle(permissionStatus))
    #expect(model.statusSummaryTitle == expectedSummary)
    #expect(model.guidanceMessage == expectedGuidance)
}

@Test
@MainActor
func startServiceFailureShowsErrorState() async {
    let client = FakeCameraBridgeAppClient()
    await client.setServiceIsRunning(false)
    let launcher = FakeServiceLauncher()
    launcher.error = CameraBridgeServiceLaunchError.failedToStartService
    let model = CameraBridgeAppModel(client: client, serviceLauncher: launcher)

    await model.startServiceNow()

    #expect(model.serviceStatusTitle == "Needs Attention")
    #expect(model.guidanceMessage == "Start the local service to check camera permissions and finish onboarding.")
    #expect(model.lastErrorMessage == "Service did not become healthy after launch")
    #expect(model.canStartService)
}

@Test
@MainActor
func permissionRequestFailureShowsErrorAndKeepsActionAvailable() async {
    let client = FakeCameraBridgeAppClient()
    await client.setServiceIsRunning(true)
    await client.setPermissionStatus(.success(.notDetermined))
    await client.setRequestPermissionResult(.failure(CameraBridgeClientError.requestFailed(
        statusCode: 401,
        code: "unauthorized",
        message: "Bearer token missing or invalid"
    )))
    let model = CameraBridgeAppModel(client: client, serviceLauncher: FakeServiceLauncher())

    await model.refreshNow()
    await model.requestCameraAccessNow()

    #expect(model.permissionStatusTitle == "Unavailable")
    #expect(model.statusSummaryTitle == "Service is running")
    #expect(model.guidanceMessage == "The service is running, but permission status could not be loaded.")
    #expect(model.lastErrorMessage == "Bearer token missing or invalid")
    #expect(model.canRequestCameraAccess)
}

@Test
@MainActor
func startServiceDisablesActionWhileLaunchIsInFlight() async {
    let client = FakeCameraBridgeAppClient()
    await client.setServiceIsRunning(false)
    let launcher = FakeServiceLauncher()
    let model = CameraBridgeAppModel(client: client, serviceLauncher: launcher)

    let task = Task {
        await model.startServiceNow()
    }
    await Task.yield()

    #expect(model.serviceStatusTitle == "Starting")
    #expect(model.statusSummaryTitle == "CameraBridge is starting")
    #expect(!model.canStartService)

    await client.setServiceIsRunning(true)
    await client.setPermissionStatus(.success(.authorized))
    launcher.finish()
    await task.value

    #expect(model.serviceStatusTitle == "Running")
    #expect(model.canRequestCameraAccess)
}

@Test
@MainActor
func permissionRequestDisablesActionWhilePromptIsInFlight() async {
    let client = FakeCameraBridgeAppClient()
    await client.setServiceIsRunning(true)
    await client.setPermissionStatus(.success(.notDetermined))
    let model = CameraBridgeAppModel(client: client, serviceLauncher: FakeServiceLauncher())

    await model.refreshNow()
    let task = Task {
        await model.requestCameraAccessNow()
    }
    await Task.yield()

    #expect(model.permissionStatusTitle == "Requesting Access")
    #expect(model.statusSummaryTitle == "Waiting for camera access")
    #expect(!model.canRequestCameraAccess)

    await client.setRequestPermissionResult(.success(.init(status: .authorized, prompted: true)))
    await client.setPermissionStatus(.success(.authorized))
    await task.value

    #expect(model.permissionStatusTitle == "Authorized")
    #expect(model.statusSummaryTitle == "CameraBridge is ready")
    #expect(model.canRequestCameraAccess)
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
    private var permissionStatusResult: Result<CameraBridgePermissionStatus, Error> = .success(.notDetermined)
    private var requestPermissionResult: Result<CameraBridgePermissionRequestResult, Error>?

    func setServiceIsRunning(_ value: Bool) {
        isRunning = value
    }

    func setPermissionStatus(_ result: Result<CameraBridgePermissionStatus, Error>) {
        permissionStatusResult = result
    }

    func setRequestPermissionResult(_ result: Result<CameraBridgePermissionRequestResult, Error>) {
        requestPermissionResult = result
    }

    func serviceIsRunning() async -> Bool {
        isRunning
    }

    func permissionStatus() async throws -> CameraBridgePermissionStatus {
        try permissionStatusResult.get()
    }

    func requestPermission() async throws -> CameraBridgePermissionRequestResult {
        while requestPermissionResult == nil {
            await Task.yield()
        }

        return try requestPermissionResult!.get()
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

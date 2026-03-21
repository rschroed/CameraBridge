import AVFoundation
import Dispatch
import Foundation
import Testing
@testable import CameraBridgeCore

@Test
func coreModuleNameMatchesTarget() {
    #expect(CameraBridgeCoreModule.name == "CameraBridgeCore")
}

@Test
func cameraStateDefaultsMatchEarlySlice() {
    let state = CameraState()

    #expect(state.permissionState == .notDetermined)
    #expect(state.sessionState == .stopped)
    #expect(state.previewState == .stopped)
    #expect(state.activeDeviceID == nil)
    #expect(state.currentOwnerID == nil)
    #expect(state.lastError == nil)
}

@Test
func permissionStateRawValuesMatchAPIVocabulary() {
    #expect(PermissionState.notDetermined.rawValue == "not_determined")
    #expect(PermissionState.restricted.rawValue == "restricted")
    #expect(PermissionState.denied.rawValue == "denied")
    #expect(PermissionState.authorized.rawValue == "authorized")
}

@Test
func sessionStateRawValuesMatchAPIVocabulary() {
    #expect(SessionState.stopped.rawValue == "stopped")
    #expect(SessionState.running.rawValue == "running")
}

@Test
func cameraDevicePositionRawValuesMatchAPIVocabulary() {
    #expect(CameraDevicePosition.front.rawValue == "front")
    #expect(CameraDevicePosition.back.rawValue == "back")
    #expect(CameraDevicePosition.external.rawValue == "external")
}

@Test
func cameraStateRetainsExplicitValues() {
    let error = CameraStateError(message: "permission unavailable")
    let state = CameraState(
        permissionState: .authorized,
        sessionState: .running,
        previewState: .running,
        activeDeviceID: "camera-1",
        currentOwnerID: "client-1",
        lastError: error
    )

    #expect(state.permissionState == .authorized)
    #expect(state.sessionState == .running)
    #expect(state.previewState == .running)
    #expect(state.activeDeviceID == "camera-1")
    #expect(state.currentOwnerID == "client-1")
    #expect(state.lastError == error)
}

@Test
func permissionStateMapsAVFoundationStatusValues() {
    #expect(PermissionState(authorizationStatus: .notDetermined) == .notDetermined)
    #expect(PermissionState(authorizationStatus: .restricted) == .restricted)
    #expect(PermissionState(authorizationStatus: .denied) == .denied)
    #expect(PermissionState(authorizationStatus: .authorized) == .authorized)
}

@Test
func cameraDeviceRetainsExplicitValues() {
    let device = CameraDevice(id: "camera-1", name: "Desk Camera", position: .external)

    #expect(device.id == "camera-1")
    #expect(device.name == "Desk Camera")
    #expect(device.position == .external)
}

@Test
func cameraDevicePositionMapsAVFoundationPositionValues() {
    #expect(CameraDevicePosition(position: .front) == .front)
    #expect(CameraDevicePosition(position: .back) == .back)
    #expect(CameraDevicePosition(position: .unspecified) == .external)
}

@Test
func defaultCameraStateProviderReturnsConfiguredState() {
    let state = CameraState(
        permissionState: .authorized,
        sessionState: .running,
        previewState: .stopped,
        activeDeviceID: "camera-1",
        currentOwnerID: "client-1",
        lastError: CameraStateError(message: "session failed")
    )
    let provider = DefaultCameraStateProvider(state: state)

    #expect(provider.currentCameraState() == state)
}

@Test
func defaultCameraSessionControllerSyncsPermissionStateFromProvider() {
    let controller = DefaultCameraSessionController(
        permissionStatusProvider: FixedPermissionStatusProvider(state: .restricted),
        permissionRequester: FixedPermissionRequester(result: .init(status: .authorized, prompted: false)),
        deviceListing: FixedDeviceListing(devices: [])
    )

    let permissionState = controller.currentPermissionState()

    #expect(permissionState == .restricted)
    #expect(controller.currentCameraState().permissionState == .restricted)
}

@Test
func defaultCameraSessionControllerUpdatesPermissionStateWhenRequestingPermission() {
    let controller = DefaultCameraSessionController(
        permissionStatusProvider: FixedPermissionStatusProvider(state: .notDetermined),
        permissionRequester: FixedPermissionRequester(result: .init(status: .authorized, prompted: true)),
        deviceListing: FixedDeviceListing(devices: []),
        initialState: CameraState(lastError: CameraStateError(message: "stale error"))
    )
    let semaphore = DispatchSemaphore(value: 0)
    let expectedResult = PermissionRequestResult(status: .authorized, prompted: true)
    let resultBox = PermissionRequestResultBox()

    controller.requestPermission { result in
        resultBox.result = result
        semaphore.signal()
    }

    #expect(semaphore.wait(timeout: .now() + 1) == .success)
    #expect(resultBox.result == expectedResult)
    #expect(controller.currentCameraState().permissionState == .authorized)
    #expect(controller.currentCameraState().lastError == nil)
}

@Test
func defaultCameraSessionControllerSelectsAvailableDevice() throws {
    let controller = DefaultCameraSessionController(
        deviceListing: FixedDeviceListing(
            devices: [
                CameraDevice(id: "camera-1", name: "Built-in Camera", position: .front),
                CameraDevice(id: "camera-2", name: "Desk Camera", position: .external),
            ]
        )
    )

    let state = try controller.selectDevice(id: "camera-2", ownerID: nil)

    #expect(state.activeDeviceID == "camera-2")
    #expect(state.currentOwnerID == nil)
    #expect(state.lastError == nil)
    #expect(controller.currentCameraState().activeDeviceID == "camera-2")
}

@Test
func defaultCameraSessionControllerRejectsUnavailableDevice() {
    let controller = DefaultCameraSessionController(
        deviceListing: FixedDeviceListing(
            devices: [
                CameraDevice(id: "camera-1", name: "Built-in Camera", position: .front),
            ]
        ),
        initialState: CameraState(activeDeviceID: "camera-1")
    )

    do {
        _ = try controller.selectDevice(id: "missing-camera", ownerID: nil)
        Issue.record("Expected unavailable device selection to fail")
    } catch let error as CameraDeviceSelectionError {
        #expect(error == .unavailableDevice(id: "missing-camera"))
    } catch {
        Issue.record("Unexpected error: \(error)")
    }

    let state = controller.currentCameraState()
    #expect(state.activeDeviceID == "camera-1")
    #expect(state.lastError == CameraStateError(message: "Requested device is unavailable: missing-camera"))
}

@Test
func defaultCameraSessionControllerRejectsMismatchedOwner() {
    let controller = DefaultCameraSessionController(
        deviceListing: FixedDeviceListing(
            devices: [
                CameraDevice(id: "camera-1", name: "Built-in Camera", position: .front),
            ]
        ),
        initialState: CameraState(
            permissionState: .authorized,
            sessionState: .running,
            previewState: .stopped,
            activeDeviceID: "camera-1",
            currentOwnerID: "client-1",
            lastError: nil
        )
    )

    do {
        _ = try controller.selectDevice(id: "camera-1", ownerID: "client-2")
        Issue.record("Expected owner mismatch to fail")
    } catch let error as CameraDeviceSelectionError {
        #expect(error == .ownershipConflict(currentOwnerID: "client-1"))
    } catch {
        Issue.record("Unexpected error: \(error)")
    }

    let state = controller.currentCameraState()
    #expect(state.activeDeviceID == "camera-1")
    #expect(state.currentOwnerID == "client-1")
    #expect(state.lastError == CameraStateError(message: "Session is owned by client-1"))
}

@Test
func defaultCameraSessionControllerStartsSessionWithSelectedDeviceAndOwner() throws {
    let controller = DefaultCameraSessionController(
        deviceListing: FixedDeviceListing(
            devices: [
                CameraDevice(id: "camera-1", name: "Built-in Camera", position: .front),
            ]
        ),
        initialState: CameraState(
            permissionState: .notDetermined,
            sessionState: .stopped,
            previewState: .stopped,
            activeDeviceID: "camera-1",
            currentOwnerID: nil,
            lastError: nil
        )
    )

    let state = try controller.startSession(ownerID: "client-1", permissionState: .authorized)

    #expect(state.permissionState == .authorized)
    #expect(state.sessionState == .running)
    #expect(state.activeDeviceID == "camera-1")
    #expect(state.currentOwnerID == "client-1")
    #expect(state.lastError == nil)
}

@Test
func defaultCameraSessionControllerRejectsStartWithoutActiveDevice() {
    let controller = DefaultCameraSessionController(
        deviceListing: FixedDeviceListing(
            devices: [
                CameraDevice(id: "camera-1", name: "Built-in Camera", position: .front),
            ]
        )
    )

    do {
        _ = try controller.startSession(ownerID: "client-1", permissionState: .authorized)
        Issue.record("Expected session start without device to fail")
    } catch let error as CameraSessionLifecycleError {
        #expect(error == .missingActiveDevice)
    } catch {
        Issue.record("Unexpected error: \(error)")
    }

    let state = controller.currentCameraState()
    #expect(state.sessionState == .stopped)
    #expect(state.currentOwnerID == nil)
    #expect(state.lastError == CameraStateError(message: "Cannot start session without an active device"))
}

@Test
func defaultCameraSessionControllerRejectsStartWithoutAuthorizedPermission() {
    let controller = DefaultCameraSessionController(
        deviceListing: FixedDeviceListing(
            devices: [
                CameraDevice(id: "camera-1", name: "Built-in Camera", position: .front),
            ]
        ),
        initialState: CameraState(activeDeviceID: "camera-1")
    )

    do {
        _ = try controller.startSession(ownerID: "client-1", permissionState: .denied)
        Issue.record("Expected session start without permission to fail")
    } catch let error as CameraSessionLifecycleError {
        #expect(error == .permissionRequired(status: .denied))
    } catch {
        Issue.record("Unexpected error: \(error)")
    }

    let state = controller.currentCameraState()
    #expect(state.permissionState == .denied)
    #expect(state.sessionState == .stopped)
    #expect(state.lastError == CameraStateError(message: "Camera permission is denied"))
}

@Test
func defaultCameraSessionControllerRejectsStartForOwnerConflict() {
    let controller = DefaultCameraSessionController(
        deviceListing: FixedDeviceListing(
            devices: [
                CameraDevice(id: "camera-1", name: "Built-in Camera", position: .front),
            ]
        ),
        initialState: CameraState(
            permissionState: .authorized,
            sessionState: .stopped,
            previewState: .stopped,
            activeDeviceID: "camera-1",
            currentOwnerID: "client-1",
            lastError: nil
        )
    )

    do {
        _ = try controller.startSession(ownerID: "client-2", permissionState: .authorized)
        Issue.record("Expected owner conflict on start")
    } catch let error as CameraSessionLifecycleError {
        #expect(error == .ownershipConflict(currentOwnerID: "client-1"))
    } catch {
        Issue.record("Unexpected error: \(error)")
    }

    #expect(controller.currentCameraState().lastError == CameraStateError(message: "Session is owned by client-1"))
}

@Test
func defaultCameraSessionControllerStopsRunningSessionAndReleasesOwner() throws {
    let controller = DefaultCameraSessionController(
        deviceListing: FixedDeviceListing(
            devices: [
                CameraDevice(id: "camera-1", name: "Built-in Camera", position: .front),
            ]
        ),
        initialState: CameraState(
            permissionState: .authorized,
            sessionState: .running,
            previewState: .running,
            activeDeviceID: "camera-1",
            currentOwnerID: "client-1",
            lastError: nil
        )
    )

    let state = try controller.stopSession(ownerID: "client-1")

    #expect(state.sessionState == .stopped)
    #expect(state.previewState == .stopped)
    #expect(state.activeDeviceID == "camera-1")
    #expect(state.currentOwnerID == nil)
    #expect(state.lastError == nil)
}

@Test
func defaultCameraSessionControllerRejectsStopWhenAlreadyStopped() {
    let controller = DefaultCameraSessionController(
        deviceListing: FixedDeviceListing(devices: [])
    )

    do {
        _ = try controller.stopSession(ownerID: "client-1")
        Issue.record("Expected stop on stopped session to fail")
    } catch let error as CameraSessionLifecycleError {
        #expect(error == .alreadyStopped)
    } catch {
        Issue.record("Unexpected error: \(error)")
    }

    #expect(controller.currentCameraState().lastError == CameraStateError(message: "Session is already stopped"))
}

@Test
func defaultCameraSessionControllerRejectsStopForOwnerMismatch() {
    let controller = DefaultCameraSessionController(
        deviceListing: FixedDeviceListing(devices: []),
        initialState: CameraState(
            permissionState: .authorized,
            sessionState: .running,
            previewState: .stopped,
            activeDeviceID: "camera-1",
            currentOwnerID: "client-1",
            lastError: nil
        )
    )

    do {
        _ = try controller.stopSession(ownerID: "client-2")
        Issue.record("Expected owner conflict on stop")
    } catch let error as CameraSessionLifecycleError {
        #expect(error == .ownershipConflict(currentOwnerID: "client-1"))
    } catch {
        Issue.record("Unexpected error: \(error)")
    }

    #expect(controller.currentCameraState().lastError == CameraStateError(message: "Session is owned by client-1"))
}

@Test
func defaultPhotoArtifactStoreWritesPhotoDataToConfiguredDirectory() throws {
    let directoryURL = makeTemporaryDirectory()
    let store = DefaultPhotoArtifactStore(baseDirectoryURL: directoryURL)
    let capturedAt = Date(timeIntervalSince1970: 1_710_000_000.123)
    let data = Data([0xFF, 0xD8, 0xFF, 0xD9])

    let fileURL = try store.storePhotoData(data, deviceID: "camera-1", capturedAt: capturedAt)

    #expect(fileURL.path.hasPrefix(directoryURL.path))
    #expect(fileURL.pathExtension == "jpg")
    #expect(try Data(contentsOf: fileURL) == data)
}

@Test
func defaultCameraSessionControllerCapturesPhotoForRunningOwnedSession() throws {
    let directoryURL = makeTemporaryDirectory()
    let capturedAt = Date(timeIntervalSince1970: 1_710_000_000.123)
    let expectedData = Data([0x01, 0x02, 0x03, 0x04])
    let controller = DefaultCameraSessionController(
        deviceListing: FixedDeviceListing(
            devices: [CameraDevice(id: "camera-1", name: "Built-in Camera", position: .front)]
        ),
        photoProducer: FixedStillPhotoProducer(data: expectedData),
        artifactStore: DefaultPhotoArtifactStore(baseDirectoryURL: directoryURL),
        now: { capturedAt },
        initialState: CameraState(
            permissionState: .authorized,
            sessionState: .running,
            previewState: .stopped,
            activeDeviceID: "camera-1",
            currentOwnerID: "client-1",
            lastError: nil
        )
    )

    let artifact = try controller.capturePhoto(ownerID: "client-1")

    #expect(artifact.deviceID == "camera-1")
    #expect(artifact.capturedAt == capturedAt)
    #expect(artifact.localPath.hasPrefix(directoryURL.path))
    #expect(try Data(contentsOf: URL(fileURLWithPath: artifact.localPath)) == expectedData)
    #expect(controller.currentCameraState().lastError == nil)
}

@Test
func defaultCameraSessionControllerRejectsCaptureWhenSessionIsStopped() {
    let controller = DefaultCameraSessionController(
        deviceListing: FixedDeviceListing(
            devices: [CameraDevice(id: "camera-1", name: "Built-in Camera", position: .front)]
        ),
        initialState: CameraState(
            permissionState: .authorized,
            sessionState: .stopped,
            previewState: .stopped,
            activeDeviceID: "camera-1",
            currentOwnerID: "client-1",
            lastError: nil
        )
    )

    do {
        _ = try controller.capturePhoto(ownerID: "client-1")
        Issue.record("Expected photo capture on stopped session to fail")
    } catch let error as CameraPhotoCaptureError {
        #expect(error == .sessionNotRunning)
    } catch {
        Issue.record("Unexpected error: \(error)")
    }

    #expect(controller.currentCameraState().lastError == CameraStateError(message: "Session is not running"))
}

@Test
func defaultCameraSessionControllerRejectsCaptureForOwnerMismatch() {
    let controller = DefaultCameraSessionController(
        deviceListing: FixedDeviceListing(
            devices: [CameraDevice(id: "camera-1", name: "Built-in Camera", position: .front)]
        ),
        initialState: CameraState(
            permissionState: .authorized,
            sessionState: .running,
            previewState: .stopped,
            activeDeviceID: "camera-1",
            currentOwnerID: "client-1",
            lastError: nil
        )
    )

    do {
        _ = try controller.capturePhoto(ownerID: "client-2")
        Issue.record("Expected photo capture owner mismatch to fail")
    } catch let error as CameraPhotoCaptureError {
        #expect(error == .ownershipConflict(currentOwnerID: "client-1"))
    } catch {
        Issue.record("Unexpected error: \(error)")
    }

    #expect(controller.currentCameraState().lastError == CameraStateError(message: "Session is owned by client-1"))
}

@Test
func defaultCameraSessionControllerRetainsCaptureFailureAsLastError() {
    let controller = DefaultCameraSessionController(
        deviceListing: FixedDeviceListing(
            devices: [CameraDevice(id: "camera-1", name: "Built-in Camera", position: .front)]
        ),
        photoProducer: FailingStillPhotoProducer(
            error: .captureFailed(message: "AVFoundation timed out")
        ),
        initialState: CameraState(
            permissionState: .authorized,
            sessionState: .running,
            previewState: .stopped,
            activeDeviceID: "camera-1",
            currentOwnerID: "client-1",
            lastError: nil
        )
    )

    do {
        _ = try controller.capturePhoto(ownerID: "client-1")
        Issue.record("Expected photo capture failure to surface producer error")
    } catch let error as CameraPhotoCaptureError {
        #expect(error == .captureFailed(message: "AVFoundation timed out"))
    } catch {
        Issue.record("Unexpected error: \(error)")
    }

    #expect(controller.currentCameraState().lastError == CameraStateError(message: "AVFoundation timed out"))
}

private struct FixedDeviceListing: CameraDeviceListing {
    let devices: [CameraDevice]

    func availableDevices() -> [CameraDevice] {
        devices
    }
}

private struct FixedPermissionStatusProvider: CameraPermissionStatusProviding {
    let state: PermissionState

    func currentPermissionState() -> PermissionState {
        state
    }
}

private struct FixedPermissionRequester: CameraPermissionRequesting {
    let result: PermissionRequestResult

    func requestPermission(completion: @escaping @Sendable (PermissionRequestResult) -> Void) {
        completion(result)
    }
}

private final class PermissionRequestResultBox: @unchecked Sendable {
    var result: PermissionRequestResult?
}

private struct FixedStillPhotoProducer: CameraStillPhotoProducing {
    let data: Data

    func capturePhotoData(deviceID: String) throws -> Data {
        data
    }
}

private struct FailingStillPhotoProducer: CameraStillPhotoProducing {
    let error: CameraPhotoCaptureError

    func capturePhotoData(deviceID: String) throws -> Data {
        throw error
    }
}

private func makeTemporaryDirectory() -> URL {
    let directoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("CameraBridgeCoreTests-\(UUID().uuidString)", isDirectory: true)
    try! FileManager.default.createDirectory(
        at: directoryURL,
        withIntermediateDirectories: true,
        attributes: nil
    )
    return directoryURL
}

import Testing
@testable import CameraBridgeCore
import AVFoundation

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

private struct FixedDeviceListing: CameraDeviceListing {
    let devices: [CameraDevice]

    func availableDevices() -> [CameraDevice] {
        devices
    }
}

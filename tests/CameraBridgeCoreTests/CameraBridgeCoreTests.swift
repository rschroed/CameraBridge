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
        lastError: error
    )

    #expect(state.permissionState == .authorized)
    #expect(state.sessionState == .running)
    #expect(state.previewState == .running)
    #expect(state.activeDeviceID == "camera-1")
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

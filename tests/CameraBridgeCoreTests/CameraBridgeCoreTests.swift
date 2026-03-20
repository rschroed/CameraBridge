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

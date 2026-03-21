import CameraBridgeSupport
import Foundation
import Testing
@testable import camd
import CameraBridgeCore

@Test
func serverConfigurationResolvedAuthTokenPrefersExplicitConfiguration() throws {
    let directoryURL = makeTemporaryDirectoryURL()
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let configuration = ServerConfiguration(authToken: " explicit-token \n")
    let store = DefaultCameraBridgeAuthTokenStore(baseDirectoryURL: directoryURL)

    let token = try configuration.resolvedAuthToken(authTokenStore: store)

    #expect(token == "explicit-token")
}

@Test
func serverConfigurationResolvedAuthTokenLoadsOrCreatesStoredTokenWhenMissing() throws {
    let directoryURL = makeTemporaryDirectoryURL()
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let configuration = ServerConfiguration(authToken: nil)
    let store = DefaultCameraBridgeAuthTokenStore(baseDirectoryURL: directoryURL)

    let createdToken = try configuration.resolvedAuthToken(authTokenStore: store)
    let reloadedToken = try store.loadToken()

    #expect(!createdToken.isEmpty)
    #expect(reloadedToken == createdToken)
}

@Test(arguments: [
    (CameraBridgeStoredPermissionState.notDetermined, PermissionState.notDetermined),
    (CameraBridgeStoredPermissionState.restricted, PermissionState.restricted),
    (CameraBridgeStoredPermissionState.denied, PermissionState.denied),
    (CameraBridgeStoredPermissionState.authorized, PermissionState.authorized),
])
func storedPermissionStatusProviderMapsStoredState(
    storedState: CameraBridgeStoredPermissionState,
    expectedState: PermissionState
) throws {
    let directoryURL = makeTemporaryDirectoryURL()
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let store = DefaultCameraBridgePermissionStateStore(baseDirectoryURL: directoryURL)
    try store.savePermissionState(storedState)

    let provider = StoredPermissionStatusProvider(permissionStateStore: store)

    #expect(provider.currentPermissionState() == expectedState)
}

@Test
func storedPermissionStatusProviderDefaultsToNotDeterminedWhenStoreIsMissing() {
    let directoryURL = makeTemporaryDirectoryURL()
    let store = DefaultCameraBridgePermissionStateStore(baseDirectoryURL: directoryURL)

    let provider = StoredPermissionStatusProvider(permissionStateStore: store)

    #expect(provider.currentPermissionState() == .notDetermined)
}

@Test
func storedPermissionRequesterReturnsCurrentStoredPermissionWithoutPrompting() {
    let requester = StoredPermissionRequester(
        permissionStatusProvider: FixedPermissionStatusProvider(state: .authorized)
    )
    let resultBox = PermissionRequestResultBox()
    requester.requestPermission { resultBox.result = $0 }

    #expect(resultBox.result == .init(status: .authorized, prompted: false))
}

private func makeTemporaryDirectoryURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
}

private struct FixedPermissionStatusProvider: CameraPermissionStatusProviding {
    let state: PermissionState

    func currentPermissionState() -> PermissionState {
        state
    }
}

private final class PermissionRequestResultBox: @unchecked Sendable {
    var result: PermissionRequestResult?
}

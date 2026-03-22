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

@Test
func daemonNonPromptingPermissionRequesterReturnsCurrentLiveStateWithoutPrompting() {
    let requester = DaemonNonPromptingPermissionRequester(
        permissionStatusProvider: FixedPermissionStatusProvider(state: .authorized)
    )
    let resultBox = PermissionRequestResultBox()
    requester.requestPermission { resultBox.result = $0 }

    #expect(resultBox.result == .init(status: .authorized, prompted: false))
}

@Test(arguments: PermissionState.allCases)
func daemonNonPromptingPermissionRequesterPreservesPermissionStateMapping(_ state: PermissionState) {
    let requester = DaemonNonPromptingPermissionRequester(
        permissionStatusProvider: FixedPermissionStatusProvider(state: state)
    )
    let resultBox = PermissionRequestResultBox()
    requester.requestPermission { resultBox.result = $0 }

    #expect(resultBox.result == .init(status: state, prompted: false))
}

@Test
func daemonNonPromptingPermissionRequesterIgnoresStalePermissionStateFiles() throws {
    let staleDirectoryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: staleDirectoryURL) }

    try FileManager.default.createDirectory(at: staleDirectoryURL, withIntermediateDirectories: true)
    let staleFileURL = staleDirectoryURL.appendingPathComponent("permission-state", isDirectory: false)
    try Data("authorized".utf8).write(to: staleFileURL, options: .atomic)

    let requester = DaemonNonPromptingPermissionRequester(
        permissionStatusProvider: FixedPermissionStatusProvider(state: .denied)
    )
    let resultBox = PermissionRequestResultBox()
    requester.requestPermission { resultBox.result = $0 }

    #expect(resultBox.result == .init(status: .denied, prompted: false))
    #expect(try String(contentsOf: staleFileURL, encoding: .utf8) == "authorized")
}

@Test
func serverConfigurationUsesStoredRuntimeConfigurationWhenHostAndPortAreNotProvided() throws {
    let directoryURL = makeTemporaryDirectoryURL()
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let runtimeConfigurationStore = DefaultCameraBridgeRuntimeConfigurationStore(baseDirectoryURL: directoryURL)
    try runtimeConfigurationStore.saveConfiguration(.init(host: "127.0.0.1", port: 9101))

    let configuration = ServerConfiguration(runtimeConfigurationStore: runtimeConfigurationStore)

    #expect(configuration.host == "127.0.0.1")
    #expect(configuration.port == 9101)
}

@Test
func daemonRuntimeInfoUsesRuntimeOwnershipAndStablePaths() throws {
    let directoryURL = makeTemporaryDirectoryURL()
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let authTokenStore = DefaultCameraBridgeAuthTokenStore(baseDirectoryURL: directoryURL)
    let token = try authTokenStore.loadOrCreateToken()
    #expect(!token.isEmpty)

    let daemon = CameraBridgeDaemon(configuration: .init(host: "127.0.0.1", port: 9102))
    let runtimeInfo = try daemon.runtimeInfo(
        boundPort: 9102,
        authTokenStore: authTokenStore
    )

    #expect(runtimeInfo.host == "127.0.0.1")
    #expect(runtimeInfo.port == 9102)
    #expect(runtimeInfo.tokenFileURL.path.hasSuffix("auth-token"))
    #expect(runtimeInfo.logFileURL.path.hasSuffix("Logs/camd.log"))
    #expect(runtimeInfo.capturesDirectoryURL.path.hasSuffix("Captures"))
    #expect(runtimeInfo.ownership == .external)
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

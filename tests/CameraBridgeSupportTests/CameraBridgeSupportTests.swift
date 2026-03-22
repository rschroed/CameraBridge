import CameraBridgeSupport
import Foundation
import Testing

@Test
func authTokenStoreReturnsNilWhenTokenFileIsMissing() throws {
    let directoryURL = makeTemporaryDirectoryURL()
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let store = DefaultCameraBridgeAuthTokenStore(baseDirectoryURL: directoryURL)

    #expect(try store.loadToken() == nil)
}

@Test
func authTokenStoreCreatesAndReloadsTokenFromApplicationSupportDirectory() throws {
    let directoryURL = makeTemporaryDirectoryURL()
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let store = DefaultCameraBridgeAuthTokenStore(baseDirectoryURL: directoryURL)

    let createdToken = try store.loadOrCreateToken()
    let tokenURL = try store.authTokenURL()
    let reloadedToken = try store.loadToken()

    #expect(!createdToken.isEmpty)
    #expect(reloadedToken == createdToken)
    #expect(FileManager.default.fileExists(atPath: tokenURL.path))
}

@Test
func authTokenStoreRejectsWhitespaceOnlyTokenFiles() throws {
    let directoryURL = makeTemporaryDirectoryURL()
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let store = DefaultCameraBridgeAuthTokenStore(baseDirectoryURL: directoryURL)
    let tokenURL = try store.authTokenURL()
    try FileManager.default.createDirectory(
        at: tokenURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try Data(" \n".utf8).write(to: tokenURL, options: .atomic)

    #expect(throws: CameraBridgeAuthTokenError.invalidTokenFile) {
        _ = try store.loadToken()
    }
}

@Test
func permissionStateStoreDefaultsToNotDeterminedWhenFileIsMissing() throws {
    let directoryURL = makeTemporaryDirectoryURL()
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let store = DefaultCameraBridgePermissionStateStore(baseDirectoryURL: directoryURL)

    #expect(try store.loadPermissionState() == .notDetermined)
}

@Test
func permissionStateStoreSavesAndReloadsStoredState() throws {
    let directoryURL = makeTemporaryDirectoryURL()
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let store = DefaultCameraBridgePermissionStateStore(baseDirectoryURL: directoryURL)

    try store.savePermissionState(.authorized)

    #expect(try store.loadPermissionState() == .authorized)
    #expect(FileManager.default.fileExists(atPath: try store.permissionStateURL().path))
}

@Test
func permissionStateStoreRejectsInvalidStoredState() throws {
    let directoryURL = makeTemporaryDirectoryURL()
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let store = DefaultCameraBridgePermissionStateStore(baseDirectoryURL: directoryURL)
    let permissionStateURL = try store.permissionStateURL()
    try FileManager.default.createDirectory(
        at: permissionStateURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try Data("camera-maybe".utf8).write(to: permissionStateURL, options: .atomic)

    #expect(throws: CameraBridgePermissionStateStoreError.invalidPermissionStateFile) {
        _ = try store.loadPermissionState()
    }
}

@Test
func runtimeConfigurationStoreDefaultsToLocalhostConfigurationWhenFileIsMissing() throws {
    let directoryURL = makeTemporaryDirectoryURL()
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let store = DefaultCameraBridgeRuntimeConfigurationStore(baseDirectoryURL: directoryURL)

    #expect(try store.loadConfiguration() == .init())
}

@Test
func runtimeConfigurationStoreSavesAndReloadsConfiguration() throws {
    let directoryURL = makeTemporaryDirectoryURL()
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let store = DefaultCameraBridgeRuntimeConfigurationStore(baseDirectoryURL: directoryURL)
    let configuration = CameraBridgeRuntimeConfiguration(host: "127.0.0.1", port: 9123)

    try store.saveConfiguration(configuration)

    #expect(try store.loadConfiguration() == configuration)
    #expect(FileManager.default.fileExists(atPath: try store.runtimeConfigurationURL().path))
}

@Test
func runtimeInfoStoreReturnsNilWhenFileIsMissing() throws {
    let directoryURL = makeTemporaryDirectoryURL()
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let store = DefaultCameraBridgeRuntimeInfoStore(baseDirectoryURL: directoryURL)

    #expect(try store.loadRuntimeInfo() == nil)
}

@Test
func runtimeInfoStoreSavesReloadsAndClearsRuntimeInfo() throws {
    let directoryURL = makeTemporaryDirectoryURL()
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let store = DefaultCameraBridgeRuntimeInfoStore(baseDirectoryURL: directoryURL)
    let runtimeInfo = CameraBridgeRuntimeInfo(
        pid: 42,
        host: "127.0.0.1",
        port: 8731,
        tokenFileURL: directoryURL.appendingPathComponent("auth-token", isDirectory: false),
        logFileURL: directoryURL.appendingPathComponent("Logs/camd.log", isDirectory: false),
        capturesDirectoryURL: directoryURL.appendingPathComponent("Captures", isDirectory: true),
        ownership: .appManaged
    )

    try store.saveRuntimeInfo(runtimeInfo)
    #expect(try store.loadRuntimeInfo() == runtimeInfo)

    try store.clearRuntimeInfo()
    #expect(try store.loadRuntimeInfo() == nil)
}

private func makeTemporaryDirectoryURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
}

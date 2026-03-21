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

private func makeTemporaryDirectoryURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
}

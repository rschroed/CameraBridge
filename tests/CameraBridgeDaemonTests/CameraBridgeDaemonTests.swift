import CameraBridgeSupport
import Foundation
import Testing
@testable import camd

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

private func makeTemporaryDirectoryURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
}

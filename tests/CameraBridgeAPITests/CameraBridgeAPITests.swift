import Foundation
import Testing
@testable import CameraBridgeAPI
import CameraBridgeCore

@Test
func apiModuleNameMatchesTarget() {
    #expect(CameraBridgeAPIModule.name == "CameraBridgeAPI")
}

@Test
func routerReturnsNotFoundForUnknownRoute() {
    let router = CameraBridgeRouter()
    let response = router.response(for: HTTPRequest(method: .get, path: "/missing"))

    #expect(response.statusCode == 404)
    #expect(String(decoding: response.body, as: UTF8.self) == #"{ "error": { "code": "not_found", "message": "Route not found" } }"#)
}

@Test
func routerReturnsHealthResponseForHealthRoute() {
    let router = CameraBridgeRouter(
        routes: CameraBridgeRoutes.current(permissionStatusProvider: FixedPermissionStatusProvider(state: .authorized))
    )
    let response = router.response(for: HTTPRequest(method: .get, path: "/health"))

    #expect(response.statusCode == 200)
    #expect(String(decoding: response.body, as: UTF8.self) == #"{ "status": "ok" }"#)
}

@Test
func localHTTPServerReturnsHealthResponse() async throws {
    let port = try reserveEphemeralPort()
    let server = LocalHTTPServer(
        configuration: .init(host: "127.0.0.1", port: port),
        router: CameraBridgeRouter(
            routes: CameraBridgeRoutes.current(permissionStatusProvider: FixedPermissionStatusProvider(state: .authorized))
        )
    )

    defer { server.stop() }

    let boundPort = try server.start()
    let url = try #require(URL(string: "http://127.0.0.1:\(boundPort)/health"))
    let (data, response) = try await URLSession.shared.data(from: url)
    let httpResponse = try #require(response as? HTTPURLResponse)

    #expect(httpResponse.statusCode == 200)
    #expect(String(decoding: data, as: UTF8.self) == #"{ "status": "ok" }"#)
}

@Test
func localHTTPServerStillReturnsNotFoundForUnknownRoute() async throws {
    let port = try reserveEphemeralPort()
    let server = LocalHTTPServer(
        configuration: .init(host: "127.0.0.1", port: port),
        router: CameraBridgeRouter(
            routes: CameraBridgeRoutes.current(permissionStatusProvider: FixedPermissionStatusProvider(state: .authorized))
        )
    )

    defer { server.stop() }

    let boundPort = try server.start()
    var request = URLRequest(url: try #require(URL(string: "http://127.0.0.1:\(boundPort)/missing")))
    request.setValue("Bearer unused-token", forHTTPHeaderField: "Authorization")
    let (data, response) = try await URLSession.shared.data(for: request)
    let httpResponse = try #require(response as? HTTPURLResponse)

    #expect(httpResponse.statusCode == 404)
    #expect(String(decoding: data, as: UTF8.self) == #"{ "error": { "code": "not_found", "message": "Route not found" } }"#)
}

@Test(arguments: PermissionState.allCases)
func routerReturnsPermissionStatusForProviderState(_ state: PermissionState) {
    let router = CameraBridgeRouter(
        routes: CameraBridgeRoutes.current(permissionStatusProvider: FixedPermissionStatusProvider(state: state))
    )
    let response = router.response(for: HTTPRequest(method: .get, path: "/v1/permissions"))

    #expect(response.statusCode == 200)
    #expect(String(decoding: response.body, as: UTF8.self) == #"{ "status": "\#(state.rawValue)" }"#)
}

@Test
func localHTTPServerReturnsPermissionStatusWithoutAuth() async throws {
    let port = try reserveEphemeralPort()
    let server = LocalHTTPServer(
        configuration: .init(host: "127.0.0.1", port: port),
        router: CameraBridgeRouter(
            routes: CameraBridgeRoutes.current(permissionStatusProvider: FixedPermissionStatusProvider(state: .restricted))
        )
    )

    defer { server.stop() }

    let boundPort = try server.start()
    let url = try #require(URL(string: "http://127.0.0.1:\(boundPort)/v1/permissions"))
    let (data, response) = try await URLSession.shared.data(from: url)
    let httpResponse = try #require(response as? HTTPURLResponse)

    #expect(httpResponse.statusCode == 200)
    #expect(String(decoding: data, as: UTF8.self) == #"{ "status": "restricted" }"#)
}

private struct FixedPermissionStatusProvider: CameraPermissionStatusProviding {
    let state: PermissionState

    func currentPermissionState() -> PermissionState {
        state
    }
}

private func reserveEphemeralPort() throws -> UInt16 {
    let socketDescriptor = socket(AF_INET, SOCK_STREAM, 0)
    guard socketDescriptor >= 0 else {
        throw POSIXError(.EIO)
    }

    defer { close(socketDescriptor) }

    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = in_port_t(0).bigEndian
    address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

    let bindResult = withUnsafePointer(to: &address) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            bind(socketDescriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }

    guard bindResult == 0 else {
        throw POSIXError(.EADDRNOTAVAIL)
    }

    var assignedAddress = sockaddr_in()
    var length = socklen_t(MemoryLayout<sockaddr_in>.size)

    let nameResult = withUnsafeMutablePointer(to: &assignedAddress) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            getsockname(socketDescriptor, $0, &length)
        }
    }

    guard nameResult == 0 else {
        throw POSIXError(.EIO)
    }

    return UInt16(bigEndian: assignedAddress.sin_port)
}

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
    #expect(
        String(decoding: response.body, as: UTF8.self) ==
        #"{"error":{"code":"not_found","message":"Route not found"}}"#
    )
}

@Test
func routerReturnsHealthResponseForHealthRoute() {
    let sessionController = makeSessionController()
    let router = makeRouter(sessionController: sessionController)
    let response = router.response(for: HTTPRequest(method: .get, path: "/health"))

    #expect(response.statusCode == 200)
    #expect(String(decoding: response.body, as: UTF8.self) == #"{ "status": "ok" }"#)
}

@Test
func localHTTPServerReturnsHealthResponse() async throws {
    let port = try reserveEphemeralPort()
    let sessionController = makeSessionController()
    let server = LocalHTTPServer(
        configuration: .init(host: "127.0.0.1", port: port),
        router: makeRouter(sessionController: sessionController)
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
func localHTTPServerReturnsHealthResponseForLocalhostAlias() async throws {
    let port = try reserveEphemeralPort()
    let sessionController = makeSessionController()
    let server = LocalHTTPServer(
        configuration: .init(host: "localhost", port: port),
        router: makeRouter(sessionController: sessionController)
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
func localHTTPServerRejectsInvalidHostConfiguration() throws {
    let port = try reserveEphemeralPort()
    let sessionController = makeSessionController()
    let server = LocalHTTPServer(
        configuration: .init(host: "camera-bridge.local", port: port),
        router: makeRouter(sessionController: sessionController)
    )

    #expect(throws: HTTPServerError.invalidHost("camera-bridge.local")) {
        _ = try server.start()
    }
}

@Test
func localHTTPServerStillReturnsNotFoundForUnknownRoute() async throws {
    let port = try reserveEphemeralPort()
    let sessionController = makeSessionController()
    let server = LocalHTTPServer(
        configuration: .init(host: "127.0.0.1", port: port),
        router: makeRouter(sessionController: sessionController)
    )

    defer { server.stop() }

    let boundPort = try server.start()
    var request = URLRequest(url: try #require(URL(string: "http://127.0.0.1:\(boundPort)/missing")))
    request.setValue("Bearer unused-token", forHTTPHeaderField: "Authorization")
    let (data, response) = try await URLSession.shared.data(for: request)
    let httpResponse = try #require(response as? HTTPURLResponse)

    #expect(httpResponse.statusCode == 404)
    #expect(
        String(decoding: data, as: UTF8.self) ==
        #"{"error":{"code":"not_found","message":"Route not found"}}"#
    )
}

@Test(arguments: PermissionState.allCases)
func routerReturnsPermissionStatusForProviderState(_ state: PermissionState) {
    let sessionController = makeSessionController()
    let router = makeRouter(sessionController: sessionController, permissionState: state)
    let response = router.response(for: HTTPRequest(method: .get, path: "/v1/permissions"))

    #expect(response.statusCode == 200)
    #expect(String(decoding: response.body, as: UTF8.self) == #"{ "status": "\#(state.rawValue)" }"#)
}

@Test
func localHTTPServerReturnsPermissionStatusWithoutAuth() async throws {
    let port = try reserveEphemeralPort()
    let sessionController = makeSessionController()
    let server = LocalHTTPServer(
        configuration: .init(host: "127.0.0.1", port: port),
        router: makeRouter(sessionController: sessionController, permissionState: .restricted)
    )

    defer { server.stop() }

    let boundPort = try server.start()
    let url = try #require(URL(string: "http://127.0.0.1:\(boundPort)/v1/permissions"))
    let (data, response) = try await URLSession.shared.data(from: url)
    let httpResponse = try #require(response as? HTTPURLResponse)

    #expect(httpResponse.statusCode == 200)
    #expect(String(decoding: data, as: UTF8.self) == #"{ "status": "restricted" }"#)
}

@Test
func routerRejectsPermissionRequestWithoutBearerToken() {
    let requester = RecordingPermissionRequester(result: .init(status: .authorized, prompted: true))
    let sessionController = makeSessionController()
    let router = makeRouter(sessionController: sessionController, permissionRequester: requester)
    let response = router.response(for: HTTPRequest(method: .post, path: "/v1/permissions/request"))

    #expect(response.statusCode == 401)
    #expect(
        String(decoding: response.body, as: UTF8.self) ==
        #"{"error":{"code":"unauthorized","message":"Bearer token missing or invalid"}}"#
    )
    #expect(requester.requestCount == 0)
}

@Test
func routerReturnsPermissionRequestResultForAuthorizedRequest() {
    let requester = RecordingPermissionRequester(result: .init(status: .authorized, prompted: true))
    let sessionController = makeSessionController()
    let router = makeRouter(sessionController: sessionController, permissionRequester: requester)
    let response = router.response(
        for: HTTPRequest(
            method: .post,
            path: "/v1/permissions/request",
            headers: ["Authorization": "Bearer test-token"]
        )
    )

    #expect(response.statusCode == 200)
    #expect(String(decoding: response.body, as: UTF8.self) == #"{"prompted":true,"status":"authorized"}"#)
    #expect(requester.requestCount == 1)
}

@Test
func localHTTPServerReturnsPermissionRequestResultForAuthorizedRequest() async throws {
    let port = try reserveEphemeralPort()
    let sessionController = makeSessionController()
    let server = LocalHTTPServer(
        configuration: .init(host: "127.0.0.1", port: port),
        router: makeRouter(
            sessionController: sessionController,
            permissionRequester: FixedPermissionRequester(result: .init(status: .denied, prompted: true))
        )
    )

    defer { server.stop() }

    let boundPort = try server.start()
    var request = URLRequest(url: try #require(URL(string: "http://127.0.0.1:\(boundPort)/v1/permissions/request")))
    request.httpMethod = "POST"
    request.setValue("Bearer test-token", forHTTPHeaderField: "Authorization")
    let (data, response) = try await URLSession.shared.data(for: request)
    let httpResponse = try #require(response as? HTTPURLResponse)

    #expect(httpResponse.statusCode == 200)
    #expect(String(decoding: data, as: UTF8.self) == #"{"prompted":true,"status":"denied"}"#)
}

@Test
func routerReturnsDeviceListForDeviceRoute() {
    let devices = [
        CameraDevice(id: "camera-1", name: "Built-in Camera", position: .front),
        CameraDevice(id: "camera-2", name: "Desk Camera", position: .external),
    ]
    let sessionController = makeSessionController(devices: devices)
    let router = makeRouter(sessionController: sessionController)
    let response = router.response(for: HTTPRequest(method: .get, path: "/v1/devices"))

    #expect(response.statusCode == 200)
    #expect(
        String(decoding: response.body, as: UTF8.self) ==
        #"{"devices":[{"id":"camera-1","name":"Built-in Camera","position":"front"},{"id":"camera-2","name":"Desk Camera","position":"external"}]}"#
    )
}

@Test
func localHTTPServerReturnsDeviceListWithoutAuth() async throws {
    let port = try reserveEphemeralPort()
    let devices = [
        CameraDevice(id: "camera-1", name: "Built-in Camera", position: .front),
        CameraDevice(id: "camera-2", name: "Desk Camera", position: .external),
    ]
    let sessionController = makeSessionController(devices: devices)
    let server = LocalHTTPServer(
        configuration: .init(host: "127.0.0.1", port: port),
        router: makeRouter(sessionController: sessionController)
    )

    defer { server.stop() }

    let boundPort = try server.start()
    let url = try #require(URL(string: "http://127.0.0.1:\(boundPort)/v1/devices"))
    let (data, response) = try await URLSession.shared.data(from: url)
    let httpResponse = try #require(response as? HTTPURLResponse)

    #expect(httpResponse.statusCode == 200)
    #expect(
        String(decoding: data, as: UTF8.self) ==
        #"{"devices":[{"id":"camera-1","name":"Built-in Camera","position":"front"},{"id":"camera-2","name":"Desk Camera","position":"external"}]}"#
    )
}

@Test
func routerReturnsSessionStateForSessionRoute() {
    let sessionController = makeSessionController(
        state: CameraState(
            permissionState: .authorized,
            sessionState: .running,
            previewState: .stopped,
            activeDeviceID: "camera-1",
            currentOwnerID: "client-1",
            lastError: CameraStateError(message: "session failed")
        )
    )
    let router = makeRouter(sessionController: sessionController)
    let response = router.response(for: HTTPRequest(method: .get, path: "/v1/session"))

    #expect(response.statusCode == 200)
    #expect(
        String(decoding: response.body, as: UTF8.self) ==
        #"{"active_device_id":"camera-1","last_error":"session failed","owner_id":"client-1","state":"running"}"#
    )
}

@Test
func localHTTPServerReturnsSessionStateWithoutAuth() async throws {
    let port = try reserveEphemeralPort()
    let sessionController = makeSessionController(
        state: CameraState(
            permissionState: .restricted,
            sessionState: .stopped,
            previewState: .stopped,
            activeDeviceID: nil,
            currentOwnerID: nil,
            lastError: nil
        )
    )
    let server = LocalHTTPServer(
        configuration: .init(host: "127.0.0.1", port: port),
        router: makeRouter(sessionController: sessionController, permissionState: .restricted)
    )

    defer { server.stop() }

    let boundPort = try server.start()
    let url = try #require(URL(string: "http://127.0.0.1:\(boundPort)/v1/session"))
    let (data, response) = try await URLSession.shared.data(from: url)
    let httpResponse = try #require(response as? HTTPURLResponse)

    #expect(httpResponse.statusCode == 200)
    #expect(
        String(decoding: data, as: UTF8.self) ==
        #"{"active_device_id":null,"last_error":null,"owner_id":null,"state":"stopped"}"#
    )
}

@Test
func routerRejectsSessionStartWithoutBearerToken() {
    let sessionController = makeSessionController(
        state: CameraState(activeDeviceID: "camera-1")
    )
    let router = makeRouter(sessionController: sessionController)
    let response = router.response(
        for: HTTPRequest(
            method: .post,
            path: "/v1/session/start",
            body: Data(#"{"owner_id":"client-1"}"#.utf8)
        )
    )

    #expect(response.statusCode == 401)
    #expect(
        String(decoding: response.body, as: UTF8.self) ==
        #"{"error":{"code":"unauthorized","message":"Bearer token missing or invalid"}}"#
    )
}

@Test
func routerRejectsSessionStartWithoutOwnerID() {
    let sessionController = makeSessionController(
        state: CameraState(activeDeviceID: "camera-1")
    )
    let router = makeRouter(sessionController: sessionController)
    let response = router.response(
        for: HTTPRequest(
            method: .post,
            path: "/v1/session/start",
            headers: ["Authorization": "Bearer test-token"],
            body: Data(#"{"owner_id":" "}"#.utf8)
        )
    )

    #expect(response.statusCode == 400)
    #expect(
        String(decoding: response.body, as: UTF8.self) ==
        #"{"error":{"code":"invalid_request","message":"owner_id is required"}}"#
    )
}

@Test
func routerRejectsSessionStartWithoutSelectedDevice() {
    let sessionController = makeSessionController()
    let router = makeRouter(sessionController: sessionController)
    let response = router.response(
        for: HTTPRequest(
            method: .post,
            path: "/v1/session/start",
            headers: ["Authorization": "Bearer test-token"],
            body: Data(#"{"owner_id":"client-1"}"#.utf8)
        )
    )

    #expect(response.statusCode == 409)
    #expect(
        String(decoding: response.body, as: UTF8.self) ==
        #"{"error":{"code":"invalid_state","message":"Cannot start session without an active device"}}"#
    )
}

@Test
func routerRejectsSessionStartWithoutAuthorizedPermission() {
    let sessionController = makeSessionController(
        state: CameraState(activeDeviceID: "camera-1")
    )
    let router = makeRouter(sessionController: sessionController, permissionState: .denied)
    let response = router.response(
        for: HTTPRequest(
            method: .post,
            path: "/v1/session/start",
            headers: ["Authorization": "Bearer test-token"],
            body: Data(#"{"owner_id":"client-1"}"#.utf8)
        )
    )

    #expect(response.statusCode == 409)
    #expect(
        String(decoding: response.body, as: UTF8.self) ==
        #"{"error":{"code":"invalid_state","message":"Camera permission is denied"}}"#
    )
}

@Test
func routerReturnsRunningSessionForAuthorizedSessionStart() {
    let sessionController = makeSessionController(
        state: CameraState(activeDeviceID: "camera-1")
    )
    let router = makeRouter(sessionController: sessionController)
    let response = router.response(
        for: HTTPRequest(
            method: .post,
            path: "/v1/session/start",
            headers: ["Authorization": "Bearer test-token"],
            body: Data(#"{"owner_id":"client-1"}"#.utf8)
        )
    )

    #expect(response.statusCode == 200)
    #expect(
        String(decoding: response.body, as: UTF8.self) ==
        #"{"active_device_id":"camera-1","last_error":null,"owner_id":"client-1","state":"running"}"#
    )
    #expect(sessionController.currentCameraState().sessionState == .running)
    #expect(sessionController.currentCameraState().currentOwnerID == "client-1")
}

@Test
func routerRejectsSessionStopWithoutBearerToken() {
    let sessionController = makeSessionController(
        state: CameraState(
            permissionState: .authorized,
            sessionState: .running,
            previewState: .stopped,
            activeDeviceID: "camera-1",
            currentOwnerID: "client-1",
            lastError: nil
        )
    )
    let router = makeRouter(sessionController: sessionController)
    let response = router.response(
        for: HTTPRequest(
            method: .post,
            path: "/v1/session/stop",
            body: Data(#"{"owner_id":"client-1"}"#.utf8)
        )
    )

    #expect(response.statusCode == 401)
}

@Test
func routerRejectsSessionStopWhenAlreadyStopped() {
    let sessionController = makeSessionController()
    let router = makeRouter(sessionController: sessionController)
    let response = router.response(
        for: HTTPRequest(
            method: .post,
            path: "/v1/session/stop",
            headers: ["Authorization": "Bearer test-token"],
            body: Data(#"{"owner_id":"client-1"}"#.utf8)
        )
    )

    #expect(response.statusCode == 409)
    #expect(
        String(decoding: response.body, as: UTF8.self) ==
        #"{"error":{"code":"invalid_state","message":"Session is already stopped"}}"#
    )
}

@Test
func routerRejectsSessionStopForOwnerMismatch() {
    let sessionController = makeSessionController(
        state: CameraState(
            permissionState: .authorized,
            sessionState: .running,
            previewState: .stopped,
            activeDeviceID: "camera-1",
            currentOwnerID: "client-1",
            lastError: nil
        )
    )
    let router = makeRouter(sessionController: sessionController)
    let response = router.response(
        for: HTTPRequest(
            method: .post,
            path: "/v1/session/stop",
            headers: ["Authorization": "Bearer test-token"],
            body: Data(#"{"owner_id":"client-2"}"#.utf8)
        )
    )

    #expect(response.statusCode == 409)
    #expect(
        String(decoding: response.body, as: UTF8.self) ==
        #"{"error":{"code":"ownership_conflict","message":"Session is owned by client-1"}}"#
    )
}

@Test
func routerReturnsStoppedSessionForAuthorizedSessionStop() {
    let sessionController = makeSessionController(
        state: CameraState(
            permissionState: .authorized,
            sessionState: .running,
            previewState: .running,
            activeDeviceID: "camera-1",
            currentOwnerID: "client-1",
            lastError: nil
        )
    )
    let router = makeRouter(sessionController: sessionController)
    let response = router.response(
        for: HTTPRequest(
            method: .post,
            path: "/v1/session/stop",
            headers: ["Authorization": "Bearer test-token"],
            body: Data(#"{"owner_id":"client-1"}"#.utf8)
        )
    )

    #expect(response.statusCode == 200)
    #expect(
        String(decoding: response.body, as: UTF8.self) ==
        #"{"active_device_id":"camera-1","last_error":null,"owner_id":null,"state":"stopped"}"#
    )
    #expect(sessionController.currentCameraState().sessionState == .stopped)
    #expect(sessionController.currentCameraState().currentOwnerID == nil)
}

@Test
func routerRejectsDeviceSelectionWithoutBearerToken() {
    let sessionController = makeSessionController()
    let router = makeRouter(sessionController: sessionController)
    let response = router.response(
        for: HTTPRequest(
            method: .post,
            path: "/v1/session/select-device",
            body: Data(#"{"device_id":"camera-1"}"#.utf8)
        )
    )

    #expect(response.statusCode == 401)
    #expect(
        String(decoding: response.body, as: UTF8.self) ==
        #"{"error":{"code":"unauthorized","message":"Bearer token missing or invalid"}}"#
    )
    #expect(sessionController.currentCameraState().activeDeviceID == nil)
}

@Test
func routerRejectsDeviceSelectionWithMalformedRequestBody() {
    let sessionController = makeSessionController()
    let router = makeRouter(sessionController: sessionController)
    let response = router.response(
        for: HTTPRequest(
            method: .post,
            path: "/v1/session/select-device",
            headers: ["Authorization": "Bearer test-token"],
            body: Data("not-json".utf8)
        )
    )

    #expect(response.statusCode == 400)
    #expect(
        String(decoding: response.body, as: UTF8.self) ==
        #"{"error":{"code":"invalid_request","message":"Request body must be valid JSON"}}"#
    )
}

@Test
func routerRejectsDeviceSelectionForUnknownDevice() {
    let sessionController = makeSessionController(
        state: CameraState(activeDeviceID: "camera-1"),
        devices: [CameraDevice(id: "camera-1", name: "Built-in Camera", position: .front)]
    )
    let router = makeRouter(sessionController: sessionController)
    let response = router.response(
        for: HTTPRequest(
            method: .post,
            path: "/v1/session/select-device",
            headers: ["Authorization": "Bearer test-token"],
            body: Data(#"{"device_id":"camera-2"}"#.utf8)
        )
    )

    #expect(response.statusCode == 409)
    #expect(
        String(decoding: response.body, as: UTF8.self) ==
        #"{"error":{"code":"invalid_state","message":"Requested device is unavailable: camera-2"}}"#
    )
    #expect(sessionController.currentCameraState().activeDeviceID == "camera-1")
}

@Test
func routerRejectsDeviceSelectionForOwnerMismatch() {
    let sessionController = makeSessionController(
        state: CameraState(
            permissionState: .authorized,
            sessionState: .running,
            previewState: .stopped,
            activeDeviceID: "camera-1",
            currentOwnerID: "client-1",
            lastError: nil
        ),
        devices: [
            CameraDevice(id: "camera-1", name: "Built-in Camera", position: .front),
            CameraDevice(id: "camera-2", name: "Desk Camera", position: .external),
        ]
    )
    let router = makeRouter(sessionController: sessionController)
    let response = router.response(
        for: HTTPRequest(
            method: .post,
            path: "/v1/session/select-device",
            headers: ["Authorization": "Bearer test-token"],
            body: Data(#"{"device_id":"camera-2","owner_id":"client-2"}"#.utf8)
        )
    )

    #expect(response.statusCode == 409)
    #expect(
        String(decoding: response.body, as: UTF8.self) ==
        #"{"error":{"code":"ownership_conflict","message":"Session is owned by client-1"}}"#
    )
    #expect(sessionController.currentCameraState().activeDeviceID == "camera-1")
}

@Test
func routerReturnsUpdatedSessionStateForAuthorizedDeviceSelection() {
    let sessionController = makeSessionController(
        devices: [
            CameraDevice(id: "camera-1", name: "Built-in Camera", position: .front),
            CameraDevice(id: "camera-2", name: "Desk Camera", position: .external),
        ]
    )
    let router = makeRouter(sessionController: sessionController)
    let response = router.response(
        for: HTTPRequest(
            method: .post,
            path: "/v1/session/select-device",
            headers: ["Authorization": "Bearer test-token"],
            body: Data(#"{"device_id":"camera-2"}"#.utf8)
        )
    )

    #expect(response.statusCode == 200)
    #expect(
        String(decoding: response.body, as: UTF8.self) ==
        #"{"active_device_id":"camera-2","last_error":null,"owner_id":null,"state":"stopped"}"#
    )
    #expect(sessionController.currentCameraState().activeDeviceID == "camera-2")
}

@Test
func routerRejectsPhotoCaptureWithoutBearerToken() {
    let sessionController = makeSessionController(
        state: CameraState(
            permissionState: .authorized,
            sessionState: .running,
            previewState: .stopped,
            activeDeviceID: "camera-1",
            currentOwnerID: "client-1",
            lastError: nil
        )
    )
    let router = makeRouter(sessionController: sessionController)
    let response = router.response(
        for: HTTPRequest(
            method: .post,
            path: "/v1/capture/photo",
            body: Data(#"{"owner_id":"client-1"}"#.utf8)
        )
    )

    #expect(response.statusCode == 401)
    #expect(
        String(decoding: response.body, as: UTF8.self) ==
        #"{"error":{"code":"unauthorized","message":"Bearer token missing or invalid"}}"#
    )
}

@Test
func routerRejectsPhotoCaptureWhenSessionIsStopped() {
    let sessionController = makeSessionController(
        state: CameraState(
            permissionState: .authorized,
            sessionState: .stopped,
            previewState: .stopped,
            activeDeviceID: "camera-1",
            currentOwnerID: "client-1",
            lastError: nil
        )
    )
    let router = makeRouter(sessionController: sessionController)
    let response = router.response(
        for: HTTPRequest(
            method: .post,
            path: "/v1/capture/photo",
            headers: ["Authorization": "Bearer test-token"],
            body: Data(#"{"owner_id":"client-1"}"#.utf8)
        )
    )

    #expect(response.statusCode == 409)
    #expect(
        String(decoding: response.body, as: UTF8.self) ==
        #"{"error":{"code":"invalid_state","message":"Session is not running"}}"#
    )
}

@Test
func routerRejectsPhotoCaptureForOwnerMismatch() {
    let sessionController = makeSessionController(
        state: CameraState(
            permissionState: .authorized,
            sessionState: .running,
            previewState: .stopped,
            activeDeviceID: "camera-1",
            currentOwnerID: "client-1",
            lastError: nil
        )
    )
    let router = makeRouter(sessionController: sessionController)
    let response = router.response(
        for: HTTPRequest(
            method: .post,
            path: "/v1/capture/photo",
            headers: ["Authorization": "Bearer test-token"],
            body: Data(#"{"owner_id":"client-2"}"#.utf8)
        )
    )

    #expect(response.statusCode == 409)
    #expect(
        String(decoding: response.body, as: UTF8.self) ==
        #"{"error":{"code":"ownership_conflict","message":"Session is owned by client-1"}}"#
    )
}

@Test
func routerReturnsPhotoCaptureMetadataForAuthorizedOwner() throws {
    let directoryURL = makeTemporaryDirectory()
    let capturedAt = Date(timeIntervalSince1970: 1_710_000_000.123)
    let sessionController = makeSessionController(
        state: CameraState(
            permissionState: .authorized,
            sessionState: .running,
            previewState: .stopped,
            activeDeviceID: "camera-1",
            currentOwnerID: "client-1",
            lastError: nil
        ),
        photoProducer: FixedStillPhotoProducer(data: Data([0x01, 0x02, 0x03])),
        artifactStore: DefaultPhotoArtifactStore(baseDirectoryURL: directoryURL),
        now: { capturedAt }
    )
    let router = makeRouter(sessionController: sessionController)
    let response = router.response(
        for: HTTPRequest(
            method: .post,
            path: "/v1/capture/photo",
            headers: ["Authorization": "Bearer test-token"],
            body: Data(#"{"owner_id":"client-1"}"#.utf8)
        )
    )

    #expect(response.statusCode == 200)

    let payload = try #require(
        JSONSerialization.jsonObject(with: response.body) as? [String: String]
    )
    let localPath = try #require(payload["local_path"])
    #expect(payload["device_id"] == "camera-1")
    #expect(payload["captured_at"] == "2024-03-09T16:00:00.123Z")
    #expect(localPath.hasPrefix(directoryURL.path))
    #expect(localPath.hasSuffix(".jpg"))
    #expect(FileManager.default.fileExists(atPath: localPath))
}

@Test
func localHTTPServerReturnsUpdatedSessionStateForAuthorizedDeviceSelection() async throws {
    let port = try reserveEphemeralPort()
    let sessionController = makeSessionController(
        devices: [
            CameraDevice(id: "camera-1", name: "Built-in Camera", position: .front),
            CameraDevice(id: "camera-2", name: "Desk Camera", position: .external),
        ]
    )
    let server = LocalHTTPServer(
        configuration: .init(host: "127.0.0.1", port: port),
        router: makeRouter(sessionController: sessionController)
    )

    defer { server.stop() }

    let boundPort = try server.start()
    var request = URLRequest(
        url: try #require(URL(string: "http://127.0.0.1:\(boundPort)/v1/session/select-device"))
    )
    request.httpMethod = "POST"
    request.httpBody = Data(#"{"device_id":"camera-2"}"#.utf8)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer test-token", forHTTPHeaderField: "Authorization")
    let (data, response) = try await URLSession.shared.data(for: request)
    let httpResponse = try #require(response as? HTTPURLResponse)

    #expect(httpResponse.statusCode == 200)
    #expect(
        String(decoding: data, as: UTF8.self) ==
        #"{"active_device_id":"camera-2","last_error":null,"owner_id":null,"state":"stopped"}"#
    )
    #expect(sessionController.currentCameraState().activeDeviceID == "camera-2")
}

@Test
func localHTTPServerSupportsSessionStartThenStop() async throws {
    let port = try reserveEphemeralPort()
    let sessionController = makeSessionController(
        state: CameraState(activeDeviceID: "camera-1")
    )
    let server = LocalHTTPServer(
        configuration: .init(host: "127.0.0.1", port: port),
        router: makeRouter(sessionController: sessionController)
    )

    defer { server.stop() }

    let boundPort = try server.start()

    var startRequest = URLRequest(
        url: try #require(URL(string: "http://127.0.0.1:\(boundPort)/v1/session/start"))
    )
    startRequest.httpMethod = "POST"
    startRequest.httpBody = Data(#"{"owner_id":"client-1"}"#.utf8)
    startRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    startRequest.setValue("Bearer test-token", forHTTPHeaderField: "Authorization")
    let (startData, startResponse) = try await URLSession.shared.data(for: startRequest)
    let startHTTPResponse = try #require(startResponse as? HTTPURLResponse)

    #expect(startHTTPResponse.statusCode == 200)
    #expect(
        String(decoding: startData, as: UTF8.self) ==
        #"{"active_device_id":"camera-1","last_error":null,"owner_id":"client-1","state":"running"}"#
    )

    var stopRequest = URLRequest(
        url: try #require(URL(string: "http://127.0.0.1:\(boundPort)/v1/session/stop"))
    )
    stopRequest.httpMethod = "POST"
    stopRequest.httpBody = Data(#"{"owner_id":"client-1"}"#.utf8)
    stopRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    stopRequest.setValue("Bearer test-token", forHTTPHeaderField: "Authorization")
    let (stopData, stopResponse) = try await URLSession.shared.data(for: stopRequest)
    let stopHTTPResponse = try #require(stopResponse as? HTTPURLResponse)

    #expect(stopHTTPResponse.statusCode == 200)
    #expect(
        String(decoding: stopData, as: UTF8.self) ==
        #"{"active_device_id":"camera-1","last_error":null,"owner_id":null,"state":"stopped"}"#
    )
}

private func makeRouter(
    sessionController: DefaultCameraSessionController,
    permissionState: PermissionState = .authorized,
    permissionRequester: any CameraPermissionRequesting = FixedPermissionRequester(
        result: .init(status: .authorized, prompted: false)
    ),
    bearerToken: String = "test-token"
) -> CameraBridgeRouter {
    CameraBridgeRouter(
        routes: CameraBridgeRoutes.current(
            permissionStatusProvider: FixedPermissionStatusProvider(state: permissionState),
            permissionRequester: permissionRequester,
            deviceListing: sessionController,
            cameraStateProvider: sessionController,
            deviceSelector: sessionController,
            sessionStarter: sessionController,
            sessionStopper: sessionController,
            photoCapturer: sessionController,
            authorizer: StaticBearerTokenAuthorizer(bearerToken: bearerToken)
        )
    )
}

private func makeSessionController(
    state: CameraState = CameraState(),
    devices: [CameraDevice] = [
        CameraDevice(id: "camera-1", name: "Built-in Camera", position: .front),
    ],
    photoProducer: any CameraStillPhotoProducing = UnimplementedStillPhotoProducer(),
    artifactStore: any PhotoArtifactStoring = DefaultPhotoArtifactStore(
        baseDirectoryURL: URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("CameraBridgeAPITests", isDirectory: true)
    ),
    now: @escaping @Sendable () -> Date = { Date() }
) -> DefaultCameraSessionController {
    DefaultCameraSessionController(
        deviceListing: FixedDeviceListing(devices: devices),
        photoProducer: photoProducer,
        artifactStore: artifactStore,
        now: now,
        initialState: state
    )
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

private final class RecordingPermissionRequester: CameraPermissionRequesting, @unchecked Sendable {
    private(set) var requestCount = 0
    let result: PermissionRequestResult

    init(result: PermissionRequestResult) {
        self.result = result
    }

    func requestPermission(completion: @escaping @Sendable (PermissionRequestResult) -> Void) {
        requestCount += 1
        completion(result)
    }
}

private struct FixedDeviceListing: CameraDeviceListing {
    let devices: [CameraDevice]

    func availableDevices() -> [CameraDevice] {
        devices
    }
}

private struct FixedStillPhotoProducer: CameraStillPhotoProducing {
    let data: Data

    func capturePhotoData(deviceID: String) throws -> Data {
        data
    }
}

private func makeTemporaryDirectory() -> URL {
    let directoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("CameraBridgeAPITests-\(UUID().uuidString)", isDirectory: true)
    try! FileManager.default.createDirectory(
        at: directoryURL,
        withIntermediateDirectories: true,
        attributes: nil
    )
    return directoryURL
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

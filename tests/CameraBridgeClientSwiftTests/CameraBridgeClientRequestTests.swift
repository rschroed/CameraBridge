import Foundation
import Testing
@testable import CameraBridgeClientSwift

private struct RecordedRequest: Sendable, Equatable {
    var method: String?
    var url: String?
    var authorization: String?
    var contentType: String?
    var body: Data?
}

private actor RequestRecorder {
    private var request: RecordedRequest?

    func record(_ request: URLRequest) {
        self.request = RecordedRequest(
            method: request.httpMethod,
            url: request.url?.absoluteString,
            authorization: request.value(forHTTPHeaderField: "Authorization"),
            contentType: request.value(forHTTPHeaderField: "Content-Type"),
            body: request.httpBody
        )
    }

    func currentRequest() -> RecordedRequest? {
        request
    }
}

@Test
func permissionStatusUsesReadOnlyRequestShape() async throws {
    let recorder = RequestRecorder()
    let client = CameraBridgeClient(
        transport: { request in
            await recorder.record(request)
            return (
                Data(#"{"status":"authorized"}"#.utf8),
                makeHTTPResponse(for: request, statusCode: 200)
            )
        }
    )

    let status = try await client.permissionStatus()
    let recordedRequest = await recorder.currentRequest()

    #expect(status == .authorized)
    #expect(recordedRequest?.method == "GET")
    #expect(recordedRequest?.url == "http://127.0.0.1:8731/v1/permissions")
    #expect(recordedRequest?.authorization == nil)
    #expect(recordedRequest?.body == nil)
}

@Test
func permissionRequestSendsBearerTokenAndEmptyJSONBody() async throws {
    let recorder = RequestRecorder()
    let client = CameraBridgeClient(
        tokenProvider: { "test-token" },
        transport: { request in
            await recorder.record(request)
            return (
                Data(#"{"prompted":true,"status":"not_determined"}"#.utf8),
                makeHTTPResponse(for: request, statusCode: 200)
            )
        }
    )

    let result = try await client.requestPermission()
    let recordedRequest = await recorder.currentRequest()

    #expect(result == .init(status: .notDetermined, prompted: true))
    #expect(recordedRequest?.method == "POST")
    #expect(recordedRequest?.url == "http://127.0.0.1:8731/v1/permissions/request")
    #expect(recordedRequest?.authorization == "Bearer test-token")
    #expect(recordedRequest?.contentType == "application/json")
    #expect(recordedRequest?.body == Data("{}".utf8))
}

@Test
func permissionRequestSurfacesAPIErrorDetails() async {
    let client = CameraBridgeClient(
        tokenProvider: { nil },
        transport: { request in
            (
                Data(#"{"error":{"code":"unauthorized","message":"Bearer token missing or invalid"}}"#.utf8),
                makeHTTPResponse(for: request, statusCode: 401)
            )
        }
    )

    await #expect(throws: CameraBridgeClientError.requestFailed(
        statusCode: 401,
        code: "unauthorized",
        message: "Bearer token missing or invalid"
    )) {
        _ = try await client.requestPermission()
    }
}

@Test
func devicesUsesReadOnlyRequestShapeAndParsesDevices() async throws {
    let recorder = RequestRecorder()
    let client = CameraBridgeClient(
        transport: { request in
            await recorder.record(request)
            return (
                Data(#"{"devices":[{"id":"camera-1","name":"Built-in Camera","position":"front"}]}"#.utf8),
                makeHTTPResponse(for: request, statusCode: 200)
            )
        }
    )

    let devices = try await client.devices()
    let recordedRequest = await recorder.currentRequest()

    #expect(devices == [.init(id: "camera-1", name: "Built-in Camera", position: .front)])
    #expect(recordedRequest?.method == "GET")
    #expect(recordedRequest?.url == "http://127.0.0.1:8731/v1/devices")
    #expect(recordedRequest?.authorization == nil)
    #expect(recordedRequest?.body == nil)
}

@Test
func devicesSurfacesInvalidDevicePosition() async {
    let client = CameraBridgeClient(
        transport: { request in
            (
                Data(#"{"devices":[{"id":"camera-1","name":"Built-in Camera","position":"sideways"}]}"#.utf8),
                makeHTTPResponse(for: request, statusCode: 200)
            )
        }
    )

    await #expect(throws: CameraBridgeClientError.invalidStatus("sideways")) {
        _ = try await client.devices()
    }
}

@Test
func sessionStateUsesReadOnlyRequestShapeAndParsesSessionSnapshot() async throws {
    let recorder = RequestRecorder()
    let client = CameraBridgeClient(
        transport: { request in
            await recorder.record(request)
            return (
                Data(#"{"state":"running","active_device_id":"camera-1","owner_id":"client-1","last_error":null}"#.utf8),
                makeHTTPResponse(for: request, statusCode: 200)
            )
        }
    )

    let snapshot = try await client.sessionState()
    let recordedRequest = await recorder.currentRequest()

    #expect(snapshot == .init(
        state: .running,
        activeDeviceID: "camera-1",
        ownerID: "client-1",
        lastError: nil
    ))
    #expect(recordedRequest?.method == "GET")
    #expect(recordedRequest?.url == "http://127.0.0.1:8731/v1/session")
    #expect(recordedRequest?.authorization == nil)
    #expect(recordedRequest?.body == nil)
}

@Test
func sessionStateSurfacesInvalidSessionState() async {
    let client = CameraBridgeClient(
        transport: { request in
            (
                Data(#"{"state":"paused","active_device_id":null,"owner_id":null,"last_error":null}"#.utf8),
                makeHTTPResponse(for: request, statusCode: 200)
            )
        }
    )

    await #expect(throws: CameraBridgeClientError.invalidStatus("paused")) {
        _ = try await client.sessionState()
    }
}

@Test
func selectDeviceSendsBearerTokenAndSelectionPayload() async throws {
    let recorder = RequestRecorder()
    let client = CameraBridgeClient(
        tokenProvider: { "test-token" },
        transport: { request in
            await recorder.record(request)
            return (
                Data(#"{"state":"stopped","active_device_id":"camera-1","owner_id":"client-1","last_error":null}"#.utf8),
                makeHTTPResponse(for: request, statusCode: 200)
            )
        }
    )

    let snapshot = try await client.selectDevice(deviceID: "camera-1", ownerID: "client-1")
    let recordedRequest = await recorder.currentRequest()

    #expect(snapshot == .init(
        state: .stopped,
        activeDeviceID: "camera-1",
        ownerID: "client-1",
        lastError: nil
    ))
    #expect(recordedRequest?.method == "POST")
    #expect(recordedRequest?.url == "http://127.0.0.1:8731/v1/session/select-device")
    #expect(recordedRequest?.authorization == "Bearer test-token")
    #expect(recordedRequest?.contentType == "application/json")
    #expect(recordedRequest?.body == Data(#"{"device_id":"camera-1","owner_id":"client-1"}"#.utf8))
}

@Test
func startSessionSendsBearerTokenAndOwnerPayload() async throws {
    let recorder = RequestRecorder()
    let client = CameraBridgeClient(
        tokenProvider: { "test-token" },
        transport: { request in
            await recorder.record(request)
            return (
                Data(#"{"state":"running","active_device_id":"camera-1","owner_id":"client-1","last_error":null}"#.utf8),
                makeHTTPResponse(for: request, statusCode: 200)
            )
        }
    )

    let snapshot = try await client.startSession(ownerID: "client-1")
    let recordedRequest = await recorder.currentRequest()

    #expect(snapshot == .init(
        state: .running,
        activeDeviceID: "camera-1",
        ownerID: "client-1",
        lastError: nil
    ))
    #expect(recordedRequest?.method == "POST")
    #expect(recordedRequest?.url == "http://127.0.0.1:8731/v1/session/start")
    #expect(recordedRequest?.authorization == "Bearer test-token")
    #expect(recordedRequest?.contentType == "application/json")
    #expect(recordedRequest?.body == Data(#"{"owner_id":"client-1"}"#.utf8))
}

@Test
func stopSessionSendsBearerTokenAndOwnerPayload() async throws {
    let recorder = RequestRecorder()
    let client = CameraBridgeClient(
        tokenProvider: { "test-token" },
        transport: { request in
            await recorder.record(request)
            return (
                Data(#"{"state":"stopped","active_device_id":"camera-1","owner_id":null,"last_error":null}"#.utf8),
                makeHTTPResponse(for: request, statusCode: 200)
            )
        }
    )

    let snapshot = try await client.stopSession(ownerID: "client-1")
    let recordedRequest = await recorder.currentRequest()

    #expect(snapshot == .init(
        state: .stopped,
        activeDeviceID: "camera-1",
        ownerID: nil,
        lastError: nil
    ))
    #expect(recordedRequest?.method == "POST")
    #expect(recordedRequest?.url == "http://127.0.0.1:8731/v1/session/stop")
    #expect(recordedRequest?.authorization == "Bearer test-token")
    #expect(recordedRequest?.contentType == "application/json")
    #expect(recordedRequest?.body == Data(#"{"owner_id":"client-1"}"#.utf8))
}

@Test
func stopSessionSurfacesAPIErrorDetails() async {
    let client = CameraBridgeClient(
        tokenProvider: { "test-token" },
        transport: { request in
            (
                Data(#"{"error":{"code":"ownership_conflict","message":"Session is owned by client-2"}}"#.utf8),
                makeHTTPResponse(for: request, statusCode: 409)
            )
        }
    )

    await #expect(throws: CameraBridgeClientError.requestFailed(
        statusCode: 409,
        code: "ownership_conflict",
        message: "Session is owned by client-2"
    )) {
        _ = try await client.stopSession(ownerID: "client-1")
    }
}

@Test
func capturePhotoSendsBearerTokenAndParsesArtifactMetadata() async throws {
    let capturedAt = makeFractionalSecondISO8601Formatter().date(from: "2024-03-09T16:00:00.123Z")!
    let recorder = RequestRecorder()
    let client = CameraBridgeClient(
        tokenProvider: { "test-token" },
        transport: { request in
            await recorder.record(request)
            return (
                Data(#"{"local_path":"/tmp/capture.jpg","captured_at":"2024-03-09T16:00:00.123Z","device_id":"camera-1"}"#.utf8),
                makeHTTPResponse(for: request, statusCode: 200)
            )
        }
    )

    let artifact = try await client.capturePhoto(ownerID: "client-1")
    let recordedRequest = await recorder.currentRequest()

    #expect(artifact == .init(
        localPath: "/tmp/capture.jpg",
        capturedAt: capturedAt,
        deviceID: "camera-1"
    ))
    #expect(recordedRequest?.method == "POST")
    #expect(recordedRequest?.url == "http://127.0.0.1:8731/v1/capture/photo")
    #expect(recordedRequest?.authorization == "Bearer test-token")
    #expect(recordedRequest?.contentType == "application/json")
    #expect(recordedRequest?.body == Data(#"{"owner_id":"client-1"}"#.utf8))
}

@Test
func capturePhotoSurfacesInvalidTimestampResponse() async {
    let client = CameraBridgeClient(
        tokenProvider: { "test-token" },
        transport: { request in
            (
                Data(#"{"local_path":"/tmp/capture.jpg","captured_at":"not-a-date","device_id":"camera-1"}"#.utf8),
                makeHTTPResponse(for: request, statusCode: 200)
            )
        }
    )

    await #expect(throws: CameraBridgeClientError.invalidResponse) {
        _ = try await client.capturePhoto(ownerID: "client-1")
    }
}

private func makeHTTPResponse(for request: URLRequest, statusCode: Int) -> HTTPURLResponse {
    HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
}

private func makeFractionalSecondISO8601Formatter() -> ISO8601DateFormatter {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
}

import CameraBridgeAPI
import Foundation

public enum CameraBridgePermissionStatus: String, Sendable, CaseIterable, Equatable {
    case notDetermined = "not_determined"
    case restricted
    case denied
    case authorized
}

public struct CameraBridgePermissionRequestResult: Sendable, Equatable {
    public var status: CameraBridgePermissionStatus
    public var prompted: Bool

    public init(status: CameraBridgePermissionStatus, prompted: Bool) {
        self.status = status
        self.prompted = prompted
    }
}

public enum CameraBridgeDevicePosition: String, Sendable, CaseIterable, Equatable {
    case front
    case back
    case external
}

public struct CameraBridgeDevice: Sendable, Equatable {
    public var id: String
    public var name: String
    public var position: CameraBridgeDevicePosition

    public init(id: String, name: String, position: CameraBridgeDevicePosition) {
        self.id = id
        self.name = name
        self.position = position
    }
}

public enum CameraBridgeSessionState: String, Sendable, CaseIterable, Equatable {
    case stopped
    case running
}

public struct CameraBridgeSessionSnapshot: Sendable, Equatable {
    public var state: CameraBridgeSessionState
    public var activeDeviceID: String?
    public var ownerID: String?
    public var lastError: String?

    public init(
        state: CameraBridgeSessionState,
        activeDeviceID: String?,
        ownerID: String?,
        lastError: String?
    ) {
        self.state = state
        self.activeDeviceID = activeDeviceID
        self.ownerID = ownerID
        self.lastError = lastError
    }
}

public struct CameraBridgeCapturedPhotoArtifact: Sendable, Equatable {
    public var localPath: String
    public var capturedAt: Date
    public var deviceID: String

    public init(localPath: String, capturedAt: Date, deviceID: String) {
        self.localPath = localPath
        self.capturedAt = capturedAt
        self.deviceID = deviceID
    }
}

public struct CameraBridgeHealthResponse: Sendable, Equatable, Decodable {
    public var status: String

    public init(status: String) {
        self.status = status
    }
}

public enum CameraBridgeClientError: Error, Sendable, Equatable {
    case invalidResponse
    case invalidStatus(String)
    case requestFailed(statusCode: Int, code: String?, message: String?)
}

public struct CameraBridgeClient {
    public typealias TokenProvider = @Sendable () -> String?
    public typealias Transport = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

    public var baseURL: URL
    public var apiModuleName: String {
        CameraBridgeAPIModule.name
    }

    private let tokenProvider: TokenProvider
    private let transport: Transport

    public init(
        baseURL: URL = URL(string: "http://127.0.0.1:8731")!,
        tokenProvider: @escaping TokenProvider = { nil },
        transport: Transport? = nil
    ) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        self.transport = transport ?? { request in
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CameraBridgeClientError.invalidResponse
            }
            return (data, httpResponse)
        }
    }

    public func health() async throws -> CameraBridgeHealthResponse {
        try await send(method: "GET", path: "/health", requiresAuthorization: false)
    }

    public func serviceIsRunning() async -> Bool {
        guard let response = try? await health() else {
            return false
        }

        return response.status == "ok"
    }

    public func permissionStatus() async throws -> CameraBridgePermissionStatus {
        let response: PermissionStatusResponse = try await send(
            method: "GET",
            path: "/v1/permissions",
            requiresAuthorization: false
        )
        guard let status = CameraBridgePermissionStatus(rawValue: response.status) else {
            throw CameraBridgeClientError.invalidStatus(response.status)
        }

        return status
    }

    public func requestPermission() async throws -> CameraBridgePermissionRequestResult {
        let response: PermissionRequestResponse = try await send(
            method: "POST",
            path: "/v1/permissions/request",
            requiresAuthorization: true,
            requestBody: EmptyRequest()
        )
        guard let status = CameraBridgePermissionStatus(rawValue: response.status) else {
            throw CameraBridgeClientError.invalidStatus(response.status)
        }

        return CameraBridgePermissionRequestResult(status: status, prompted: response.prompted)
    }

    public func devices() async throws -> [CameraBridgeDevice] {
        let response: DevicesResponse = try await send(
            method: "GET",
            path: "/v1/devices",
            requiresAuthorization: false
        )

        return try response.devices.map { device in
            guard let position = CameraBridgeDevicePosition(rawValue: device.position) else {
                throw CameraBridgeClientError.invalidStatus(device.position)
            }

            return CameraBridgeDevice(id: device.id, name: device.name, position: position)
        }
    }

    public func sessionState() async throws -> CameraBridgeSessionSnapshot {
        let response: SessionStateResponse = try await send(
            method: "GET",
            path: "/v1/session",
            requiresAuthorization: false
        )
        return try makeSessionSnapshot(from: response)
    }

    public func selectDevice(deviceID: String, ownerID: String?) async throws -> CameraBridgeSessionSnapshot {
        let response: SessionStateResponse = try await send(
            method: "POST",
            path: "/v1/session/select-device",
            requiresAuthorization: true,
            requestBody: DeviceSelectionRequest(deviceID: deviceID, ownerID: ownerID)
        )
        return try makeSessionSnapshot(from: response)
    }

    public func startSession(ownerID: String) async throws -> CameraBridgeSessionSnapshot {
        let response: SessionStateResponse = try await send(
            method: "POST",
            path: "/v1/session/start",
            requiresAuthorization: true,
            requestBody: SessionOwnerRequest(ownerID: ownerID)
        )
        return try makeSessionSnapshot(from: response)
    }

    public func stopSession(ownerID: String) async throws -> CameraBridgeSessionSnapshot {
        let response: SessionStateResponse = try await send(
            method: "POST",
            path: "/v1/session/stop",
            requiresAuthorization: true,
            requestBody: SessionOwnerRequest(ownerID: ownerID)
        )
        return try makeSessionSnapshot(from: response)
    }

    public func capturePhoto(ownerID: String) async throws -> CameraBridgeCapturedPhotoArtifact {
        let response: PhotoCaptureResponse = try await send(
            method: "POST",
            path: "/v1/capture/photo",
            requiresAuthorization: true,
            requestBody: SessionOwnerRequest(ownerID: ownerID)
        )
        guard let capturedAt = iso8601DateFormatter.date(from: response.capturedAt) else {
            throw CameraBridgeClientError.invalidResponse
        }

        return CameraBridgeCapturedPhotoArtifact(
            localPath: response.localPath,
            capturedAt: capturedAt,
            deviceID: response.deviceID
        )
    }

    private func send<Response: Decodable>(
        method: String,
        path: String,
        requiresAuthorization: Bool
    ) async throws -> Response {
        try await send(
            method: method,
            path: path,
            requiresAuthorization: requiresAuthorization,
            requestBody: Optional<EmptyRequest>.none
        )
    }

    private func send<Response: Decodable, Request: Encodable>(
        method: String,
        path: String,
        requiresAuthorization: Bool,
        requestBody: Request? = nil
    ) async throws -> Response {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let requestBody {
            request.httpBody = try JSONEncoder().encode(requestBody)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        if requiresAuthorization, let token = tokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await transport(request)
        guard (200..<300).contains(response.statusCode) else {
            let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            throw CameraBridgeClientError.requestFailed(
                statusCode: response.statusCode,
                code: errorResponse?.error.code,
                message: errorResponse?.error.message
            )
        }

        return try JSONDecoder().decode(Response.self, from: data)
    }

    private func makeSessionSnapshot(from response: SessionStateResponse) throws -> CameraBridgeSessionSnapshot {
        guard let state = CameraBridgeSessionState(rawValue: response.state) else {
            throw CameraBridgeClientError.invalidStatus(response.state)
        }

        return CameraBridgeSessionSnapshot(
            state: state,
            activeDeviceID: response.activeDeviceID,
            ownerID: response.ownerID,
            lastError: response.lastError
        )
    }
}

private struct EmptyRequest: Encodable {}

private struct SessionOwnerRequest: Encodable {
    var ownerID: String

    enum CodingKeys: String, CodingKey {
        case ownerID = "owner_id"
    }
}

private struct DeviceSelectionRequest: Encodable {
    var deviceID: String
    var ownerID: String?

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case ownerID = "owner_id"
    }
}

private struct PermissionStatusResponse: Decodable {
    var status: String
}

private struct PermissionRequestResponse: Decodable {
    var status: String
    var prompted: Bool
}

private struct DevicesResponse: Decodable {
    var devices: [DeviceResponse]
}

private struct DeviceResponse: Decodable {
    var id: String
    var name: String
    var position: String
}

private struct SessionStateResponse: Decodable {
    var state: String
    var activeDeviceID: String?
    var ownerID: String?
    var lastError: String?

    enum CodingKeys: String, CodingKey {
        case state
        case activeDeviceID = "active_device_id"
        case ownerID = "owner_id"
        case lastError = "last_error"
    }
}

private struct PhotoCaptureResponse: Decodable {
    var localPath: String
    var capturedAt: String
    var deviceID: String

    enum CodingKeys: String, CodingKey {
        case localPath = "local_path"
        case capturedAt = "captured_at"
        case deviceID = "device_id"
    }
}

private struct APIErrorResponse: Decodable {
    var error: APIError
}

private struct APIError: Decodable {
    var code: String
    var message: String
}

private let iso8601DateFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
}()

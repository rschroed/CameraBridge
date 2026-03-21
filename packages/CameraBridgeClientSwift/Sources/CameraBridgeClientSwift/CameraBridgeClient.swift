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
}

private struct EmptyRequest: Encodable {}

private struct PermissionStatusResponse: Decodable {
    var status: String
}

private struct PermissionRequestResponse: Decodable {
    var status: String
    var prompted: Bool
}

private struct APIErrorResponse: Decodable {
    var error: APIError
}

private struct APIError: Decodable {
    var code: String
    var message: String
}

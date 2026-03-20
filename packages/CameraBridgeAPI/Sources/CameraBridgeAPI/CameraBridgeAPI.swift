import CameraBridgeCore
import Dispatch
import Foundation
import Network

public enum CameraBridgeAPIModule {
    public static let name = "CameraBridgeAPI"
    public static let coreModuleName = CameraBridgeCoreModule.name
}

public enum HTTPMethod: String, Sendable, Equatable {
    case get = "GET"
    case post = "POST"
}

public struct HTTPRequest: Sendable, Equatable {
    public var method: HTTPMethod
    public var path: String
    public var headers: [String: String]
    public var body: Data

    public init(method: HTTPMethod, path: String, headers: [String: String] = [:], body: Data = Data()) {
        self.method = method
        self.path = path
        self.headers = headers
        self.body = body
    }
}

public struct HTTPResponse: Sendable, Equatable {
    public var statusCode: Int
    public var headers: [String: String]
    public var body: Data

    public init(statusCode: Int, headers: [String: String] = [:], body: Data = Data()) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }

    public static func json(statusCode: Int, body: String) -> HTTPResponse {
        HTTPResponse(
            statusCode: statusCode,
            headers: ["Content-Type": "application/json"],
            body: Data(body.utf8)
        )
    }

    public static func json<T: Encodable>(statusCode: Int, body: T) -> HTTPResponse {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try! encoder.encode(body)
        return HTTPResponse(
            statusCode: statusCode,
            headers: ["Content-Type": "application/json"],
            body: data
        )
    }

    public static func error(statusCode: Int, code: String, message: String) -> HTTPResponse {
        .json(statusCode: statusCode, body: ErrorResponse(error: .init(code: code, message: message)))
    }

    public static func notFound() -> HTTPResponse {
        .error(statusCode: 404, code: "not_found", message: "Route not found")
    }

    public static func badRequest(code: String = "invalid_request", message: String) -> HTTPResponse {
        .error(statusCode: 400, code: code, message: message)
    }

    public static func unauthorized() -> HTTPResponse {
        .error(statusCode: 401, code: "unauthorized", message: "Bearer token missing or invalid")
    }
}

public protocol BearerTokenAuthorizing: Sendable {
    func isAuthorized(request: HTTPRequest) -> Bool
}

public struct StaticBearerTokenAuthorizer: BearerTokenAuthorizing {
    public var bearerToken: String?

    public init(bearerToken: String?) {
        self.bearerToken = bearerToken
    }

    public func isAuthorized(request: HTTPRequest) -> Bool {
        guard let bearerToken, !bearerToken.isEmpty else {
            return false
        }

        return request.authorizationBearerToken == bearerToken
    }
}

public struct HTTPRoute: Sendable {
    public typealias Handler = @Sendable (HTTPRequest) -> HTTPResponse

    public var method: HTTPMethod
    public var path: String
    private let handler: Handler

    public init(method: HTTPMethod, path: String, handler: @escaping Handler) {
        self.method = method
        self.path = path
        self.handler = handler
    }

    fileprivate func respond(to request: HTTPRequest) -> HTTPResponse {
        handler(request)
    }
}

public struct CameraBridgeRouter: Sendable {
    private var routes: [RouteKey: HTTPRoute]

    public init(routes: [HTTPRoute] = []) {
        self.routes = Dictionary(
            uniqueKeysWithValues: routes.map { (RouteKey(method: $0.method, path: $0.path), $0) }
        )
    }

    public func response(for request: HTTPRequest) -> HTTPResponse {
        let key = RouteKey(method: request.method, path: request.path)
        guard let route = routes[key] else {
            return .notFound()
        }

        return route.respond(to: request)
    }
}

public enum CameraBridgeRoutes {
    public static func current(
        permissionStatusProvider: any CameraPermissionStatusProviding,
        cameraStateProvider: any CameraStateProviding,
        deviceSelector: any CameraDeviceSelecting,
        authorizer: any BearerTokenAuthorizing
    ) -> [HTTPRoute] {
        [
            health(),
            permissionStatus(provider: permissionStatusProvider),
            sessionState(provider: cameraStateProvider),
            sessionDeviceSelection(selector: deviceSelector, authorizer: authorizer),
        ]
    }

    public static func health() -> HTTPRoute {
        HTTPRoute(method: .get, path: "/health") { _ in
            .json(statusCode: 200, body: #"{ "status": "ok" }"#)
        }
    }

    public static func permissionStatus(provider: any CameraPermissionStatusProviding) -> HTTPRoute {
        HTTPRoute(method: .get, path: "/v1/permissions") { _ in
            .json(
                statusCode: 200,
                body: #"{ "status": "\#(provider.currentPermissionState().rawValue)" }"#
            )
        }
    }

    public static func sessionState(provider: any CameraStateProviding) -> HTTPRoute {
        HTTPRoute(method: .get, path: "/v1/session") { _ in
            .json(statusCode: 200, body: SessionStateResponse(state: provider.currentCameraState()))
        }
    }

    public static func sessionDeviceSelection(
        selector: any CameraDeviceSelecting,
        authorizer: any BearerTokenAuthorizing
    ) -> HTTPRoute {
        HTTPRoute(method: .post, path: "/v1/session/select-device") { request in
            guard authorizer.isAuthorized(request: request) else {
                return .unauthorized()
            }

            let selectionRequest: SelectDeviceRequest
            do {
                selectionRequest = try JSONDecoder().decode(SelectDeviceRequest.self, from: request.body)
            } catch {
                return .badRequest(message: "Request body must be valid JSON")
            }

            let deviceID = selectionRequest.deviceID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !deviceID.isEmpty else {
                return .badRequest(message: "device_id is required")
            }

            do {
                let state = try selector.selectDevice(id: deviceID, ownerID: selectionRequest.ownerID)
                return .json(statusCode: 200, body: SessionStateResponse(state: state))
            } catch let error as CameraDeviceSelectionError {
                switch error {
                case .ownershipConflict(let currentOwnerID):
                    return .error(
                        statusCode: 409,
                        code: "ownership_conflict",
                        message: "Session is owned by \(currentOwnerID)"
                    )
                case .unavailableDevice(let id):
                    return .error(
                        statusCode: 409,
                        code: "invalid_state",
                        message: "Requested device is unavailable: \(id)"
                    )
                }
            } catch {
                return .error(statusCode: 409, code: "invalid_state", message: "Device selection failed")
            }
        }
    }
}

public final class LocalHTTPServer: @unchecked Sendable {
    public struct Configuration: Sendable, Equatable {
        public var host: String
        public var port: UInt16

        public init(host: String, port: UInt16) {
            self.host = host
            self.port = port
        }
    }

    public typealias Logger = @Sendable (String) -> Void

    public let configuration: Configuration

    private let router: CameraBridgeRouter
    private let logger: Logger
    private let queue: DispatchQueue
    private let stateLock = NSLock()
    private var listener: NWListener?
    private var started = false
    private(set) public var boundPort: UInt16?

    public init(
        configuration: Configuration,
        router: CameraBridgeRouter,
        logger: @escaping Logger = { _ in }
    ) {
        self.configuration = configuration
        self.router = router
        self.logger = logger
        self.queue = DispatchQueue(label: "CameraBridgeAPI.LocalHTTPServer")
    }

    @discardableResult
    public func start() throws -> UInt16 {
        stateLock.lock()
        defer { stateLock.unlock() }

        guard !started else {
            return boundPort ?? configuration.port
        }

        guard let port = NWEndpoint.Port(rawValue: configuration.port) else {
            throw HTTPServerError.invalidPort(configuration.port)
        }

        let listener = try NWListener(using: .tcp, on: port)
        let readySemaphore = DispatchSemaphore(value: 0)
        var startError: Error?

        listener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.boundPort = listener.port?.rawValue ?? self?.configuration.port
                readySemaphore.signal()
            case .failed(let error):
                startError = error
                readySemaphore.signal()
            default:
                break
            }
        }

        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection: connection)
        }

        listener.start(queue: queue)
        readySemaphore.wait()

        if let startError {
            listener.cancel()
            throw startError
        }

        self.listener = listener
        self.started = true
        let activePort = boundPort ?? configuration.port
        logger("listening on http://\(configuration.host):\(activePort)")
        return activePort
    }

    public func stop() {
        stateLock.lock()
        defer { stateLock.unlock() }

        listener?.cancel()
        listener = nil
        started = false
    }

    private func handle(connection: NWConnection) {
        connection.stateUpdateHandler = { state in
            if case .failed = state {
                connection.cancel()
            }
        }

        connection.start(queue: queue)
        receive(on: connection, accumulated: Data())
    }

    private func receive(on connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self else {
                connection.cancel()
                return
            }

            if error != nil {
                connection.cancel()
                return
            }

            var buffer = accumulated
            if let data {
                buffer.append(data)
            }

            switch HTTPRequestParser.parse(buffer) {
            case .success(let request):
                let response = router.response(for: request)
                send(response: response, on: connection)
            case .incomplete:
                if isComplete {
                    send(response: .notFound(), on: connection)
                } else {
                    receive(on: connection, accumulated: buffer)
                }
            case .failure:
                send(response: .notFound(), on: connection)
            }
        }
    }

    private func send(response: HTTPResponse, on connection: NWConnection) {
        connection.send(content: HTTPResponseSerializer.serialize(response), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

public enum HTTPServerError: Error, Sendable, Equatable {
    case invalidPort(UInt16)
}

private struct RouteKey: Hashable, Sendable {
    var method: HTTPMethod
    var path: String
}

private enum HTTPRequestParseResult {
    case success(HTTPRequest)
    case incomplete
    case failure
}

private enum HTTPRequestParser {
    static func parse(_ data: Data) -> HTTPRequestParseResult {
        guard let headersRange = data.range(of: Data("\r\n\r\n".utf8)) else {
            return .incomplete
        }

        let headerData = data[..<headersRange.lowerBound]
        guard let headerString = String(data: headerData, encoding: .utf8) else {
            return .failure
        }

        let lines = headerString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            return .failure
        }

        let requestParts = requestLine.split(separator: " ")
        guard requestParts.count == 3,
              let method = HTTPMethod(rawValue: String(requestParts[0])) else {
            return .failure
        }

        let path = String(requestParts[1])
        let headers = parseHeaders(lines.dropFirst())
        let expectedBodyLength = Int(headers["content-length"] ?? "") ?? 0
        let bodyStart = headersRange.upperBound
        let availableBodyLength = data.count - bodyStart

        guard availableBodyLength >= expectedBodyLength else {
            return .incomplete
        }

        let body = Data(data[bodyStart..<(bodyStart + expectedBodyLength)])
        return .success(
            HTTPRequest(method: method, path: path, headers: headers, body: body)
        )
    }

    private static func parseHeaders<S: Sequence>(_ lines: S) -> [String: String] where S.Element == String {
        var headers: [String: String] = [:]

        for line in lines where !line.isEmpty {
            let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else {
                continue
            }

            headers[String(parts[0]).lowercased()] = String(parts[1]).trimmingCharacters(in: .whitespaces)
        }

        return headers
    }
}

private enum HTTPResponseSerializer {
    static func serialize(_ response: HTTPResponse) -> Data {
        var headers = response.headers
        headers["Connection"] = "close"
        headers["Content-Length"] = String(response.body.count)

        let statusText = reasonPhrase(for: response.statusCode)
        let headerLines = headers
            .sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: "\r\n")

        var message = "HTTP/1.1 \(response.statusCode) \(statusText)\r\n"
        message += headerLines
        message += "\r\n\r\n"

        var data = Data(message.utf8)
        data.append(response.body)
        return data
    }

    private static func reasonPhrase(for statusCode: Int) -> String {
        switch statusCode {
        case 400:
            return "Bad Request"
        case 200:
            return "OK"
        case 401:
            return "Unauthorized"
        case 409:
            return "Conflict"
        case 404:
            return "Not Found"
        default:
            return "Error"
        }
    }
}

private extension HTTPRequest {
    var authorizationBearerToken: String? {
        guard let authorization = headers.first(where: {
            $0.key.caseInsensitiveCompare("Authorization") == .orderedSame
        })?.value else {
            return nil
        }

        let prefix = "Bearer "
        guard authorization.hasPrefix(prefix) else {
            return nil
        }

        return String(authorization.dropFirst(prefix.count))
    }
}

private struct ErrorResponse: Encodable, Equatable {
    var error: ErrorBody
}

private struct ErrorBody: Encodable, Equatable {
    var code: String
    var message: String
}

private struct SessionStateResponse: Encodable, Equatable {
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

    init(state: CameraState) {
        self.state = state.sessionState.rawValue
        self.activeDeviceID = state.activeDeviceID
        self.ownerID = state.currentOwnerID
        self.lastError = state.lastError?.message
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(state, forKey: .state)

        if let activeDeviceID {
            try container.encode(activeDeviceID, forKey: .activeDeviceID)
        } else {
            try container.encodeNil(forKey: .activeDeviceID)
        }

        if let ownerID {
            try container.encode(ownerID, forKey: .ownerID)
        } else {
            try container.encodeNil(forKey: .ownerID)
        }

        if let lastError {
            try container.encode(lastError, forKey: .lastError)
        } else {
            try container.encodeNil(forKey: .lastError)
        }
    }
}

private struct SelectDeviceRequest: Decodable, Equatable {
    var deviceID: String
    var ownerID: String?

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case ownerID = "owner_id"
    }
}

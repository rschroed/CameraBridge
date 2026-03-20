import CameraBridgeAPI
import CameraBridgeCore
import Foundation

struct ServerConfiguration: Sendable, Equatable {
    static let defaultHost = "127.0.0.1"
    static let defaultPort: UInt16 = 8731
    static let authTokenEnvironmentVariable = "CAMERABRIDGE_AUTH_TOKEN"

    var host: String
    var port: UInt16
    var authToken: String?

    init(
        host: String = ServerConfiguration.defaultHost,
        port: UInt16 = ServerConfiguration.defaultPort,
        authToken: String? = ProcessInfo.processInfo.environment[ServerConfiguration.authTokenEnvironmentVariable]
    ) {
        self.host = host
        self.port = port
        self.authToken = authToken
    }
}

struct CameraBridgeDaemon {
    typealias Logger = @Sendable (String) -> Void

    var configuration: ServerConfiguration
    var logger: Logger

    init(
        configuration: ServerConfiguration = ServerConfiguration(),
        logger: @escaping Logger = { print($0) }
    ) {
        self.configuration = configuration
        self.logger = logger
    }

    private func defaultRouter() -> CameraBridgeRouter {
        let deviceListing = AVFoundationCameraDeviceListing()
        let sessionController = DefaultCameraSessionController(deviceListing: deviceListing)
        return CameraBridgeRouter(
            routes: CameraBridgeRoutes.current(
                permissionStatusProvider: AVFoundationCameraPermissionStatusProvider(),
                cameraStateProvider: sessionController,
                deviceSelector: sessionController,
                authorizer: StaticBearerTokenAuthorizer(bearerToken: configuration.authToken)
            )
        )
    }

    func makeServer(router: CameraBridgeRouter? = nil) -> LocalHTTPServer {
        LocalHTTPServer(
            configuration: .init(host: configuration.host, port: configuration.port),
            router: router ?? defaultRouter(),
            logger: logger
        )
    }

    @discardableResult
    func start(router: CameraBridgeRouter? = nil) throws -> LocalHTTPServer {
        logger("starting camd on \(configuration.host):\(configuration.port)")
        let server = makeServer(router: router)
        let port = try server.start()
        logger("camd ready on \(configuration.host):\(port)")
        return server
    }
}

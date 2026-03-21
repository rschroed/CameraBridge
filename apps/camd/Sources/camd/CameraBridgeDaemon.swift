import CameraBridgeAPI
import CameraBridgeCore
import CameraBridgeSupport
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

    func resolvedAuthToken(
        authTokenStore: DefaultCameraBridgeAuthTokenStore = DefaultCameraBridgeAuthTokenStore()
    ) throws -> String {
        if let authToken {
            let trimmedToken = authToken.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedToken.isEmpty {
                return trimmedToken
            }
        }

        return try authTokenStore.loadOrCreateToken()
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

    private func defaultRouter() throws -> CameraBridgeRouter {
        let deviceListing = AVFoundationCameraDeviceListing()
        let sessionController = DefaultCameraSessionController(
            deviceListing: deviceListing,
            photoProducer: AVFoundationStillPhotoProducer(),
            artifactStore: DefaultPhotoArtifactStore()
        )
        let authToken = try configuration.resolvedAuthToken()
        return CameraBridgeRouter(
            routes: CameraBridgeRoutes.current(
                permissionController: sessionController,
                deviceListing: sessionController,
                cameraStateProvider: sessionController,
                deviceSelector: sessionController,
                sessionStarter: sessionController,
                sessionStopper: sessionController,
                photoCapturer: sessionController,
                authorizer: StaticBearerTokenAuthorizer(bearerToken: authToken)
            )
        )
    }

    func makeServer(router: CameraBridgeRouter? = nil) throws -> LocalHTTPServer {
        LocalHTTPServer(
            configuration: .init(host: configuration.host, port: configuration.port),
            router: try (router ?? defaultRouter()),
            logger: logger
        )
    }

    @discardableResult
    func start(router: CameraBridgeRouter? = nil) throws -> LocalHTTPServer {
        logger("starting camd on \(configuration.host):\(configuration.port)")
        let server = try makeServer(router: router)
        let port = try server.start()
        logger("camd ready on \(configuration.host):\(port)")
        return server
    }
}

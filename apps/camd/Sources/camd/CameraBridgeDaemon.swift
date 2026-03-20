import CameraBridgeAPI
import CameraBridgeCore
import Foundation

struct ServerConfiguration: Sendable, Equatable {
    static let defaultHost = "127.0.0.1"
    static let defaultPort: UInt16 = 8731

    var host: String
    var port: UInt16

    init(host: String = ServerConfiguration.defaultHost, port: UInt16 = ServerConfiguration.defaultPort) {
        self.host = host
        self.port = port
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

    func makeRouter(
        permissionStatusProvider: any CameraPermissionStatusProviding = AVFoundationCameraPermissionStatusProvider()
    ) -> CameraBridgeRouter {
        CameraBridgeRouter(routes: CameraBridgeRoutes.current(permissionStatusProvider: permissionStatusProvider))
    }

    func makeServer(
        router: CameraBridgeRouter? = nil,
        permissionStatusProvider: any CameraPermissionStatusProviding = AVFoundationCameraPermissionStatusProvider()
    ) -> LocalHTTPServer {
        let resolvedRouter = router ?? makeRouter(permissionStatusProvider: permissionStatusProvider)

        return LocalHTTPServer(
            configuration: .init(host: configuration.host, port: configuration.port),
            router: resolvedRouter,
            logger: logger
        )
    }

    @discardableResult
    func start(
        router: CameraBridgeRouter? = nil,
        permissionStatusProvider: any CameraPermissionStatusProviding = AVFoundationCameraPermissionStatusProvider()
    ) throws -> LocalHTTPServer {
        logger("starting camd on \(configuration.host):\(configuration.port)")
        let server = makeServer(router: router, permissionStatusProvider: permissionStatusProvider)
        let port = try server.start()
        logger("camd ready on \(configuration.host):\(port)")
        return server
    }
}

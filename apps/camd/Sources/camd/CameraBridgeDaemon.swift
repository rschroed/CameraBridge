import CameraBridgeAPI
import CameraBridgeCore
import CameraBridgeSupport
import Foundation

struct ServerConfiguration: Sendable, Equatable {
    static let defaultHost = "127.0.0.1"
    static let defaultPort: UInt16 = 8731
    static let hostEnvironmentVariable = "CAMERABRIDGE_HOST"
    static let portEnvironmentVariable = "CAMERABRIDGE_PORT"
    static let authTokenEnvironmentVariable = "CAMERABRIDGE_AUTH_TOKEN"
    static let runtimeOwnershipEnvironmentVariable = "CAMERABRIDGE_RUNTIME_OWNERSHIP"

    var host: String
    var port: UInt16
    var authToken: String?

    init(
        host: String? = nil,
        port: UInt16? = nil,
        authToken: String? = ProcessInfo.processInfo.environment[ServerConfiguration.authTokenEnvironmentVariable],
        runtimeConfigurationStore: DefaultCameraBridgeRuntimeConfigurationStore = DefaultCameraBridgeRuntimeConfigurationStore()
    ) {
        let storedConfiguration = (try? runtimeConfigurationStore.loadConfiguration()) ??
            CameraBridgeRuntimeConfiguration()
        self.host = host ??
            ProcessInfo.processInfo.environment[ServerConfiguration.hostEnvironmentVariable] ??
            storedConfiguration.host
        self.port = port ??
            Self.environmentPortValue() ??
            storedConfiguration.port
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

    func resolvedRuntimeOwnership() -> CameraBridgeRuntimeOwnership {
        guard let rawValue =
            ProcessInfo.processInfo.environment[ServerConfiguration.runtimeOwnershipEnvironmentVariable],
            let ownership = CameraBridgeRuntimeOwnership(rawValue: rawValue)
        else {
            return .external
        }

        return ownership
    }

    private static func environmentPortValue() -> UInt16? {
        guard let rawValue = ProcessInfo.processInfo.environment[portEnvironmentVariable] else {
            return nil
        }

        return UInt16(rawValue)
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
        let permissionStatusProvider = AVFoundationCameraPermissionStatusProvider()
        let sessionController = DefaultCameraSessionController(
            permissionStatusProvider: permissionStatusProvider,
            permissionRequester: DaemonNonPromptingPermissionRequester(
                permissionStatusProvider: permissionStatusProvider
            ),
            deviceListing: deviceListing,
            stillSessionManager: AVFoundationStillSessionManager(),
            artifactStore: DefaultPhotoArtifactStore()
        )
        let authToken = try configuration.resolvedAuthToken()
        return CameraBridgeRouter(
            routes: CameraBridgeRoutes.current(
                permissionStatusProvider: sessionController,
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

    func runtimeInfo(
        boundPort: UInt16,
        authTokenStore: DefaultCameraBridgeAuthTokenStore = DefaultCameraBridgeAuthTokenStore()
    ) throws -> CameraBridgeRuntimeInfo {
        CameraBridgeRuntimeInfo(
            pid: Int32(ProcessInfo.processInfo.processIdentifier),
            host: configuration.host,
            port: boundPort,
            tokenFileURL: try authTokenStore.authTokenURL(),
            logFileURL: try CameraBridgeSupportPaths.logFileURL(),
            capturesDirectoryURL: try CameraBridgeSupportPaths.capturesDirectoryURL(),
            ownership: configuration.resolvedRuntimeOwnership()
        )
    }
}

struct DaemonNonPromptingPermissionRequester: CameraPermissionRequesting {
    let permissionStatusProvider: any CameraPermissionStatusProviding

    func requestPermission(completion: @escaping @Sendable (PermissionRequestResult) -> Void) {
        completion(
            PermissionRequestResult(
                status: permissionStatusProvider.currentPermissionState(),
                prompted: false
            )
        )
    }
}

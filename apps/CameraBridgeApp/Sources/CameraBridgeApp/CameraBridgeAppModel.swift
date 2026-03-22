import AVFoundation
import CameraBridgeClientSwift
import CameraBridgeSupport
import Foundation

@MainActor
final class CameraBridgeAppModel {
    enum ServiceStatus: Equatable {
        case stopped
        case starting
        case runningManaged
        case runningExternal
        case stopping
        case failed(String)

        var title: String {
            switch self {
            case .stopped:
                return "Stopped"
            case .starting:
                return "Starting"
            case .runningManaged:
                return "Running"
            case .runningExternal:
                return "Running (External)"
            case .stopping:
                return "Stopping"
            case .failed:
                return "Needs Attention"
            }
        }

        var isManagedRunning: Bool {
            if case .runningManaged = self {
                return true
            }

            return false
        }
    }

    private enum PermissionDisplay: Equatable {
        case unavailable
        case checking
        case notDetermined
        case restricted
        case denied
        case authorized

        var title: String {
            switch self {
            case .unavailable:
                return "Unavailable"
            case .checking:
                return "Requesting Access"
            case .notDetermined:
                return "Not Determined"
            case .restricted:
                return "Restricted"
            case .denied:
                return "Denied"
            case .authorized:
                return "Authorized"
            }
        }

        init(permissionStatus: CameraBridgePermissionStatus) {
            switch permissionStatus {
            case .notDetermined:
                self = .notDetermined
            case .restricted:
                self = .restricted
            case .denied:
                self = .denied
            case .authorized:
                self = .authorized
            }
        }
    }

    private struct DeveloperInfo: Equatable {
        var baseURL: String
        var tokenPath: String
        var logPath: String
        var capturesPath: String
    }

    var onChange: (() -> Void)?

    var serviceStatusTitle: String {
        serviceStatus.title
    }

    var permissionStatusTitle: String {
        permissionDisplay.title
    }

    var statusSummaryTitle: String {
        switch (serviceStatus, permissionDisplay) {
        case (.starting, _):
            return "CameraBridge is starting"
        case (.stopping, _):
            return "CameraBridge is stopping"
        case (.stopped, _):
            return "Local service is stopped"
        case (.failed, _):
            return "CameraBridge needs attention"
        case (.runningManaged, .checking), (.runningExternal, .checking):
            return "Waiting for camera access"
        case (.runningManaged, .notDetermined), (.runningExternal, .notDetermined):
            return "Camera access setup is incomplete"
        case (.runningManaged, .restricted), (.runningManaged, .denied),
            (.runningExternal, .restricted), (.runningExternal, .denied):
            return "Camera access is unavailable"
        case (.runningManaged, .authorized):
            return "CameraBridge is ready"
        case (.runningExternal, .authorized):
            return "External CameraBridge service detected"
        case (.runningManaged, .unavailable):
            return "Managed service is running"
        case (.runningExternal, .unavailable):
            return "External CameraBridge service detected"
        }
    }

    var guidanceMessage: String {
        switch (serviceStatus, permissionDisplay) {
        case (.starting, _):
            return "Waiting for the local CameraBridge service to respond."
        case (.stopping, _):
            return "Waiting for the managed CameraBridge service to stop."
        case (.stopped, .notDetermined), (.failed, .notDetermined):
            return "Request camera access from CameraBridge, then start the local service to finish onboarding."
        case (.stopped, .restricted), (.failed, .restricted):
            return "Camera access is restricted on this Mac and cannot be granted from CameraBridge."
        case (.stopped, .denied), (.failed, .denied):
            return "Camera access was denied. Re-enable it in System Settings > Privacy & Security > Camera."
        case (.stopped, _), (.failed, _):
            return "Start the local service to finish onboarding."
        case (.runningManaged, .checking), (.runningExternal, .checking):
            return "Respond to the macOS camera permission prompt if it appears."
        case (.runningManaged, .notDetermined):
            return "Request camera access from CameraBridge to continue."
        case (.runningExternal, .notDetermined):
            return "A local CameraBridge service is already running. Request camera access from CameraBridge to continue."
        case (.runningManaged, .restricted), (.runningExternal, .restricted):
            return "Camera access is restricted on this Mac and cannot be granted from CameraBridge."
        case (.runningManaged, .denied), (.runningExternal, .denied):
            return "Camera access was denied. Re-enable it in System Settings > Privacy & Security > Camera."
        case (.runningManaged, .authorized):
            return "The managed CameraBridge service is running and camera access is available."
        case (.runningExternal, .authorized):
            return "A local CameraBridge service is already running outside this app and camera access is available."
        case (.runningManaged, .unavailable):
            return "The managed service is running, but permission status could not be loaded."
        case (.runningExternal, .unavailable):
            return "A local CameraBridge service is already running, but permission status could not be loaded."
        }
    }

    var lastErrorMessage: String? {
        lastError
    }

    var canStartService: Bool {
        switch serviceStatus {
        case .runningManaged, .runningExternal, .starting, .stopping:
            return false
        case .stopped, .failed:
            return true
        }
    }

    var canStopService: Bool {
        serviceStatus.isManagedRunning
    }

    var canRequestCameraAccess: Bool {
        !isRequestInFlight && (permissionDisplay == .notDetermined || permissionDisplay == .unavailable)
    }

    var developerBaseURL: String {
        developerInfo.baseURL
    }

    var developerTokenPath: String {
        developerInfo.tokenPath
    }

    var developerLogPath: String {
        developerInfo.logPath
    }

    var developerCapturesPath: String {
        developerInfo.capturesPath
    }

    private var serviceStatus: ServiceStatus = .stopped
    private var permissionDisplay: PermissionDisplay = .unavailable
    private var lastError: String?
    private var isRequestInFlight = false
    private var refreshTimer: Timer?
    private var developerInfo = DeveloperInfo(
        baseURL: "Unavailable",
        tokenPath: "Unavailable",
        logPath: "Unavailable",
        capturesPath: "Unavailable"
    )

    private let client: any CameraBridgeAppClient
    private let permissionController: any CameraBridgeAppPermissionControlling
    private let serviceController: any CameraBridgeServiceControlling
    private let runtimeConfigurationStore: any CameraBridgeRuntimeConfigurationReading
    private let runtimeInfoStore: any CameraBridgeRuntimeInfoReading

    init(
        client: (any CameraBridgeAppClient)? = nil,
        authTokenStore: any CameraBridgeAuthTokenReading = DefaultCameraBridgeAuthTokenStore(),
        runtimeConfigurationStore: any CameraBridgeRuntimeConfigurationReading = DefaultCameraBridgeRuntimeConfigurationStore(),
        runtimeInfoStore: any CameraBridgeRuntimeInfoReading = DefaultCameraBridgeRuntimeInfoStore(),
        permissionController: (any CameraBridgeAppPermissionControlling)? = nil,
        serviceController: (any CameraBridgeServiceControlling)? = nil
    ) {
        let runtimeConfiguration = (try? runtimeConfigurationStore.loadConfiguration()) ??
            CameraBridgeRuntimeConfiguration()
        let resolvedClient = client ?? CameraBridgeClient(
            baseURL: runtimeConfiguration.baseURL,
            tokenProvider: {
                try? authTokenStore.loadToken()
            }
        )
        self.client = resolvedClient
        self.runtimeConfigurationStore = runtimeConfigurationStore
        self.runtimeInfoStore = runtimeInfoStore
        self.permissionController = permissionController ?? AVFoundationCameraBridgeAppPermissionController()
        self.serviceController = serviceController ?? LocalCameraBridgeServiceController(
            client: resolvedClient,
            runtimeConfigurationStore: runtimeConfigurationStore
        )
    }

    func start() {
        refresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func refresh() {
        Task { @MainActor in
            await refreshNow()
        }
    }

    func startService() {
        Task { @MainActor in
            await startServiceNow()
        }
    }

    func stopService() {
        Task { @MainActor in
            await stopServiceNow()
        }
    }

    func requestCameraAccess() {
        Task { @MainActor in
            await requestCameraAccessNow()
        }
    }

    func refreshNow() async {
        await refreshState()
    }

    func startServiceNow() async {
        await performStartService()
    }

    func stopServiceNow() async {
        await performStopService()
    }

    func requestCameraAccessNow() async {
        await performRequestCameraAccess()
    }

    func prepareForTermination() async {
        try? await serviceController.stopIfManaged()
    }

    private func publishChange() {
        onChange?()
    }

    private func refreshState() async {
        let permissionStatus = permissionController.currentPermissionStatus()
        switch await serviceController.currentManagementState() {
        case .stopped:
            serviceStatus = .stopped
        case .runningManaged:
            serviceStatus = .runningManaged
        case .runningExternal:
            serviceStatus = .runningExternal
        }
        permissionDisplay = .init(permissionStatus: permissionStatus)
        developerInfo = loadDeveloperInfo()
        lastError = nil
        publishChange()
    }

    private func performStartService() async {
        guard canStartService else {
            return
        }

        serviceStatus = .starting
        lastError = nil
        publishChange()

        do {
            try await serviceController.startIfNeeded()
            await refreshState()
        } catch {
            serviceStatus = .failed(displayMessage(for: error))
            let permissionStatus = permissionController.currentPermissionStatus()
            permissionDisplay = .init(permissionStatus: permissionStatus)
            developerInfo = loadDeveloperInfo()
            lastError = displayMessage(for: error)
            publishChange()
        }
    }

    private func performStopService() async {
        guard canStopService else {
            return
        }

        serviceStatus = .stopping
        lastError = nil
        publishChange()

        do {
            try await serviceController.stopIfManaged()
            await refreshState()
        } catch {
            serviceStatus = .failed(displayMessage(for: error))
            let permissionStatus = permissionController.currentPermissionStatus()
            permissionDisplay = .init(permissionStatus: permissionStatus)
            developerInfo = loadDeveloperInfo()
            lastError = displayMessage(for: error)
            publishChange()
        }
    }

    private func performRequestCameraAccess() async {
        guard canRequestCameraAccess else {
            return
        }

        isRequestInFlight = true
        permissionDisplay = .checking
        lastError = nil
        publishChange()

        defer {
            isRequestInFlight = false
            publishChange()
        }

        _ = await permissionController.requestPermission()
        await refreshState()
    }

    private func loadDeveloperInfo() -> DeveloperInfo {
        let runtimeConfiguration = (try? runtimeConfigurationStore.loadConfiguration()) ??
            CameraBridgeRuntimeConfiguration()
        let runtimeInfo = try? runtimeInfoStore.loadRuntimeInfo()

        return DeveloperInfo(
            baseURL: (runtimeInfo?.baseURL ?? runtimeConfiguration.baseURL).absoluteString,
            tokenPath: pathDescription(
                runtimeInfo?.tokenFileURL,
                fallback: try? CameraBridgeSupportPaths.authTokenURL()
            ),
            logPath: pathDescription(
                runtimeInfo?.logFileURL,
                fallback: try? CameraBridgeSupportPaths.logFileURL()
            ),
            capturesPath: pathDescription(
                runtimeInfo?.capturesDirectoryURL,
                fallback: try? CameraBridgeSupportPaths.capturesDirectoryURL()
            )
        )
    }

    private func pathDescription(_ value: URL?, fallback: URL?) -> String {
        (value ?? fallback)?.path ?? "Unavailable"
    }

    private func displayMessage(for error: Error) -> String {
        switch error {
        case let clientError as CameraBridgeClientError:
            switch clientError {
            case .invalidResponse:
                return "Service returned an invalid response"
            case .invalidStatus(let status):
                return "Service returned unknown status: \(status)"
            case .requestFailed(_, _, let message):
                return message ?? "Service request failed"
            }
        case let controlError as CameraBridgeServiceControlError:
            return controlError.errorDescription ?? "Service control failed"
        case let authTokenError as CameraBridgeAuthTokenError:
            return authTokenError.errorDescription ?? "Auth token setup failed"
        default:
            return error.localizedDescription
        }
    }
}

protocol CameraBridgeAuthTokenReading {
    func loadToken() throws -> String?
}

extension DefaultCameraBridgeAuthTokenStore: CameraBridgeAuthTokenReading {}

protocol CameraBridgeRuntimeConfigurationReading {
    func loadConfiguration() throws -> CameraBridgeRuntimeConfiguration
}

extension DefaultCameraBridgeRuntimeConfigurationStore: CameraBridgeRuntimeConfigurationReading {}

protocol CameraBridgeRuntimeInfoReading {
    func loadRuntimeInfo() throws -> CameraBridgeRuntimeInfo?
}

extension DefaultCameraBridgeRuntimeInfoStore: CameraBridgeRuntimeInfoReading {}

protocol CameraBridgeAppClient {
    func serviceIsRunning() async -> Bool
}

extension CameraBridgeClient: CameraBridgeAppClient {}

@MainActor
protocol CameraBridgeAppPermissionControlling {
    func currentPermissionStatus() -> CameraBridgePermissionStatus
    func requestPermission() async -> CameraBridgePermissionRequestResult
}

struct AVFoundationCameraBridgeAppPermissionController: CameraBridgeAppPermissionControlling {
    func currentPermissionStatus() -> CameraBridgePermissionStatus {
        CameraBridgePermissionStatus(
            authorizationStatus: AVCaptureDevice.authorizationStatus(for: .video)
        )
    }

    func requestPermission() async -> CameraBridgePermissionRequestResult {
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .video)
        guard currentStatus == .notDetermined else {
            return .init(
                status: CameraBridgePermissionStatus(authorizationStatus: currentStatus),
                prompted: false
            )
        }

        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { _ in
                continuation.resume(
                    returning: .init(
                        status: CameraBridgePermissionStatus(
                            authorizationStatus: AVCaptureDevice.authorizationStatus(for: .video)
                        ),
                        prompted: true
                    )
                )
            }
        }
    }
}

enum CameraBridgeManagedServiceState: Equatable {
    case stopped
    case runningManaged
    case runningExternal
}

@MainActor
protocol CameraBridgeServiceControlling {
    func startIfNeeded() async throws
    func stopIfManaged() async throws
    func currentManagementState() async -> CameraBridgeManagedServiceState
}

enum CameraBridgeServiceControlError: LocalizedError {
    case missingBundledDaemon
    case failedToStartService
    case failedToStopService
    case launchLogUnavailable

    var errorDescription: String? {
        switch self {
        case .missingBundledDaemon:
            return "Bundled camd executable is missing"
        case .failedToStartService:
            return "Service did not become healthy after launch"
        case .failedToStopService:
            return "Managed service did not stop cleanly"
        case .launchLogUnavailable:
            return "Service log file could not be opened"
        }
    }
}

@MainActor
final class LocalCameraBridgeServiceController: CameraBridgeServiceControlling {
    private let client: any CameraBridgeAppClient
    private let runtimeConfigurationStore: any CameraBridgeRuntimeConfigurationReading
    private var process: Process?
    private var logHandle: FileHandle?

    init(
        client: any CameraBridgeAppClient,
        runtimeConfigurationStore: any CameraBridgeRuntimeConfigurationReading
    ) {
        self.client = client
        self.runtimeConfigurationStore = runtimeConfigurationStore
    }

    func startIfNeeded() async throws {
        if await client.serviceIsRunning() {
            return
        }

        let daemonURL = try bundledDaemonURL()
        let logHandle = try makeLogHandle()
        let runtimeConfiguration = (try? runtimeConfigurationStore.loadConfiguration()) ??
            CameraBridgeRuntimeConfiguration()

        let process = Process()
        process.executableURL = daemonURL
        process.standardOutput = logHandle
        process.standardError = logHandle
        process.environment = mergedEnvironment(runtimeConfiguration: runtimeConfiguration)

        do {
            try process.run()
        } catch {
            try? logHandle.close()
            throw error
        }

        self.process = process
        self.logHandle = logHandle

        for _ in 0..<20 {
            if await client.serviceIsRunning() {
                return
            }

            if !process.isRunning {
                break
            }

            try await Task.sleep(nanoseconds: 250_000_000)
        }

        clearManagedProcess()
        throw CameraBridgeServiceControlError.failedToStartService
    }

    func stopIfManaged() async throws {
        guard let process, process.isRunning else {
            clearManagedProcess()
            return
        }

        process.terminate()

        for _ in 0..<20 {
            if !process.isRunning {
                break
            }

            try await Task.sleep(nanoseconds: 250_000_000)
        }

        if process.isRunning {
            clearManagedProcess()
            throw CameraBridgeServiceControlError.failedToStopService
        }

        for _ in 0..<20 {
            if !(await client.serviceIsRunning()) {
                clearManagedProcess()
                return
            }

            try await Task.sleep(nanoseconds: 250_000_000)
        }

        clearManagedProcess()
        throw CameraBridgeServiceControlError.failedToStopService
    }

    func currentManagementState() async -> CameraBridgeManagedServiceState {
        if let process, process.isRunning, await client.serviceIsRunning() {
            return .runningManaged
        }

        if await client.serviceIsRunning() {
            return .runningExternal
        }

        return .stopped
    }

    private func bundledDaemonURL() throws -> URL {
        guard let resourceURL = Bundle.main.resourceURL else {
            throw CameraBridgeServiceControlError.missingBundledDaemon
        }

        let daemonURL = resourceURL.appendingPathComponent("camd", isDirectory: false)
        guard FileManager.default.isExecutableFile(atPath: daemonURL.path) else {
            throw CameraBridgeServiceControlError.missingBundledDaemon
        }

        return daemonURL
    }

    private func makeLogHandle() throws -> FileHandle {
        let fileManager = FileManager.default
        let logsURL = try CameraBridgeSupportPaths.logsDirectoryURL(fileManager: fileManager)
        try fileManager.createDirectory(at: logsURL, withIntermediateDirectories: true)

        let logURL = try CameraBridgeSupportPaths.logFileURL(fileManager: fileManager)
        if !fileManager.fileExists(atPath: logURL.path) {
            guard fileManager.createFile(atPath: logURL.path, contents: nil) else {
                throw CameraBridgeServiceControlError.launchLogUnavailable
            }
        }

        let handle = try FileHandle(forWritingTo: logURL)
        try handle.seekToEnd()
        return handle
    }

    private func mergedEnvironment(runtimeConfiguration: CameraBridgeRuntimeConfiguration) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["CAMERABRIDGE_HOST"] = runtimeConfiguration.host
        environment["CAMERABRIDGE_PORT"] = String(runtimeConfiguration.port)
        environment["CAMERABRIDGE_RUNTIME_OWNERSHIP"] = CameraBridgeRuntimeOwnership.appManaged.rawValue
        return environment
    }

    private func clearManagedProcess() {
        process = nil
        try? logHandle?.close()
        logHandle = nil
    }
}

private extension CameraBridgePermissionStatus {
    init(authorizationStatus: AVAuthorizationStatus) {
        switch authorizationStatus {
        case .notDetermined:
            self = .notDetermined
        case .restricted:
            self = .restricted
        case .denied:
            self = .denied
        case .authorized:
            self = .authorized
        @unknown default:
            self = .denied
        }
    }
}

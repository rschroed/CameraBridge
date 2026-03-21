import AVFoundation
import CameraBridgeClientSwift
import CameraBridgeSupport
import Foundation

@MainActor
final class CameraBridgeAppModel {
    enum ServiceStatus: Equatable {
        case stopped
        case starting
        case running
        case failed(String)

        var title: String {
            switch self {
            case .stopped:
                return "Stopped"
            case .starting:
                return "Starting"
            case .running:
                return "Running"
            case .failed:
                return "Needs Attention"
            }
        }

        var isRunning: Bool {
            if case .running = self {
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
        case (.stopped, _):
            return "Local service is stopped"
        case (.failed, _):
            return "CameraBridge needs attention"
        case (.running, .checking):
            return "Waiting for camera access"
        case (.running, .notDetermined):
            return "Camera access setup is incomplete"
        case (.running, .restricted), (.running, .denied):
            return "Camera access is unavailable"
        case (.running, .authorized):
            return "CameraBridge is ready"
        case (.running, .unavailable):
            return "Service is running"
        }
    }

    var guidanceMessage: String {
        switch (serviceStatus, permissionDisplay) {
        case (.starting, _):
            return "Waiting for the local CameraBridge service to respond."
        case (.stopped, .notDetermined), (.failed, .notDetermined):
            return "Request camera access from CameraBridge, then start the local service to finish onboarding."
        case (.stopped, .restricted), (.failed, .restricted):
            return "Camera access is restricted on this Mac and cannot be granted from CameraBridge."
        case (.stopped, .denied), (.failed, .denied):
            return "Camera access was denied. Re-enable it in System Settings > Privacy & Security > Camera."
        case (.stopped, _), (.failed, _):
            return "Start the local service to finish onboarding."
        case (.running, .checking):
            return "Respond to the macOS camera permission prompt if it appears."
        case (.running, .notDetermined):
            return "Request camera access from CameraBridge to continue."
        case (.running, .restricted):
            return "Camera access is restricted on this Mac and cannot be granted from CameraBridge."
        case (.running, .denied):
            return "Camera access was denied. Re-enable it in System Settings > Privacy & Security > Camera."
        case (.running, .authorized):
            return "The service is running and camera access is available."
        case (.running, .unavailable):
            return "The service is running, but permission status could not be loaded."
        }
    }

    var lastErrorMessage: String? {
        lastError
    }

    var canStartService: Bool {
        switch serviceStatus {
        case .running, .starting:
            return false
        case .stopped, .failed:
            return true
        }
    }

    var canRequestCameraAccess: Bool {
        !isRequestInFlight && (permissionDisplay == .notDetermined || permissionDisplay == .unavailable)
    }

    private var serviceStatus: ServiceStatus = .stopped
    private var permissionDisplay: PermissionDisplay = .unavailable
    private var lastError: String?
    private var isRequestInFlight = false
    private var refreshTimer: Timer?

    private let client: any CameraBridgeAppClient
    private let permissionController: any CameraBridgeAppPermissionControlling
    private let permissionStateStore: any CameraBridgePermissionStateWriting
    private let serviceLauncher: any CameraBridgeServiceLaunching

    init(
        client: (any CameraBridgeAppClient)? = nil,
        authTokenStore: any CameraBridgeAuthTokenReading = DefaultCameraBridgeAuthTokenStore(),
        permissionController: (any CameraBridgeAppPermissionControlling)? = nil,
        permissionStateStore: any CameraBridgePermissionStateWriting = DefaultCameraBridgePermissionStateStore(),
        serviceLauncher: (any CameraBridgeServiceLaunching)? = nil
    ) {
        let resolvedClient = client ?? CameraBridgeClient(
            tokenProvider: {
                try? authTokenStore.loadToken()
            }
        )
        self.client = resolvedClient
        self.permissionController = permissionController ?? AVFoundationCameraBridgeAppPermissionController()
        self.permissionStateStore = permissionStateStore
        self.serviceLauncher = serviceLauncher ?? LocalCameraBridgeServiceLauncher(client: resolvedClient)
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

    func requestCameraAccessNow() async {
        await performRequestCameraAccess()
    }

    private func publishChange() {
        onChange?()
    }

    private func refreshState() async {
        let permissionStatus = permissionController.currentPermissionStatus()
        let syncError = syncPermissionState(permissionStatus)
        let isRunning = await client.serviceIsRunning()
        serviceStatus = isRunning ? .running : .stopped
        permissionDisplay = .init(permissionStatus: permissionStatus)
        lastError = syncError.map(displayMessage(for:))
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
            try await serviceLauncher.startIfNeeded()
            await refreshState()
        } catch {
            serviceStatus = .failed(displayMessage(for: error))
            let permissionStatus = permissionController.currentPermissionStatus()
            _ = syncPermissionState(permissionStatus)
            permissionDisplay = .init(permissionStatus: permissionStatus)
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

        let result = await permissionController.requestPermission()
        if let syncError = syncPermissionState(result.status) {
            permissionDisplay = .init(permissionStatus: result.status)
            lastError = displayMessage(for: syncError)
            return
        }

        await refreshState()
    }

    private func syncPermissionState(_ permissionStatus: CameraBridgePermissionStatus) -> Error? {
        do {
            try permissionStateStore.savePermissionState(.init(permissionStatus: permissionStatus))
            return nil
        } catch {
            return error
        }
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
        case let launchError as CameraBridgeServiceLaunchError:
            return launchError.errorDescription ?? "Service failed to start"
        case let authTokenError as CameraBridgeAuthTokenError:
            return authTokenError.errorDescription ?? "Auth token setup failed"
        case let permissionStateStoreError as CameraBridgePermissionStateStoreError:
            return permissionStateStoreError.errorDescription ?? "Permission state sync failed"
        default:
            return error.localizedDescription
        }
    }
}

protocol CameraBridgeAuthTokenReading {
    func loadToken() throws -> String?
}

extension DefaultCameraBridgeAuthTokenStore: CameraBridgeAuthTokenReading {}

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

protocol CameraBridgePermissionStateWriting {
    func savePermissionState(_ state: CameraBridgeStoredPermissionState) throws
}

extension DefaultCameraBridgePermissionStateStore: CameraBridgePermissionStateWriting {}

@MainActor
protocol CameraBridgeServiceLaunching {
    func startIfNeeded() async throws
}

enum CameraBridgeServiceLaunchError: LocalizedError {
    case missingBundledDaemon
    case failedToStartService
    case launchLogUnavailable

    var errorDescription: String? {
        switch self {
        case .missingBundledDaemon:
            return "Bundled camd executable is missing"
        case .failedToStartService:
            return "Service did not become healthy after launch"
        case .launchLogUnavailable:
            return "Service log file could not be opened"
        }
    }
}

@MainActor
final class LocalCameraBridgeServiceLauncher: CameraBridgeServiceLaunching {
    private let client: any CameraBridgeAppClient
    private var process: Process?

    init(client: any CameraBridgeAppClient) {
        self.client = client
    }

    func startIfNeeded() async throws {
        if await client.serviceIsRunning() {
            return
        }

        let daemonURL = try bundledDaemonURL()
        let logHandle = try makeLogHandle()

        let process = Process()
        process.executableURL = daemonURL
        process.standardOutput = logHandle
        process.standardError = logHandle

        try process.run()
        self.process = process

        for _ in 0..<20 {
            if await client.serviceIsRunning() {
                return
            }

            if !process.isRunning {
                break
            }

            try await Task.sleep(nanoseconds: 250_000_000)
        }

        throw CameraBridgeServiceLaunchError.failedToStartService
    }

    private func bundledDaemonURL() throws -> URL {
        guard let resourceURL = Bundle.main.resourceURL else {
            throw CameraBridgeServiceLaunchError.missingBundledDaemon
        }

        let daemonURL = resourceURL.appendingPathComponent("camd", isDirectory: false)
        guard FileManager.default.isExecutableFile(atPath: daemonURL.path) else {
            throw CameraBridgeServiceLaunchError.missingBundledDaemon
        }

        return daemonURL
    }

    private func makeLogHandle() throws -> FileHandle {
        let fileManager = FileManager.default
        guard let applicationSupportURL =
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else {
            throw CameraBridgeServiceLaunchError.launchLogUnavailable
        }

        let logsURL = applicationSupportURL
            .appendingPathComponent("CameraBridge", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
        try fileManager.createDirectory(at: logsURL, withIntermediateDirectories: true)

        let logURL = logsURL.appendingPathComponent("camd.log", isDirectory: false)
        if !fileManager.fileExists(atPath: logURL.path) {
            guard fileManager.createFile(atPath: logURL.path, contents: nil) else {
                throw CameraBridgeServiceLaunchError.launchLogUnavailable
            }
        }

        let handle = try FileHandle(forWritingTo: logURL)
        try handle.seekToEnd()
        return handle
    }
}

private extension CameraBridgeStoredPermissionState {
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

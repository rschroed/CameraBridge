import CameraBridgeClientSwift
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
                return "stopped"
            case .starting:
                return "starting"
            case .running:
                return "running"
            case .failed:
                return "failed"
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
                return "unavailable"
            case .checking:
                return "checking"
            case .notDetermined:
                return "not determined"
            case .restricted:
                return "restricted"
            case .denied:
                return "denied"
            case .authorized:
                return "authorized"
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
        serviceStatus.isRunning && !isRequestInFlight
    }

    private var serviceStatus: ServiceStatus = .stopped
    private var permissionDisplay: PermissionDisplay = .unavailable
    private var lastError: String?
    private var isRequestInFlight = false
    private var refreshTimer: Timer?

    private let client: CameraBridgeClient
    private let serviceLauncher: any CameraBridgeServiceLaunching

    init(
        client: CameraBridgeClient? = nil,
        authTokenStore: any CameraBridgeAuthTokenStoring = DefaultCameraBridgeAuthTokenStore(),
        serviceLauncher: (any CameraBridgeServiceLaunching)? = nil
    ) {
        let resolvedClient = client ?? CameraBridgeClient(
            tokenProvider: {
                try? authTokenStore.loadOrCreateToken()
            }
        )
        self.client = resolvedClient
        self.serviceLauncher = serviceLauncher ?? LocalCameraBridgeServiceLauncher(
            client: resolvedClient,
            authTokenStore: authTokenStore
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
            await refreshState()
        }
    }

    func startService() {
        Task { @MainActor in
            await performStartService()
        }
    }

    func requestCameraAccess() {
        Task { @MainActor in
            await performRequestCameraAccess()
        }
    }

    private func publishChange() {
        onChange?()
    }

    private func refreshState() async {
        let isRunning = await client.serviceIsRunning()
        guard isRunning else {
            serviceStatus = .stopped
            permissionDisplay = .unavailable
            publishChange()
            return
        }

        do {
            let permissionStatus = try await client.permissionStatus()
            serviceStatus = .running
            permissionDisplay = .init(permissionStatus: permissionStatus)
            lastError = nil
            publishChange()
        } catch {
            serviceStatus = .running
            permissionDisplay = .unavailable
            lastError = displayMessage(for: error)
            publishChange()
        }
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
            permissionDisplay = .unavailable
            lastError = displayMessage(for: error)
            publishChange()
        }
    }

    private func performRequestCameraAccess() async {
        guard canRequestCameraAccess else {
            if !serviceStatus.isRunning {
                lastError = "Service is not running"
                publishChange()
            }
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

        do {
            _ = try await client.requestPermission()
            await refreshState()
        } catch {
            permissionDisplay = .unavailable
            lastError = displayMessage(for: error)
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
        default:
            return error.localizedDescription
        }
    }
}

protocol CameraBridgeAuthTokenStoring {
    func loadOrCreateToken() throws -> String
}

enum CameraBridgeAuthTokenError: LocalizedError {
    case invalidTokenFile
    case supportDirectoryUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidTokenFile:
            return "Stored auth token is invalid"
        case .supportDirectoryUnavailable:
            return "CameraBridge support directory is unavailable"
        }
    }
}

struct DefaultCameraBridgeAuthTokenStore: CameraBridgeAuthTokenStoring {
    private let fileManager = FileManager.default

    func loadOrCreateToken() throws -> String {
        let tokenURL = try authTokenURL()
        try fileManager.createDirectory(
            at: tokenURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if fileManager.fileExists(atPath: tokenURL.path) {
            let token = try String(contentsOf: tokenURL, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !token.isEmpty else {
                throw CameraBridgeAuthTokenError.invalidTokenFile
            }
            return token
        }

        let token = UUID().uuidString.lowercased()
        try Data(token.utf8).write(to: tokenURL, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tokenURL.path)
        return token
    }

    private func authTokenURL() throws -> URL {
        guard let applicationSupportURL =
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else {
            throw CameraBridgeAuthTokenError.supportDirectoryUnavailable
        }

        return applicationSupportURL
            .appendingPathComponent("CameraBridge", isDirectory: true)
            .appendingPathComponent("auth-token", isDirectory: false)
    }
}

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
    private static let authTokenEnvironmentVariable = "CAMERABRIDGE_AUTH_TOKEN"

    private let client: CameraBridgeClient
    private let authTokenStore: any CameraBridgeAuthTokenStoring
    private var process: Process?

    init(client: CameraBridgeClient, authTokenStore: any CameraBridgeAuthTokenStoring) {
        self.client = client
        self.authTokenStore = authTokenStore
    }

    func startIfNeeded() async throws {
        if await client.serviceIsRunning() {
            return
        }

        let daemonURL = try bundledDaemonURL()
        let token = try authTokenStore.loadOrCreateToken()
        let logHandle = try makeLogHandle()

        let process = Process()
        process.executableURL = daemonURL
        process.standardOutput = logHandle
        process.standardError = logHandle

        var environment = ProcessInfo.processInfo.environment
        environment[Self.authTokenEnvironmentVariable] = token
        process.environment = environment

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

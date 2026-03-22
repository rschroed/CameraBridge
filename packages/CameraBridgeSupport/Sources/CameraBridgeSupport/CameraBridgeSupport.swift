import Foundation

public enum CameraBridgeSupportModule {
    public static let name = "CameraBridgeSupport"
}

public enum CameraBridgeSupportPathError: LocalizedError, Equatable {
    case supportDirectoryUnavailable

    public var errorDescription: String? {
        switch self {
        case .supportDirectoryUnavailable:
            return "CameraBridge support directory is unavailable"
        }
    }
}

public enum CameraBridgeAuthTokenError: LocalizedError, Equatable {
    case invalidTokenFile
    case supportDirectoryUnavailable

    public var errorDescription: String? {
        switch self {
        case .invalidTokenFile:
            return "Stored auth token is invalid"
        case .supportDirectoryUnavailable:
            return "CameraBridge support directory is unavailable"
        }
    }
}

public enum CameraBridgeStoredPermissionState: String, Sendable, CaseIterable, Equatable {
    case notDetermined = "not_determined"
    case restricted
    case denied
    case authorized
}

public enum CameraBridgePermissionStateStoreError: LocalizedError, Equatable {
    case invalidPermissionStateFile
    case supportDirectoryUnavailable

    public var errorDescription: String? {
        switch self {
        case .invalidPermissionStateFile:
            return "Stored permission state is invalid"
        case .supportDirectoryUnavailable:
            return "CameraBridge support directory is unavailable"
        }
    }
}

public enum CameraBridgeRuntimeConfigurationStoreError: LocalizedError, Equatable {
    case invalidRuntimeConfigurationFile
    case supportDirectoryUnavailable

    public var errorDescription: String? {
        switch self {
        case .invalidRuntimeConfigurationFile:
            return "Stored runtime configuration is invalid"
        case .supportDirectoryUnavailable:
            return "CameraBridge support directory is unavailable"
        }
    }
}

public enum CameraBridgeRuntimeInfoStoreError: LocalizedError, Equatable {
    case invalidRuntimeInfoFile
    case supportDirectoryUnavailable

    public var errorDescription: String? {
        switch self {
        case .invalidRuntimeInfoFile:
            return "Stored runtime info is invalid"
        case .supportDirectoryUnavailable:
            return "CameraBridge support directory is unavailable"
        }
    }
}

public struct DefaultCameraBridgeAuthTokenStore {
    public var baseDirectoryURL: URL?

    private let fileManager: FileManager

    public init(fileManager: FileManager = .default, baseDirectoryURL: URL? = nil) {
        self.fileManager = fileManager
        self.baseDirectoryURL = baseDirectoryURL
    }

    public func loadToken() throws -> String? {
        let tokenURL = try authTokenURL()
        guard fileManager.fileExists(atPath: tokenURL.path) else {
            return nil
        }

        return try normalizedToken(from: tokenURL)
    }

    public func loadOrCreateToken() throws -> String {
        let tokenURL = try authTokenURL()
        try fileManager.createDirectory(
            at: tokenURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if fileManager.fileExists(atPath: tokenURL.path) {
            return try normalizedToken(from: tokenURL)
        }

        let token = UUID().uuidString.lowercased()
        try Data(token.utf8).write(to: tokenURL, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tokenURL.path)
        return token
    }

    public func authTokenURL() throws -> URL {
        try CameraBridgeSupportPaths.authTokenURL(baseDirectoryURL: baseDirectoryURL, fileManager: fileManager)
    }

    private func supportDirectoryURL() throws -> URL {
        try resolvedSupportDirectoryURL(
            baseDirectoryURL: baseDirectoryURL,
            fileManager: fileManager,
            unavailableError: CameraBridgeAuthTokenError.supportDirectoryUnavailable
        )
    }

    private func normalizedToken(from tokenURL: URL) throws -> String {
        let token = try String(contentsOf: tokenURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            throw CameraBridgeAuthTokenError.invalidTokenFile
        }
        return token
    }
}

public struct DefaultCameraBridgePermissionStateStore {
    public var baseDirectoryURL: URL?

    private let fileManager: FileManager

    public init(fileManager: FileManager = .default, baseDirectoryURL: URL? = nil) {
        self.fileManager = fileManager
        self.baseDirectoryURL = baseDirectoryURL
    }

    public func loadPermissionState() throws -> CameraBridgeStoredPermissionState {
        let permissionStateURL = try permissionStateURL()
        guard fileManager.fileExists(atPath: permissionStateURL.path) else {
            return .notDetermined
        }

        let rawValue = try String(contentsOf: permissionStateURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let state = CameraBridgeStoredPermissionState(rawValue: rawValue) else {
            throw CameraBridgePermissionStateStoreError.invalidPermissionStateFile
        }

        return state
    }

    public func savePermissionState(_ state: CameraBridgeStoredPermissionState) throws {
        let permissionStateURL = try permissionStateURL()
        try fileManager.createDirectory(
            at: permissionStateURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(state.rawValue.utf8).write(to: permissionStateURL, options: .atomic)
    }

    public func permissionStateURL() throws -> URL {
        try CameraBridgeSupportPaths.permissionStateURL(
            baseDirectoryURL: baseDirectoryURL,
            fileManager: fileManager
        )
    }

    private func supportDirectoryURL() throws -> URL {
        try resolvedSupportDirectoryURL(
            baseDirectoryURL: baseDirectoryURL,
            fileManager: fileManager,
            unavailableError: CameraBridgePermissionStateStoreError.supportDirectoryUnavailable
        )
    }
}

public enum CameraBridgeRuntimeOwnership: String, Sendable, CaseIterable, Equatable, Codable {
    case external
    case appManaged = "app_managed"
}

public struct CameraBridgeRuntimeConfiguration: Sendable, Equatable, Codable {
    public static let defaultHost = "127.0.0.1"
    public static let defaultPort: UInt16 = 8731

    public var host: String
    public var port: UInt16

    public init(host: String = defaultHost, port: UInt16 = defaultPort) {
        self.host = host
        self.port = port
    }

    public var baseURL: URL {
        URL(string: "http://\(host):\(port)")!
    }
}

public struct CameraBridgeRuntimeInfo: Sendable, Equatable, Codable {
    public var pid: Int32
    public var host: String
    public var port: UInt16
    public var tokenFileURL: URL
    public var logFileURL: URL
    public var capturesDirectoryURL: URL
    public var ownership: CameraBridgeRuntimeOwnership

    public init(
        pid: Int32,
        host: String,
        port: UInt16,
        tokenFileURL: URL,
        logFileURL: URL,
        capturesDirectoryURL: URL,
        ownership: CameraBridgeRuntimeOwnership
    ) {
        self.pid = pid
        self.host = host
        self.port = port
        self.tokenFileURL = tokenFileURL
        self.logFileURL = logFileURL
        self.capturesDirectoryURL = capturesDirectoryURL
        self.ownership = ownership
    }

    public var baseURL: URL {
        URL(string: "http://\(host):\(port)")!
    }
}

public struct DefaultCameraBridgeRuntimeConfigurationStore {
    public var baseDirectoryURL: URL?

    private let fileManager: FileManager

    public init(fileManager: FileManager = .default, baseDirectoryURL: URL? = nil) {
        self.fileManager = fileManager
        self.baseDirectoryURL = baseDirectoryURL
    }

    public func loadConfiguration() throws -> CameraBridgeRuntimeConfiguration {
        let configurationURL = try runtimeConfigurationURL()
        guard fileManager.fileExists(atPath: configurationURL.path) else {
            return CameraBridgeRuntimeConfiguration()
        }

        let data = try Data(contentsOf: configurationURL)
        do {
            return try JSONDecoder().decode(CameraBridgeRuntimeConfiguration.self, from: data)
        } catch {
            throw CameraBridgeRuntimeConfigurationStoreError.invalidRuntimeConfigurationFile
        }
    }

    public func saveConfiguration(_ configuration: CameraBridgeRuntimeConfiguration) throws {
        let configurationURL = try runtimeConfigurationURL()
        try fileManager.createDirectory(
            at: configurationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(configuration).write(to: configurationURL, options: .atomic)
    }

    public func runtimeConfigurationURL() throws -> URL {
        try CameraBridgeSupportPaths.runtimeConfigurationURL(
            baseDirectoryURL: baseDirectoryURL,
            fileManager: fileManager
        )
    }
}

public struct DefaultCameraBridgeRuntimeInfoStore {
    public var baseDirectoryURL: URL?

    private let fileManager: FileManager

    public init(fileManager: FileManager = .default, baseDirectoryURL: URL? = nil) {
        self.fileManager = fileManager
        self.baseDirectoryURL = baseDirectoryURL
    }

    public func loadRuntimeInfo() throws -> CameraBridgeRuntimeInfo? {
        let runtimeInfoURL = try self.runtimeInfoURL()
        guard fileManager.fileExists(atPath: runtimeInfoURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: runtimeInfoURL)
        do {
            return try JSONDecoder().decode(CameraBridgeRuntimeInfo.self, from: data)
        } catch {
            throw CameraBridgeRuntimeInfoStoreError.invalidRuntimeInfoFile
        }
    }

    public func saveRuntimeInfo(_ runtimeInfo: CameraBridgeRuntimeInfo) throws {
        let runtimeInfoURL = try self.runtimeInfoURL()
        try fileManager.createDirectory(
            at: runtimeInfoURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(runtimeInfo).write(to: runtimeInfoURL, options: .atomic)
    }

    public func clearRuntimeInfo() throws {
        let runtimeInfoURL = try self.runtimeInfoURL()
        guard fileManager.fileExists(atPath: runtimeInfoURL.path) else {
            return
        }

        try fileManager.removeItem(at: runtimeInfoURL)
    }

    public func runtimeInfoURL() throws -> URL {
        try CameraBridgeSupportPaths.runtimeInfoURL(
            baseDirectoryURL: baseDirectoryURL,
            fileManager: fileManager
        )
    }
}

public enum CameraBridgeSupportPaths {
    public static func supportDirectoryURL(
        baseDirectoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> URL {
        try resolvedSupportDirectoryURL(
            baseDirectoryURL: baseDirectoryURL,
            fileManager: fileManager,
            unavailableError: CameraBridgeSupportPathError.supportDirectoryUnavailable
        )
    }

    public static func authTokenURL(
        baseDirectoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> URL {
        try supportDirectoryURL(baseDirectoryURL: baseDirectoryURL, fileManager: fileManager)
            .appendingPathComponent("auth-token", isDirectory: false)
    }

    public static func permissionStateURL(
        baseDirectoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> URL {
        try supportDirectoryURL(baseDirectoryURL: baseDirectoryURL, fileManager: fileManager)
            .appendingPathComponent("permission-state", isDirectory: false)
    }

    public static func runtimeConfigurationURL(
        baseDirectoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> URL {
        try supportDirectoryURL(baseDirectoryURL: baseDirectoryURL, fileManager: fileManager)
            .appendingPathComponent("runtime-configuration.json", isDirectory: false)
    }

    public static func runtimeInfoURL(
        baseDirectoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> URL {
        try supportDirectoryURL(baseDirectoryURL: baseDirectoryURL, fileManager: fileManager)
            .appendingPathComponent("runtime-info.json", isDirectory: false)
    }

    public static func logsDirectoryURL(
        baseDirectoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> URL {
        try supportDirectoryURL(baseDirectoryURL: baseDirectoryURL, fileManager: fileManager)
            .appendingPathComponent("Logs", isDirectory: true)
    }

    public static func logFileURL(
        baseDirectoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> URL {
        try logsDirectoryURL(baseDirectoryURL: baseDirectoryURL, fileManager: fileManager)
            .appendingPathComponent("camd.log", isDirectory: false)
    }

    public static func capturesDirectoryURL(
        baseDirectoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> URL {
        try supportDirectoryURL(baseDirectoryURL: baseDirectoryURL, fileManager: fileManager)
            .appendingPathComponent("Captures", isDirectory: true)
    }
}

private func resolvedSupportDirectoryURL<E: Error>(
    baseDirectoryURL: URL?,
    fileManager: FileManager,
    unavailableError: E
) throws -> URL {
    if let baseDirectoryURL {
        return baseDirectoryURL
    }

    guard let applicationSupportURL =
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    else {
        throw unavailableError
    }

    return applicationSupportURL
        .appendingPathComponent("CameraBridge", isDirectory: true)
}

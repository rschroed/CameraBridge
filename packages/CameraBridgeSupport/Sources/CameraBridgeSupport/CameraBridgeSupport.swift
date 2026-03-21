import Foundation

public enum CameraBridgeSupportModule {
    public static let name = "CameraBridgeSupport"
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
        try supportDirectoryURL()
            .appendingPathComponent("auth-token", isDirectory: false)
    }

    private func supportDirectoryURL() throws -> URL {
        if let baseDirectoryURL {
            return baseDirectoryURL
        }

        guard let applicationSupportURL =
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else {
            throw CameraBridgeAuthTokenError.supportDirectoryUnavailable
        }

        return applicationSupportURL
            .appendingPathComponent("CameraBridge", isDirectory: true)
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

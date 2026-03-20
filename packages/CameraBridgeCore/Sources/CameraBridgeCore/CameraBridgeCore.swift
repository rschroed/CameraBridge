import AVFoundation

public enum CameraBridgeCoreModule {
    public static let name = "CameraBridgeCore"
}

public enum PermissionState: String, Sendable, CaseIterable, Equatable {
    case notDetermined = "not_determined"
    case restricted
    case denied
    case authorized
}

public enum SessionState: String, Sendable, CaseIterable, Equatable {
    case stopped
    case running
}

public enum PreviewState: Sendable, Equatable {
    case stopped
    case running
}

public struct CameraStateError: Error, Sendable, Equatable {
    public let message: String

    public init(message: String) {
        self.message = message
    }
}

public struct CameraState: Sendable, Equatable {
    public var permissionState: PermissionState
    public var sessionState: SessionState
    public var previewState: PreviewState
    public var activeDeviceID: String?
    public var currentOwnerID: String?
    public var lastError: CameraStateError?

    public init(
        permissionState: PermissionState = .notDetermined,
        sessionState: SessionState = .stopped,
        previewState: PreviewState = .stopped,
        activeDeviceID: String? = nil,
        currentOwnerID: String? = nil,
        lastError: CameraStateError? = nil
    ) {
        self.permissionState = permissionState
        self.sessionState = sessionState
        self.previewState = previewState
        self.activeDeviceID = activeDeviceID
        self.currentOwnerID = currentOwnerID
        self.lastError = lastError
    }
}

public protocol CameraPermissionStatusProviding: Sendable {
    func currentPermissionState() -> PermissionState
}

public protocol CameraStateProviding: Sendable {
    func currentCameraState() -> CameraState
}

public struct AVFoundationCameraPermissionStatusProvider: CameraPermissionStatusProviding {
    public init() {}

    public func currentPermissionState() -> PermissionState {
        PermissionState(authorizationStatus: AVCaptureDevice.authorizationStatus(for: .video))
    }
}

public struct DefaultCameraStateProvider: CameraStateProviding {
    public var state: CameraState

    public init(state: CameraState = CameraState()) {
        self.state = state
    }

    public func currentCameraState() -> CameraState {
        state
    }
}

extension PermissionState {
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

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

public enum SessionState: Sendable, Equatable {
    case stopped
    case running
}

public enum PreviewState: Sendable, Equatable {
    case stopped
    case running
}

public struct PermissionRequestResult: Sendable, Equatable {
    public var status: PermissionState
    public var prompted: Bool

    public init(status: PermissionState, prompted: Bool) {
        self.status = status
        self.prompted = prompted
    }
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
    public var lastError: CameraStateError?

    public init(
        permissionState: PermissionState = .notDetermined,
        sessionState: SessionState = .stopped,
        previewState: PreviewState = .stopped,
        activeDeviceID: String? = nil,
        lastError: CameraStateError? = nil
    ) {
        self.permissionState = permissionState
        self.sessionState = sessionState
        self.previewState = previewState
        self.activeDeviceID = activeDeviceID
        self.lastError = lastError
    }
}

public protocol CameraPermissionStatusProviding: Sendable {
    func currentPermissionState() -> PermissionState
}

public protocol CameraPermissionRequesting: Sendable {
    func requestPermission(completion: @escaping @Sendable (PermissionRequestResult) -> Void)
}

public struct AVFoundationCameraPermissionStatusProvider: CameraPermissionStatusProviding {
    public init() {}

    public func currentPermissionState() -> PermissionState {
        PermissionState(authorizationStatus: AVCaptureDevice.authorizationStatus(for: .video))
    }
}

public struct AVFoundationCameraPermissionRequester: CameraPermissionRequesting {
    public init() {}

    public func requestPermission(completion: @escaping @Sendable (PermissionRequestResult) -> Void) {
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .video)
        guard currentStatus == .notDetermined else {
            completion(
                PermissionRequestResult(
                    status: PermissionState(authorizationStatus: currentStatus),
                    prompted: false
                )
            )
            return
        }

        AVCaptureDevice.requestAccess(for: .video) { _ in
            completion(
                PermissionRequestResult(
                    status: PermissionState(
                        authorizationStatus: AVCaptureDevice.authorizationStatus(for: .video)
                    ),
                    prompted: true
                )
            )
        }
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

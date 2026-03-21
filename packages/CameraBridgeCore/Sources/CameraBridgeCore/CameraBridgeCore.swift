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

public enum CameraDevicePosition: String, Sendable, CaseIterable, Equatable {
    case front
    case back
    case external
}

public struct CameraDevice: Sendable, Equatable {
    public var id: String
    public var name: String
    public var position: CameraDevicePosition

    public init(id: String, name: String, position: CameraDevicePosition) {
        self.id = id
        self.name = name
        self.position = position
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

public protocol CameraDeviceListing: Sendable {
    func availableDevices() -> [CameraDevice]
}

public struct AVFoundationCameraPermissionStatusProvider: CameraPermissionStatusProviding {
    public init() {}

    public func currentPermissionState() -> PermissionState {
        PermissionState(authorizationStatus: AVCaptureDevice.authorizationStatus(for: .video))
    }
}

public struct AVFoundationCameraDeviceListing: CameraDeviceListing {
    public init() {}

    public func availableDevices() -> [CameraDevice] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInWideAngleCamera,
                .continuityCamera,
                .deskViewCamera,
                .external,
            ],
            mediaType: .video,
            position: .unspecified
        )
        .devices
        .map(CameraDevice.init(device:))
        .sorted {
            if $0.name == $1.name {
                return $0.id < $1.id
            }

            return $0.name < $1.name
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

extension CameraDevicePosition {
    init(position: AVCaptureDevice.Position) {
        switch position {
        case .front:
            self = .front
        case .back:
            self = .back
        case .unspecified:
            self = .external
        @unknown default:
            self = .external
        }
    }
}

private extension CameraDevice {
    init(device: AVCaptureDevice) {
        self.init(
            id: device.uniqueID,
            name: device.localizedName,
            position: CameraDevicePosition(position: device.position)
        )
    }
}

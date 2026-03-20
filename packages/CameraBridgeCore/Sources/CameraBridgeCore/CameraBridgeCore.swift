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

public protocol CameraDeviceListing: Sendable {
    func availableDevices() -> [CameraDevice]
}

public protocol CameraDeviceSelecting: Sendable {
    func selectDevice(id: String, ownerID: String?) throws -> CameraState
}

public protocol CameraSessionStarting: Sendable {
    func startSession(ownerID: String, permissionState: PermissionState) throws -> CameraState
}

public protocol CameraSessionStopping: Sendable {
    func stopSession(ownerID: String) throws -> CameraState
}

public enum CameraDeviceSelectionError: Error, Sendable, Equatable {
    case ownershipConflict(currentOwnerID: String)
    case unavailableDevice(id: String)
}

public enum CameraSessionLifecycleError: Error, Sendable, Equatable {
    case ownershipConflict(currentOwnerID: String)
    case permissionRequired(status: PermissionState)
    case missingActiveDevice
    case alreadyRunning
    case alreadyStopped
    case missingOwner
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

public struct DefaultCameraStateProvider: CameraStateProviding {
    public var state: CameraState

    public init(state: CameraState = CameraState()) {
        self.state = state
    }

    public func currentCameraState() -> CameraState {
        state
    }
}

public final class DefaultCameraSessionController: CameraStateProviding, CameraDeviceSelecting, CameraSessionStarting, CameraSessionStopping, @unchecked Sendable {
    private let deviceListing: any CameraDeviceListing
    private let stateLock = NSLock()
    private var state: CameraState

    public init(
        deviceListing: any CameraDeviceListing,
        initialState: CameraState = CameraState()
    ) {
        self.deviceListing = deviceListing
        self.state = initialState
    }

    public func currentCameraState() -> CameraState {
        stateLock.lock()
        defer { stateLock.unlock() }
        return state
    }

    public func selectDevice(id: String, ownerID: String?) throws -> CameraState {
        stateLock.lock()
        defer { stateLock.unlock() }

        if let currentOwnerID = state.currentOwnerID, currentOwnerID != ownerID {
            let message = "Session is owned by \(currentOwnerID)"
            state.lastError = CameraStateError(message: message)
            throw CameraDeviceSelectionError.ownershipConflict(currentOwnerID: currentOwnerID)
        }

        guard deviceListing.availableDevices().contains(where: { $0.id == id }) else {
            let message = "Requested device is unavailable: \(id)"
            state.lastError = CameraStateError(message: message)
            throw CameraDeviceSelectionError.unavailableDevice(id: id)
        }

        state.activeDeviceID = id
        state.lastError = nil
        return state
    }

    public func startSession(ownerID: String, permissionState: PermissionState) throws -> CameraState {
        stateLock.lock()
        defer { stateLock.unlock() }

        state.permissionState = permissionState

        if let currentOwnerID = state.currentOwnerID, currentOwnerID != ownerID {
            let message = "Session is owned by \(currentOwnerID)"
            state.lastError = CameraStateError(message: message)
            throw CameraSessionLifecycleError.ownershipConflict(currentOwnerID: currentOwnerID)
        }

        guard permissionState == .authorized else {
            let message = "Camera permission is \(permissionState.rawValue)"
            state.lastError = CameraStateError(message: message)
            throw CameraSessionLifecycleError.permissionRequired(status: permissionState)
        }

        guard state.activeDeviceID != nil else {
            let message = "Cannot start session without an active device"
            state.lastError = CameraStateError(message: message)
            throw CameraSessionLifecycleError.missingActiveDevice
        }

        guard state.sessionState != .running else {
            let message = "Session is already running"
            state.lastError = CameraStateError(message: message)
            throw CameraSessionLifecycleError.alreadyRunning
        }

        state.sessionState = .running
        state.currentOwnerID = ownerID
        state.lastError = nil
        return state
    }

    public func stopSession(ownerID: String) throws -> CameraState {
        stateLock.lock()
        defer { stateLock.unlock() }

        guard state.sessionState == .running else {
            let message = "Session is already stopped"
            state.lastError = CameraStateError(message: message)
            throw CameraSessionLifecycleError.alreadyStopped
        }

        guard let currentOwnerID = state.currentOwnerID else {
            let message = "Running session has no owner"
            state.lastError = CameraStateError(message: message)
            throw CameraSessionLifecycleError.missingOwner
        }

        guard currentOwnerID == ownerID else {
            let message = "Session is owned by \(currentOwnerID)"
            state.lastError = CameraStateError(message: message)
            throw CameraSessionLifecycleError.ownershipConflict(currentOwnerID: currentOwnerID)
        }

        state.sessionState = .stopped
        state.previewState = .stopped
        state.currentOwnerID = nil
        state.lastError = nil
        return state
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

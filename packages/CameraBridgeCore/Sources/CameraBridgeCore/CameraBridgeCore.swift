import AVFoundation
import Foundation

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

public protocol CameraPermissionRequesting: Sendable {
    func requestPermission(completion: @escaping @Sendable (PermissionRequestResult) -> Void)
}

public protocol CameraPermissionControlling: CameraPermissionStatusProviding, CameraPermissionRequesting {}

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

public protocol CameraPhotoCapturing: Sendable {
    func capturePhoto(ownerID: String) throws -> CapturedPhotoArtifact
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

public struct CapturedPhotoArtifact: Sendable, Equatable {
    public var localPath: String
    public var capturedAt: Date
    public var deviceID: String

    public init(localPath: String, capturedAt: Date, deviceID: String) {
        self.localPath = localPath
        self.capturedAt = capturedAt
        self.deviceID = deviceID
    }
}

public enum CameraPhotoCaptureError: Error, Sendable, Equatable {
    case ownershipConflict(currentOwnerID: String)
    case sessionNotRunning
    case missingOwner
    case missingActiveDevice
    case unavailableDevice(id: String)
    case captureFailed(message: String)
}

public protocol CameraStillPhotoProducing: Sendable {
    func capturePhotoData(deviceID: String) throws -> Data
}

public protocol PhotoArtifactStoring: Sendable {
    func storePhotoData(_ data: Data, deviceID: String, capturedAt: Date) throws -> URL
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

public struct DefaultPhotoArtifactStore: PhotoArtifactStoring {
    public var baseDirectoryURL: URL

    public init(baseDirectoryURL: URL? = nil) {
        self.baseDirectoryURL = baseDirectoryURL ?? Self.defaultBaseDirectoryURL()
    }

    public func storePhotoData(_ data: Data, deviceID: String, capturedAt: Date) throws -> URL {
        try FileManager.default.createDirectory(
            at: baseDirectoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let fileURL = baseDirectoryURL.appendingPathComponent(
            "capture-\(Self.filenameTimestamp(from: capturedAt))-\(UUID().uuidString.lowercased()).jpg",
            isDirectory: false
        )
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    private static func defaultBaseDirectoryURL() -> URL {
        let applicationSupportURL =
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ??
            URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        return applicationSupportURL
            .appendingPathComponent("CameraBridge", isDirectory: true)
            .appendingPathComponent("Captures", isDirectory: true)
    }

    private static func filenameTimestamp(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmssSSS'Z'"
        return formatter.string(from: date)
    }
}

public struct UnimplementedStillPhotoProducer: CameraStillPhotoProducing {
    public init() {}

    public func capturePhotoData(deviceID: String) throws -> Data {
        throw CameraPhotoCaptureError.captureFailed(message: "Still photo capture is not configured")
    }
}

public struct AVFoundationStillPhotoProducer: CameraStillPhotoProducing {
    public var timeout: TimeInterval

    public init(timeout: TimeInterval = 10) {
        self.timeout = timeout
    }

    public func capturePhotoData(deviceID: String) throws -> Data {
        guard let device = discoverDevice(id: deviceID) else {
            throw CameraPhotoCaptureError.unavailableDevice(id: deviceID)
        }

        let session = AVCaptureSession()
        session.beginConfiguration()
        session.sessionPreset = .photo

        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            throw CameraPhotoCaptureError.captureFailed(message: "Unable to create AVCaptureDeviceInput")
        }

        guard session.canAddInput(input) else {
            throw CameraPhotoCaptureError.captureFailed(message: "Unable to add camera input to capture session")
        }

        let output = AVCapturePhotoOutput()
        guard session.canAddOutput(output) else {
            throw CameraPhotoCaptureError.captureFailed(message: "Unable to add photo output to capture session")
        }

        session.addInput(input)
        session.addOutput(output)
        session.commitConfiguration()
        session.startRunning()
        defer { session.stopRunning() }

        let delegate = StillPhotoCaptureDelegate()
        let settings: AVCapturePhotoSettings
        if output.availablePhotoCodecTypes.contains(.jpeg) {
            settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        } else {
            settings = AVCapturePhotoSettings()
        }

        output.capturePhoto(with: settings, delegate: delegate)
        return try delegate.waitForPhotoData(timeout: timeout)
    }

    private func discoverDevice(id: String) -> AVCaptureDevice? {
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
        .first(where: { $0.uniqueID == id })
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

public final class DefaultCameraSessionController: CameraPermissionControlling, CameraStateProviding, CameraDeviceListing, CameraDeviceSelecting, CameraSessionStarting, CameraSessionStopping, CameraPhotoCapturing, @unchecked Sendable {
    private let permissionStatusProvider: any CameraPermissionStatusProviding
    private let permissionRequester: any CameraPermissionRequesting
    private let deviceListing: any CameraDeviceListing
    private let photoProducer: any CameraStillPhotoProducing
    private let artifactStore: any PhotoArtifactStoring
    private let now: @Sendable () -> Date
    private let stateLock = NSLock()
    private var state: CameraState

    public init(
        permissionStatusProvider: any CameraPermissionStatusProviding = AVFoundationCameraPermissionStatusProvider(),
        permissionRequester: any CameraPermissionRequesting = AVFoundationCameraPermissionRequester(),
        deviceListing: any CameraDeviceListing,
        photoProducer: any CameraStillPhotoProducing = UnimplementedStillPhotoProducer(),
        artifactStore: any PhotoArtifactStoring = DefaultPhotoArtifactStore(),
        now: @escaping @Sendable () -> Date = { Date() },
        initialState: CameraState = CameraState()
    ) {
        self.permissionStatusProvider = permissionStatusProvider
        self.permissionRequester = permissionRequester
        self.deviceListing = deviceListing
        self.photoProducer = photoProducer
        self.artifactStore = artifactStore
        self.now = now
        self.state = initialState
    }

    public convenience init(
        deviceListing: any CameraDeviceListing,
        photoProducer: any CameraStillPhotoProducing = UnimplementedStillPhotoProducer(),
        artifactStore: any PhotoArtifactStoring = DefaultPhotoArtifactStore(),
        now: @escaping @Sendable () -> Date = { Date() },
        initialState: CameraState = CameraState()
    ) {
        self.init(
            permissionStatusProvider: AVFoundationCameraPermissionStatusProvider(),
            permissionRequester: AVFoundationCameraPermissionRequester(),
            deviceListing: deviceListing,
            photoProducer: photoProducer,
            artifactStore: artifactStore,
            now: now,
            initialState: initialState
        )
    }

    public func currentCameraState() -> CameraState {
        stateLock.lock()
        defer { stateLock.unlock() }
        return state
    }

    public func currentPermissionState() -> PermissionState {
        let permissionState = permissionStatusProvider.currentPermissionState()
        stateLock.lock()
        defer { stateLock.unlock() }
        state.permissionState = permissionState
        return permissionState
    }

    public func requestPermission(completion: @escaping @Sendable (PermissionRequestResult) -> Void) {
        permissionRequester.requestPermission { [weak self] result in
            guard let self else {
                completion(result)
                return
            }

            self.stateLock.lock()
            self.state.permissionState = result.status
            self.state.lastError = nil
            self.stateLock.unlock()
            completion(result)
        }
    }

    public func availableDevices() -> [CameraDevice] {
        deviceListing.availableDevices()
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

    public func capturePhoto(ownerID: String) throws -> CapturedPhotoArtifact {
        stateLock.lock()
        defer { stateLock.unlock() }

        guard state.sessionState == .running else {
            let error = CameraPhotoCaptureError.sessionNotRunning
            state.lastError = CameraStateError(message: error.message)
            throw error
        }

        guard let currentOwnerID = state.currentOwnerID else {
            let error = CameraPhotoCaptureError.missingOwner
            state.lastError = CameraStateError(message: error.message)
            throw error
        }

        guard currentOwnerID == ownerID else {
            let error = CameraPhotoCaptureError.ownershipConflict(currentOwnerID: currentOwnerID)
            state.lastError = CameraStateError(message: error.message)
            throw error
        }

        guard let activeDeviceID = state.activeDeviceID else {
            let error = CameraPhotoCaptureError.missingActiveDevice
            state.lastError = CameraStateError(message: error.message)
            throw error
        }

        let capturedAt = now()

        do {
            let data = try photoProducer.capturePhotoData(deviceID: activeDeviceID)
            let fileURL = try artifactStore.storePhotoData(
                data,
                deviceID: activeDeviceID,
                capturedAt: capturedAt
            )
            let artifact = CapturedPhotoArtifact(
                localPath: fileURL.path,
                capturedAt: capturedAt,
                deviceID: activeDeviceID
            )
            state.lastError = nil
            return artifact
        } catch let error as CameraPhotoCaptureError {
            state.lastError = CameraStateError(message: error.message)
            throw error
        } catch {
            let captureError = CameraPhotoCaptureError.captureFailed(
                message: error.localizedDescription
            )
            state.lastError = CameraStateError(message: captureError.message)
            throw captureError
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

private extension CameraPhotoCaptureError {
    var message: String {
        switch self {
        case .ownershipConflict(let currentOwnerID):
            return "Session is owned by \(currentOwnerID)"
        case .sessionNotRunning:
            return "Session is not running"
        case .missingOwner:
            return "Running session has no owner"
        case .missingActiveDevice:
            return "Cannot capture photo without an active device"
        case .unavailableDevice(let id):
            return "Requested device is unavailable: \(id)"
        case .captureFailed(let message):
            return message
        }
    }
}

private final class StillPhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private let semaphore = DispatchSemaphore(value: 0)
    private var result: Result<Data, CameraPhotoCaptureError>?

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            complete(with: .failure(.captureFailed(message: error.localizedDescription)))
            return
        }

        guard let data = photo.fileDataRepresentation() else {
            complete(with: .failure(.captureFailed(message: "AVFoundation did not produce photo data")))
            return
        }

        complete(with: .success(data))
    }

    func waitForPhotoData(timeout: TimeInterval) throws -> Data {
        let waitResult = semaphore.wait(timeout: .now() + timeout)
        guard waitResult == .success else {
            throw CameraPhotoCaptureError.captureFailed(message: "Photo capture timed out")
        }

        lock.lock()
        defer { lock.unlock() }

        guard let result else {
            throw CameraPhotoCaptureError.captureFailed(message: "Photo capture finished without a result")
        }

        return try result.get()
    }

    private func complete(with result: Result<Data, CameraPhotoCaptureError>) {
        lock.lock()
        let shouldSignal = self.result == nil
        if shouldSignal {
            self.result = result
        }
        lock.unlock()

        if shouldSignal {
            semaphore.signal()
        }
    }
}

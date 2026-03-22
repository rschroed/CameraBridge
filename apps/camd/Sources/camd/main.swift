import CameraBridgeAPI
import CameraBridgeCore
import CameraBridgeSupport
import Darwin
import Dispatch
import Foundation

_ = CameraBridgeAPIModule.name
_ = CameraBridgeCoreModule.name

final class CameraBridgeDaemonRuntime {
    private let daemon = CameraBridgeDaemon()
    private let runtimeInfoStore = DefaultCameraBridgeRuntimeInfoStore()
    private var server: LocalHTTPServer?
    private var signalSources: [DispatchSourceSignal] = []
    private let signalQueue = DispatchQueue(label: "camd.signal-handling")

    func run() throws {
        let server = try daemon.start()
        self.server = server
        try runtimeInfoStore.saveRuntimeInfo(
            daemon.runtimeInfo(boundPort: server.boundPort ?? daemon.configuration.port)
        )
        installSignalHandlers()
        dispatchMain()
    }

    private func installSignalHandlers() {
        signal(SIGTERM, SIG_IGN)
        signal(SIGINT, SIG_IGN)

        for signalValue in [SIGTERM, SIGINT] {
            let source = DispatchSource.makeSignalSource(signal: signalValue, queue: signalQueue)
            source.setEventHandler { [weak self] in
                self?.shutdown()
            }
            source.resume()
            signalSources.append(source)
        }
    }

    private func shutdown() {
        server?.stop()
        try? runtimeInfoStore.clearRuntimeInfo()
        exit(0)
    }
}

let runtime = CameraBridgeDaemonRuntime()

do {
    try runtime.run()
} catch {
    try? DefaultCameraBridgeRuntimeInfoStore().clearRuntimeInfo()
    fputs("camd failed to start: \(error)\n", stderr)
}

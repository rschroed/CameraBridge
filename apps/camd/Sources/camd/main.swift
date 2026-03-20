import CameraBridgeAPI
import CameraBridgeCore
import Dispatch

_ = CameraBridgeAPIModule.name
_ = CameraBridgeCoreModule.name

let daemon = CameraBridgeDaemon()

do {
    let server = try daemon.start()
    withExtendedLifetime(server) {
        dispatchMain()
    }
} catch {
    fputs("camd failed to start: \(error)\n", stderr)
}

import CameraBridgeAPI
import CameraBridgeCore

@main
struct CameraBridgeDaemonMain {
    static func main() {
        print("camd scaffold: \(CameraBridgeAPIModule.name) -> \(CameraBridgeCoreModule.name)")
    }
}

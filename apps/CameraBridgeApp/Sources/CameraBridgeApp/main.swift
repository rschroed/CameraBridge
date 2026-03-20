import CameraBridgeClientSwift
import CameraBridgeCore

@main
struct CameraBridgeAppMain {
    static func main() {
        let client = CameraBridgeClient()
        print("CameraBridgeApp scaffold: \(client.apiModuleName) + \(CameraBridgeCoreModule.name)")
    }
}

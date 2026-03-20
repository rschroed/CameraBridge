import Testing
@testable import CameraBridgeClientSwift

@Test
func clientExposesAPIModuleName() {
    let client = CameraBridgeClient()
    #expect(client.apiModuleName == "CameraBridgeAPI")
}

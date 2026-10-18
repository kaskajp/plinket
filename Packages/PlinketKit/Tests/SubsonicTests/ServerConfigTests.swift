import Foundation
import Testing
import Subsonic

struct ServerConfigTests {
    @Test func serverAddress_assumesHTTPSAndDropsTrailingSlash() {
        let config = ServerConfig(serverAddress: " music.example.com/ ", username: "demo")

        #expect(config?.baseURL.absoluteString == "https://music.example.com")
    }

    @Test func serverAddress_keepsPortAndPath() {
        let config = ServerConfig(serverAddress: "HTTPS://nas.example.com:4533/navidrome", username: "demo")

        #expect(config?.baseURL.absoluteString == "https://nas.example.com:4533/navidrome")
    }

    @Test(arguments: ["", "http://music.example.com", "ftp://music.example.com", "https://"])
    func serverAddress_rejectsUnusableAddresses(address: String) {
        #expect(ServerConfig(serverAddress: address, username: "demo") == nil)
    }

    @Test func serverAddress_rejectsBlankUsername() {
        #expect(ServerConfig(serverAddress: "music.example.com", username: "  ") == nil)
    }
}

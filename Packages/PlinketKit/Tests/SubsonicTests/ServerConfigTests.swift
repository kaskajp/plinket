import Foundation
import Testing
import Subsonic

struct ServerConfigTests {
    @Test func serverAddress_assumesHTTPSAndDropsTrailingSlash() throws {
        let config = try ServerConfig(serverAddress: " music.example.com/ ", username: "demo")

        #expect(config.baseURL.absoluteString == "https://music.example.com")
    }

    @Test func serverAddress_keepsPortAndPath() throws {
        let config = try ServerConfig(serverAddress: "HTTPS://nas.example.com:4533/navidrome", username: "demo")

        #expect(config.baseURL.absoluteString == "https://nas.example.com:4533/navidrome")
    }

    @Test(arguments: [
        "http://192.168.1.10:4533",
        "http://10.0.0.2",
        "http://172.20.1.5",
        "http://127.0.0.1:4533",
        "http://169.254.10.1",
        "http://100.101.102.103",
        "http://[fd12:3456::1]:4533",
        "http://[fe80::1]",
        "http://localhost:4533",
        "http://nas.local:4533/navidrome",
        "http://nas",
    ])
    func serverAddress_allowsPlainHTTPOnLocalNetwork(address: String) throws {
        let config = try ServerConfig(serverAddress: address, username: "demo")

        #expect(config.baseURL.scheme == "http")
    }

    @Test(arguments: [
        "http://music.example.com",
        "http://8.8.8.8",
        "http://172.32.0.1",
        "http://[2001:db8::1]",
        "http://nas.home.lan",
    ])
    func serverAddress_rejectsPlainHTTPOutsideLocalNetwork(address: String) {
        #expect(throws: ServerAddressError.plainHTTPOutsideLocalNetwork) {
            try ServerConfig(serverAddress: address, username: "demo")
        }
    }

    @Test(arguments: ["", "ftp://music.example.com", "https://"])
    func serverAddress_rejectsUnusableAddresses(address: String) {
        #expect(throws: ServerAddressError.invalid) {
            try ServerConfig(serverAddress: address, username: "demo")
        }
    }

    @Test func serverAddress_rejectsBlankUsername() {
        #expect(throws: ServerAddressError.invalid) {
            try ServerConfig(serverAddress: "music.example.com", username: "  ")
        }
    }
}

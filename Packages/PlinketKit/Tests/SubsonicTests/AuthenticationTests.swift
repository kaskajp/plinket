import Foundation
import Testing
@testable import Subsonic

struct AuthenticationTests {
    @Test func token_isMD5OfPasswordAndSalt() {
        // Example from the Subsonic API documentation.
        #expect(TokenAuthentication.token(password: "sesame", salt: "c19b2d") == "26719a1196d2a940705a59634eb18eab")
    }

    @Test func url_carriesTokenForItsOwnSalt() throws {
        let client = SubsonicClient(config: makeConfig(), password: testPassword)

        let query = queryItems(of: client.streamURL(songID: "song-1"))

        let salt = try #require(query["s"])
        #expect(query["t"] == TokenAuthentication.token(password: testPassword, salt: salt))
    }

    @Test func url_drawsFreshSaltPerRequest() {
        let client = SubsonicClient(config: makeConfig(), password: testPassword)

        let firstSalt = queryItems(of: client.streamURL(songID: "song-1"))["s"]
        let secondSalt = queryItems(of: client.streamURL(songID: "song-1"))["s"]

        #expect(firstSalt != secondSalt)
    }

    @Test func url_neverSendsPlaintextPassword() {
        let client = SubsonicClient(config: makeConfig(), password: testPassword)

        let url = client.coverArtURL(id: "al-1", size: 300)

        #expect(!url.absoluteString.contains(testPassword))
    }
}

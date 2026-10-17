import CryptoKit
import Foundation

enum TokenAuthentication {
    static let saltByteCount = 8

    static func token(password: String, salt: String) -> String {
        hexString(Insecure.MD5.hash(data: Data((password + salt).utf8)))
    }

    /// `SystemRandomNumberGenerator` is cryptographically secure on Apple platforms.
    static func makeSalt() -> String {
        var generator = SystemRandomNumberGenerator()
        let bytes = (0..<saltByteCount).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        return hexString(bytes)
    }

    private static func hexString(_ bytes: some Sequence<UInt8>) -> String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }
}

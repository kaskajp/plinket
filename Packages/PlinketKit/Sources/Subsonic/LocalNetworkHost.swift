import Foundation
import Network

/// Hosts on the local network, the only ones Plinket reaches over plain HTTP: private IP addresses,
/// `.local` names and single-label names. The app's local networking exception to App Transport Security lets these through.
enum LocalNetworkHost {
    static func contains(_ host: String) -> Bool {
        let host = host.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        if let address = IPv4Address(host) {
            return isPrivate(address)
        }
        if let address = IPv6Address(host) {
            return isPrivate(address)
        }
        return host == "localhost" || host.hasSuffix(".local") || !host.contains(".")
    }

    /// Loopback, link-local, RFC 1918 and carrier-grade NAT (used by VPNs such as Tailscale) ranges.
    private static func isPrivate(_ address: IPv4Address) -> Bool {
        let octets = [UInt8](address.rawValue)
        switch (octets[0], octets[1]) {
        case (10, _), (127, _), (192, 168), (169, 254):
            return true
        case (172, 16...31), (100, 64...127):
            return true
        default:
            return false
        }
    }

    /// Loopback, link-local and unique local (fc00::/7) ranges.
    private static func isPrivate(_ address: IPv6Address) -> Bool {
        let firstByte = [UInt8](address.rawValue)[0]
        return address.isLoopback || address.isLinkLocal || firstByte & 0xFE == 0xFC
    }
}

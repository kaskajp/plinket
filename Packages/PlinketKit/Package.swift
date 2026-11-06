// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PlinketKit",
    platforms: [.iOS("27.0"), .macOS("27.0")],
    products: [
        .library(name: "PlinketKit", targets: ["Subsonic", "Library", "Playback", "Downloads"]),
    ],
    targets: [
        .target(name: "Subsonic"),
        .target(name: "Library", dependencies: ["Subsonic"]),
        .target(name: "Playback", dependencies: ["Subsonic"]),
        .target(name: "Downloads", dependencies: ["Subsonic"]),
        .testTarget(name: "DownloadsTests", dependencies: ["Downloads", "Playback"], resources: [.copy("Fixtures")]),
        .testTarget(name: "SubsonicTests", dependencies: ["Subsonic"], resources: [.copy("Fixtures")]),
        .testTarget(name: "LibraryTests", dependencies: ["Library"]),
        .testTarget(name: "PlaybackTests", dependencies: ["Playback", "Subsonic"]),
    ]
)

// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PlinketKit",
    platforms: [.iOS("27.0"), .macOS("27.0")],
    products: [
        .library(name: "PlinketKit", targets: ["Subsonic", "Library", "Playback"]),
    ],
    targets: [
        .target(name: "Subsonic"),
        .target(name: "Library", dependencies: ["Subsonic"]),
        .target(name: "Playback", dependencies: ["Subsonic"]),
        .testTarget(name: "SubsonicTests", dependencies: ["Subsonic"], resources: [.copy("Fixtures")]),
        .testTarget(name: "LibraryTests", dependencies: ["Library"]),
        .testTarget(name: "PlaybackTests", dependencies: ["Playback", "Subsonic"]),
    ]
)
